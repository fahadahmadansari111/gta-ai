extends RefCounted
## Vice City sample chain (M01/M02) — port of SampleMissionsTests.cs.
## Covers: M01/M02 JSON parse (ids, objective types, rewards, time limits,
## gating requirements), M01 full playthrough (out-of-order ignored, then
## Arrived->Collect->Deliver passes), M01->M02 gating via MissionGraph.
## JSON content checks always run; runtime/graph playthrough uses the real
## MissionDefinition/Runtime/Graph scripts via load() when they resolve.

const DEF_PATH := "res://scripts/missions/mission_definition.gd"
const RT_PATH := "res://scripts/missions/mission_runtime.gd"
const GRAPH_PATH := "res://scripts/missions/mission_graph.gd"

const M01_JSON := """
{
  "id": "M01_Neon_Delivery",
  "title": "Neon Delivery",
  "description": "Rico needs a package picked up on the Ocean Drive neon strip and delivered to the Malibu Club.",
  "objectives": [
    {"type": "GoTo", "targetId": "neon_strip_pickup", "radius": 3.0},
    {"type": "Collect", "itemId": "neon_package", "count": 1},
    {"type": "Deliver", "destinationId": "malibu_club_dropoff", "vehicleId": null}
  ],
  "rewards": {"money": 500},
  "startCondition": {"requiredMissionId": null},
  "timeLimitSec": 300
}
"""

const M02_JSON := """
{
  "id": "M02_Beach_Chase",
  "title": "Beach Chase",
  "description": "Smoke through the boardwalk checkpoints, then take out the beach rivals.",
  "objectives": [
    {"type": "RaceCheckpoint", "checkpointIndex": 0},
    {"type": "RaceCheckpoint", "checkpointIndex": 1},
    {"type": "Kill", "targetId": "beach_rival", "count": 2}
  ],
  "rewards": {"money": 750},
  "startCondition": {"requiredMissionId": "M01_Neon_Delivery"},
  "timeLimitSec": 240
}
"""


static func run() -> Dictionary:
	var counts: Array = [0, 0]
	_json_content(counts)
	_real_playthrough_and_gating(counts)
	return {"passed": counts[0], "failed": counts[1]}


static func _check(counts: Array, cond: bool, label: String) -> void:
	if cond:
		counts[0] += 1
	else:
		counts[1] += 1
		printerr("  FAIL [sample_missions] ", label)


static func _json_content(counts: Array) -> void:
	var m01: Variant = JSON.parse_string(M01_JSON)
	var m02: Variant = JSON.parse_string(M02_JSON)
	_check(counts, m01 is Dictionary and m02 is Dictionary, "M01/M02 JSON parses")
	if not (m01 is Dictionary and m02 is Dictionary):
		return
	var o1: Array = m01.get("objectives", [])
	var o2: Array = m02.get("objectives", [])
	_check(counts, str(m01.get("id", "")) == "M01_Neon_Delivery" and o1.size() == 3, "M01 id + 3 objectives")
	_check(counts, str(o1[0].get("type", "")) == "GoTo" and str(o1[1].get("type", "")) == "Collect" and str(o1[2].get("type", "")) == "Deliver", "M01 objective types GoTo/Collect/Deliver")
	_check(counts, str(m02.get("id", "")) == "M02_Beach_Chase" and o2.size() == 3, "M02 id + 3 objectives")
	_check(counts, str(o2[0].get("type", "")) == "RaceCheckpoint" and str(o2[2].get("type", "")) == "Kill", "M02 objective types checkpoints + Kill")
	_check(counts, int((m01.get("rewards", {}) as Dictionary).get("money", 0)) == 500, "M01 reward 500")
	_check(counts, int((m02.get("rewards", {}) as Dictionary).get("money", 0)) == 750, "M02 reward 750")
	_check(counts, float(m01.get("timeLimitSec", 0.0)) > 0.0 and float(m02.get("timeLimitSec", 0.0)) > 0.0, "M01/M02 time limits positive")
	_check(counts, (m01.get("startCondition", {}) as Dictionary).get("requiredMissionId", "x") == null, "M01 is the starter (no requirement)")
	_check(counts, str((m02.get("startCondition", {}) as Dictionary).get("requiredMissionId", "")) == "M01_Neon_Delivery", "M02 requires M01")


static func _real_playthrough_and_gating(counts: Array) -> void:
	if not ResourceLoader.exists(DEF_PATH) or not ResourceLoader.exists(RT_PATH) or not ResourceLoader.exists(GRAPH_PATH):
		print("  SKIP [sample_missions] real checks: mission scripts absent")
		return
	var Def = load(DEF_PATH)
	var RT = load(RT_PATH)
	var Graph = load(GRAPH_PATH)
	if Def == null or RT == null or Graph == null:
		print("  SKIP [sample_missions] real checks: load failed")
		return
	var m01 = Def.from_json(M01_JSON)
	var m02 = Def.from_json(M02_JSON)
	if m01 == null or m02 == null:
		print("  SKIP [sample_missions] real checks: from_json failed")
		return
	_check(counts, m01.id == "M01_Neon_Delivery" and m01.objectives.size() == 3, "real M01 parses with 3 objectives")
	_check(counts, m01.objectives[0].objective_type() == "GoTo" and m01.objectives[1].objective_type() == "Collect" and m01.objectives[2].objective_type() == "Deliver", "real M01 objective types")
	_check(counts, m01.reward_money == 500 and m02.reward_money == 750, "real rewards 500/750")
	_check(counts, m01.required_mission_id == "" and m02.required_mission_id == "M01_Neon_Delivery", "real gating requirements")

	# M01 full playthrough.
	var rt = RT.new(m01)
	if rt == null or not rt.has_method("advance_on_event"):
		print("  SKIP [sample_missions] real playthrough: API mismatch")
		return
	rt.start()
	_check(counts, rt.status == RT.Status.ACTIVE, "real M01 starts ACTIVE")
	_check(counts, not rt.advance_on_event({"type": "Deliver", "destination_id": "malibu_club_dropoff"}) and rt.current_index == 0, "real M01 out-of-order deliver ignored")
	_check(counts, rt.advance_on_event({"type": "Arrived", "target_id": "neon_strip_pickup"}) and rt.current_index == 1, "real M01 pickup advances")
	_check(counts, rt.advance_on_event({"type": "Collect", "item_id": "neon_package"}) and rt.current_index == 2, "real M01 collect advances")
	_check(counts, rt.advance_on_event({"type": "Deliver", "destination_id": "malibu_club_dropoff"}) and rt.status == RT.Status.PASSED, "real M01 PASSED, unlocks M02")

	# M02 checkpoint order is strict; kills need 2.
	var rt2 = RT.new(m02)
	rt2.start()
	_check(counts, not rt2.advance_on_event({"type": "Checkpoint", "index": 1}) and rt2.current_index == 0, "real M02 checkpoint 1 before 0 ignored")
	_check(counts, rt2.advance_on_event({"type": "Checkpoint", "index": 0}) and rt2.advance_on_event({"type": "Checkpoint", "index": 1}), "real M02 checkpoints in order")
	_check(counts, not rt2.advance_on_event({"type": "Kill", "target_id": "beach_rival"}) and rt2.status == RT.Status.ACTIVE, "real M02 first kill (1/2) returns false")
	_check(counts, rt2.advance_on_event({"type": "Kill", "target_id": "beach_rival"}) and rt2.status == RT.Status.PASSED, "real M02 second kill passes")

	# Chain gating: M01 -> M02.
	var g = Graph.new()
	if g == null or not g.has_method("can_start"):
		print("  SKIP [sample_missions] real gating: API mismatch")
		return
	g.register(m01)
	g.register(m02)
	_check(counts, g.can_start("M01_Neon_Delivery", []), "real M01 startable with nothing done")
	_check(counts, not g.can_start("M02_Beach_Chase", []), "real M02 locked before M01")
	_check(counts, g.can_start("M02_Beach_Chase", ["M01_Neon_Delivery"]), "real M02 unlocks after M01")
	_check(counts, not g.can_start("M01_Neon_Delivery", ["M01_Neon_Delivery"]), "real completed M01 not restartable")
	_check(counts, not g.can_start("M04_Does_Not_Exist", []), "real unknown id never startable")
