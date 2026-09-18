extends RefCounted
## Mission runtime semantics — port of MissionRuntimeTests.cs.
## Covers: sequential completion, out-of-order/unknown events ignored,
## timeout fail, partial-count events return false, sticky terminal states.
## Inline spec model always runs; the real MissionRuntime is probed via load()
## when its script (plus the MissionDefinition/Objective class graph) resolves.

const DEF_PATH := "res://scripts/missions/mission_definition.gd"
const RT_PATH := "res://scripts/missions/mission_runtime.gd"


static func run() -> Dictionary:
	var counts: Array = [0, 0]
	_spec_sequential(counts)
	_spec_out_of_order(counts)
	_spec_timeout(counts)
	_spec_partial_counts(counts)
	_spec_terminal_sticky(counts)
	_real_checks(counts)
	return {"passed": counts[0], "failed": counts[1]}


static func _check(counts: Array, cond: bool, label: String) -> void:
	if cond:
		counts[0] += 1
	else:
		counts[1] += 1
		printerr("  FAIL [mission_runtime] ", label)


# --- Inline spec model (mirrors SpecMissionRuntime in C#) ---

static func _spec_new(objectives: Array, time_limit: float) -> Dictionary:
	return {
		"objectives": objectives.duplicate(),
		"index": 0,
		"state": "active",
		"time_left": time_limit,
		"progress": {},
	}


static func _spec_complete(m: Dictionary, oid: String) -> bool:
	if str(m["state"]) != "active":
		return false
	var objs: Array = m["objectives"]
	if int(m["index"]) >= objs.size():
		return false
	if str(objs[int(m["index"])]) != oid:
		return false
	m["index"] = int(m["index"]) + 1
	if int(m["index"]) >= objs.size():
		m["state"] = "passed"
	return true


static func _spec_tick(m: Dictionary, dt: float) -> void:
	if str(m["state"]) != "active":
		return
	m["time_left"] = float(m["time_left"]) - dt
	if float(m["time_left"]) <= 0.0:
		m["time_left"] = 0.0
		m["state"] = "failed"


static func _spec_sequential(counts: Array) -> void:
	var m := _spec_new(["go", "grab", "escape"], 120.0)
	_check(counts, str(m["state"]) == "active" and int(m["index"]) == 0, "spec starts active at index 0")
	_check(counts, _spec_complete(m, "go") and int(m["index"]) == 1, "spec completes first objective")
	_check(counts, _spec_complete(m, "grab") and int(m["index"]) == 2, "spec completes second objective")
	_check(counts, _spec_complete(m, "escape") and str(m["state"]) == "passed", "spec passes after last objective")


static func _spec_out_of_order(counts: Array) -> void:
	var m := _spec_new(["a", "b", "c"], 60.0)
	_check(counts, not _spec_complete(m, "c") and int(m["index"]) == 0, "spec ignores skip-ahead id")
	_check(counts, not _spec_complete(m, "b") and int(m["index"]) == 0, "spec ignores non-current id")
	_check(counts, not _spec_complete(m, "nope") and str(m["state"]) == "active", "spec ignores unknown id")
	_check(counts, _spec_complete(m, "a") and int(m["index"]) == 1, "spec advances on current id")


static func _spec_timeout(counts: Array) -> void:
	var m := _spec_new(["a", "b"], 10.0)
	_spec_tick(m, 4.0)
	_check(counts, str(m["state"]) == "active", "spec still active before limit")
	_check(counts, _spec_complete(m, "a"), "spec completes before timeout")
	_spec_tick(m, 6.5)
	_check(counts, str(m["state"]) == "failed" and float(m["time_left"]) == 0.0, "spec fails past time limit")
	var m2 := _spec_new(["a"], 5.0)
	_spec_tick(m2, 5.0)
	_check(counts, str(m2["state"]) == "failed", "spec fails on timeout without progress")
	var m3 := _spec_new(["a"], 5.0)
	_spec_tick(m3, 4.9)
	_check(counts, _spec_complete(m3, "a") and str(m3["state"]) == "passed", "spec passes just before limit")
	_spec_tick(m3, 100.0)
	_check(counts, str(m3["state"]) == "passed", "spec tick is no-op after pass")


static func _spec_partial_counts(counts: Array) -> void:
	# Collect 2 of 3 crates: progress folds in but does not advance (returns false).
	var progress := {"cargo_crate": 0}
	progress["cargo_crate"] = int(progress["cargo_crate"]) + 2
	var advanced := int(progress["cargo_crate"]) >= 3
	_check(counts, not advanced, "spec partial collect (2/3) does not advance")
	progress["cargo_crate"] = int(progress["cargo_crate"]) + 1
	advanced = int(progress["cargo_crate"]) >= 3
	_check(counts, advanced, "spec final collect (3/3) advances")


static func _spec_terminal_sticky(counts: Array) -> void:
	var m := _spec_new(["a"], 5.0)
	_spec_tick(m, 5.0)
	_check(counts, not _spec_complete(m, "a") and str(m["state"]) == "failed", "spec complete is no-op after fail")
	_spec_tick(m, 5.0)
	_check(counts, str(m["state"]) == "failed", "spec failed state is sticky")


# --- Real MissionRuntime probe (mirrors RealMissionRuntimeTests in C#) ---

static func _real_checks(counts: Array) -> void:
	if not ResourceLoader.exists(DEF_PATH) or not ResourceLoader.exists(RT_PATH):
		print("  SKIP [mission_runtime] real checks: scripts absent")
		return
	var Def = load(DEF_PATH)
	var RT = load(RT_PATH)
	if Def == null or RT == null:
		print("  SKIP [mission_runtime] real checks: load failed (class graph unresolved?)")
		return
	var probe = RT.new(Def.from_dict({"id": "probe", "objectives": []}))
	if probe == null or not probe.has_method("start") or not probe.has_method("advance_on_event") or not probe.has_method("update"):
		print("  SKIP [mission_runtime] real checks: API mismatch")
		return

	# Sequential playthrough: GoTo -> Collect x1 -> Deliver.
	var rt = RT.new(Def.from_dict({
		"id": "t", "title": "t", "description": "t",
		"objectives": [
			{"type": "GoTo", "targetId": "go"},
			{"type": "Collect", "itemId": "box", "count": 1},
			{"type": "Deliver", "destinationId": "drop"},
		],
		"rewards": {"money": 0},
		"timeLimitSec": 120.0,
	}))
	rt.start()
	_check(counts, rt.status == RT.Status.ACTIVE and rt.current_index == 0, "real starts ACTIVE at index 0")
	_check(counts, not rt.advance_on_event({"type": "Deliver", "destination_id": "drop"}) and rt.current_index == 0, "real ignores out-of-order deliver")
	_check(counts, rt.advance_on_event({"type": "Arrived", "target_id": "go"}) and rt.current_index == 1, "real advances on current GoTo")
	_check(counts, rt.advance_on_event({"type": "Collect", "item_id": "box"}) and rt.current_index == 2, "real advances on Collect")
	_check(counts, rt.advance_on_event({"type": "Deliver", "destination_id": "drop"}) and rt.status == RT.Status.PASSED, "real PASSED after final objective")

	# Timeout: limit 10s, progress once, then overrun.
	var rt2 = RT.new(Def.from_dict({
		"id": "t2", "title": "t", "description": "t",
		"objectives": [{"type": "GoTo", "targetId": "a"}, {"type": "GoTo", "targetId": "b"}],
		"rewards": {"money": 0},
		"timeLimitSec": 10.0,
	}))
	rt2.start()
	rt2.update(4.0)
	_check(counts, rt2.status == RT.Status.ACTIVE, "real still ACTIVE before limit")
	rt2.advance_on_event({"type": "Arrived", "target_id": "a"})
	rt2.update(6.5)
	_check(counts, rt2.status == RT.Status.FAILED, "real FAILED past time limit")
	_check(counts, not rt2.advance_on_event({"type": "Arrived", "target_id": "b"}) and rt2.status == RT.Status.FAILED, "real terminal FAILED is sticky")

	# Partial counts return false until the quota is met.
	var rt3 = RT.new(Def.from_dict({
		"id": "t3", "title": "t", "description": "t",
		"objectives": [{"type": "Collect", "itemId": "cargo_crate", "count": 3}],
		"rewards": {"money": 0},
		"timeLimitSec": 60.0,
	}))
	rt3.start()
	_check(counts, not rt3.advance_on_event({"type": "Collect", "item_id": "cargo_crate", "amount": 2}) and rt3.status == RT.Status.ACTIVE, "real partial collect (2/3) returns false")
	_check(counts, rt3.advance_on_event({"type": "Collect", "item_id": "cargo_crate", "amount": 1}) and rt3.status == RT.Status.PASSED, "real final collect completes mission")
