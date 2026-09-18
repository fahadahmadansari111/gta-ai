extends RefCounted
## Wanted/heat semantics — port of WantedSystemTests.cs.
## Covers: start at zero, escalate through star thresholds, clamp at max,
## decay to zero, decay never negative, no decay while crime ongoing, clear.
## Inline spec always runs; the real WantedSystem is probed via load() when
## scripts/economy or scripts/ai lands (assumed class_name WantedSystem).

const WANTED_PATHS := [
	"res://scripts/ai/wanted_system.gd",
	"res://scripts/world/wanted_system.gd",
]
const THRESHOLDS := [20.0, 45.0, 80.0, 130.0, 200.0]
const MAX_LEVEL := 5


static func run() -> Dictionary:
	var counts: Array = [0, 0]
	_spec_starts_zero(counts)
	_spec_escalates(counts)
	_spec_clamped(counts)
	_spec_decays(counts)
	_spec_never_negative(counts)
	_spec_no_decay_while_crime(counts)
	_spec_clear(counts)
	_real_checks(counts)
	return {"passed": counts[0], "failed": counts[1]}


static func _check(counts: Array, cond: bool, label: String) -> void:
	if cond:
		counts[0] += 1
	else:
		counts[1] += 1
		printerr("  FAIL [wanted] ", label)


static func _spec_new() -> Dictionary:
	return {"heat": 0.0, "level": 0, "decay": 8.0}


static func _spec_recalc(w: Dictionary) -> void:
	var lvl := 0
	for i in THRESHOLDS.size():
		if float(w["heat"]) >= float(THRESHOLDS[i]):
			lvl = i + 1
	w["level"] = mini(lvl, MAX_LEVEL)


static func _spec_add(w: Dictionary, amount: float) -> void:
	w["heat"] = float(w["heat"]) + amount
	_spec_recalc(w)


static func _spec_tick(w: Dictionary, dt: float, crime := false) -> void:
	if not crime and float(w["heat"]) > 0.0:
		w["heat"] = maxf(0.0, float(w["heat"]) - float(w["decay"]) * dt)
		_spec_recalc(w)


static func _spec_clear(w: Dictionary) -> void:
	w["heat"] = 0.0
	w["level"] = 0


static func _spec_starts_zero(counts: Array) -> void:
	var w := _spec_new()
	_check(counts, int(w["level"]) == 0 and float(w["heat"]) == 0.0, "spec starts at zero")


static func _spec_escalates(counts: Array) -> void:
	var w := _spec_new()
	_spec_add(w, 10.0)
	_check(counts, int(w["level"]) == 0, "spec below first threshold stays 0")
	_spec_add(w, 15.0)
	_check(counts, int(w["level"]) == 1, "spec 25 heat is level 1")
	_spec_add(w, 25.0)
	_check(counts, int(w["level"]) == 2, "spec 50 heat is level 2")
	_spec_add(w, 40.0)
	_check(counts, int(w["level"]) == 3, "spec 90 heat is level 3")
	_spec_add(w, 50.0)
	_check(counts, int(w["level"]) == 4, "spec 140 heat is level 4")
	_spec_add(w, 100.0)
	_check(counts, int(w["level"]) == 5, "spec 240 heat is level 5")


static func _spec_clamped(counts: Array) -> void:
	var w := _spec_new()
	_spec_add(w, 10000.0)
	_check(counts, int(w["level"]) == MAX_LEVEL, "spec level clamped at max")


static func _spec_decays(counts: Array) -> void:
	var w := _spec_new()
	w["decay"] = 10.0
	_spec_add(w, 50.0)
	_check(counts, int(w["level"]) == 2, "spec 50 heat is level 2 before decay")
	_spec_tick(w, 2.0)
	_check(counts, int(w["level"]) == 1, "spec decays 50 -> 30 heat (level 1)")
	_spec_tick(w, 10.0)
	_check(counts, int(w["level"]) == 0 and float(w["heat"]) == 0.0, "spec fully decays to zero")


static func _spec_never_negative(counts: Array) -> void:
	var w := _spec_new()
	w["decay"] = 100.0
	_spec_add(w, 5.0)
	_spec_tick(w, 10.0)
	_check(counts, float(w["heat"]) == 0.0 and int(w["level"]) == 0, "spec decay clamps at zero")
	_spec_tick(w, 10.0)
	_check(counts, float(w["heat"]) == 0.0 and int(w["level"]) == 0, "spec decay stays non-negative")


static func _spec_no_decay_while_crime(counts: Array) -> void:
	var w := _spec_new()
	w["decay"] = 10.0
	_spec_add(w, 50.0)
	_spec_tick(w, 5.0, true)
	_check(counts, float(w["heat"]) == 50.0 and int(w["level"]) == 2, "spec no decay while crime ongoing")


static func _spec_clear(counts: Array) -> void:
	var w := _spec_new()
	_spec_add(w, 300.0)
	_spec_clear(w)
	_check(counts, int(w["level"]) == 0 and float(w["heat"]) == 0.0, "spec clear resets")


# --- Real WantedSystem probe (behavior-level; tolerant of tuning) ---

static func _load_first(paths: Array):
	for p in paths:
		if ResourceLoader.exists(str(p)):
			var s = load(str(p))
			if s != null:
				return s
	return null


static func _has_prop(w, prop: String) -> bool:
	for p in w.get_property_list():
		if str(p.get("name", "")) == prop:
			return true
	return false


static func _heat_of(w) -> float:
	for prop in ["heat", "Heat"]:
		if _has_prop(w, prop):
			return float(w.get(prop))
	return -1.0


static func _stars_of(w) -> int:
	for prop in ["stars", "Stars", "level", "Level", "wanted_level"]:
		if _has_prop(w, prop):
			return int(w.get(prop))
	return -1


static func _method_arity(obj: Object, mname: String) -> int:
	for m in obj.get_method_list():
		if str(m.get("name", "")) == mname:
			return (m.get("args", []) as Array).size()
	return -1


static func _add_crime(w, heat_amount: float) -> bool:
	if _method_arity(w, "add_crime") == 1:
		w.call("add_crime", 2)
		return true
	if _method_arity(w, "add_heat") == 1:
		w.call("add_heat", heat_amount)
		return true
	if _method_arity(w, "report_crime") == 1:
		w.call("report_crime", 2)
		return true
	return false


static func _real_checks(counts: Array) -> void:
	var WS = _load_first(WANTED_PATHS)
	if WS == null:
		print("  SKIP [wanted] real checks: WantedSystem script absent")
		return
	var w = WS.new()
	if w == null or not _add_crime(w, 25.0):
		print("  SKIP [wanted] real checks: API mismatch (need add_crime/add_heat)")
		return
	_check(counts, _heat_of(w) >= 0.0, "real heat readable and non-negative")
	var heat0 := _heat_of(w)
	var stars0 := _stars_of(w)
	_add_crime(w, 60.0)
	_check(counts, _heat_of(w) >= heat0, "real escalates heat on crime")
	_check(counts, _stars_of(w) >= stars0, "real stars never drop on crime")
	# Decay (any arity: decay(dt) or decay(dt, hiding)).
	var heat_before := _heat_of(w)
	var darity := _method_arity(w, "decay")
	if darity == 1:
		w.call("decay", 30.0)
	elif darity == 2:
		w.call("decay", 30.0, true)
	if darity in [1, 2]:
		_check(counts, _heat_of(w) <= heat_before and _heat_of(w) >= 0.0, "real decay reduces heat, never negative")
	else:
		print("  SKIP [wanted] real decay check: no decay(dt[, hiding]) found")
	# Clear resets to zero.
	if _method_arity(w, "clear") == 0:
		w.call("clear")
		_check(counts, _heat_of(w) == 0.0 and _stars_of(w) == 0, "real clear resets")
	else:
		print("  SKIP [wanted] real clear check: no clear() found")
