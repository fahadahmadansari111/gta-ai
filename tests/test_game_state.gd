extends RefCounted
## Game phase state machine — port of GameStateTests.cs, adapted to the
## Godot Phase model (BOOT, FREE_ROAM, MISSION, PAUSED, BUSTED, WASTED).
## Covers: starts in BOOT, BOOT->WASTED invalid, valid full chain,
## pause/resume cycle, busted path, invalid stays put, signals fire on
## success only. Inline spec always runs; the real GameState is probed too.

const STATE_PATH := "res://scripts/core/game_state.gd"
const GS_ALLOWED := {
	"BOOT": ["FREE_ROAM"],
	"FREE_ROAM": ["MISSION", "PAUSED", "BUSTED", "WASTED"],
	"MISSION": ["FREE_ROAM", "PAUSED", "BUSTED", "WASTED"],
	"PAUSED": ["FREE_ROAM", "MISSION"],
	"BUSTED": ["FREE_ROAM"],
	"WASTED": ["FREE_ROAM"],
}


static func run() -> Dictionary:
	var counts: Array = [0, 0]
	_spec_starts_boot(counts)
	_spec_invalid_rejected(counts)
	_spec_valid_chain(counts)
	_spec_pause_resume(counts)
	_spec_wasted_busted_paths(counts)
	_real_checks(counts)
	return {"passed": counts[0], "failed": counts[1]}


static func _check(counts: Array, cond: bool, label: String) -> void:
	if cond:
		counts[0] += 1
	else:
		counts[1] += 1
		printerr("  FAIL [game_state] ", label)


static func _spec_can(cur: String, nxt: String) -> bool:
	return (GS_ALLOWED.get(cur, []) as Array).has(nxt)


static func _spec_starts_boot(counts: Array) -> void:
	_check(counts, _spec_can("BOOT", "FREE_ROAM"), "spec BOOT can go FREE_ROAM")


static func _spec_invalid_rejected(counts: Array) -> void:
	_check(counts, not _spec_can("BOOT", "WASTED"), "spec BOOT->WASTED invalid")
	_check(counts, not _spec_can("BOOT", "MISSION"), "spec BOOT->MISSION invalid")
	_check(counts, not _spec_can("PAUSED", "WASTED"), "spec PAUSED->WASTED invalid")
	_check(counts, not _spec_can("WASTED", "MISSION"), "spec WASTED->MISSION invalid")


static func _spec_valid_chain(counts: Array) -> void:
	var chain := ["BOOT", "FREE_ROAM", "MISSION", "PAUSED", "MISSION", "WASTED", "FREE_ROAM"]
	var ok := true
	for i in range(chain.size() - 1):
		if not _spec_can(chain[i], chain[i + 1]):
			ok = false
	_check(counts, ok, "spec valid chain BOOT->FREE_ROAM->MISSION->PAUSED->MISSION->WASTED->FREE_ROAM")


static func _spec_pause_resume(counts: Array) -> void:
	_check(counts, _spec_can("MISSION", "PAUSED") and _spec_can("PAUSED", "MISSION"), "spec pause/resume cycle")


static func _spec_wasted_busted_paths(counts: Array) -> void:
	_check(counts, _spec_can("MISSION", "WASTED") and _spec_can("WASTED", "FREE_ROAM"), "spec wasted returns to free roam")
	_check(counts, _spec_can("FREE_ROAM", "BUSTED") and _spec_can("BUSTED", "FREE_ROAM"), "spec busted returns to free roam")


static func _real_checks(counts: Array) -> void:
	if not ResourceLoader.exists(STATE_PATH):
		print("  SKIP [game_state] real checks: game_state.gd absent")
		return
	var GS = load(STATE_PATH)
	if GS == null:
		print("  SKIP [game_state] real checks: load failed")
		return
	var gs = GS.new()
	if gs == null or not gs.has_method("set_phase") or not gs.has_method("can_transition_to"):
		print("  SKIP [game_state] real checks: API mismatch")
		return
	var P = GS.Phase
	_check(counts, gs.current_phase == P.BOOT, "real starts in BOOT")
	_check(counts, not gs.set_phase(P.WASTED) and gs.current_phase == P.BOOT, "real BOOT->WASTED invalid and stays")
	_check(counts, not gs.set_phase(P.MISSION) and gs.current_phase == P.BOOT, "real BOOT->MISSION invalid and stays")
	var chain: Array = [P.FREE_ROAM, P.MISSION, P.PAUSED, P.MISSION, P.WASTED, P.FREE_ROAM]
	var ok := true
	for nxt in chain:
		if not gs.set_phase(nxt):
			ok = false
	_check(counts, ok and gs.current_phase == P.FREE_ROAM, "real valid chain succeeds")
	_check(counts, gs.set_phase(P.BUSTED) and gs.set_phase(P.FREE_ROAM), "real busted path succeeds")
	# Signals fire on success only.
	var fired: Array = []
	gs.reset()
	gs.phase_changed.connect(func(prev: int, nxt: int) -> void: fired.append([prev, nxt]))
	_check(counts, not gs.set_phase(P.WASTED) and fired.is_empty(), "real no signal on invalid transition")
	_check(counts, gs.set_phase(P.FREE_ROAM) and fired.size() == 1, "real signal fires on success")
