class_name GameState
extends RefCounted
## Top-level game phase state machine. Port of the C# GameState.
## Starts in Phase.BOOT. Invalid transitions fail and leave current_phase unchanged.

enum Phase { BOOT, FREE_ROAM, MISSION, PAUSED, BUSTED, WASTED }

signal phase_changed(previous: int, next: int)
signal state_changed(previous: int, next: int)

const _ALLOWED: Dictionary = {
	Phase.BOOT: [Phase.FREE_ROAM],
	Phase.FREE_ROAM: [Phase.MISSION, Phase.PAUSED, Phase.BUSTED, Phase.WASTED],
	Phase.MISSION: [Phase.FREE_ROAM, Phase.PAUSED, Phase.BUSTED, Phase.WASTED],
	Phase.PAUSED: [Phase.FREE_ROAM, Phase.MISSION],
	Phase.BUSTED: [Phase.FREE_ROAM],
	Phase.WASTED: [Phase.FREE_ROAM],
}

var current_phase: int = Phase.BOOT


func can_transition_to(next: int) -> bool:
	var allowed: Array = _ALLOWED.get(current_phase, [])
	return allowed.has(next)


## Attempt a phase transition. Returns true and emits signals on success;
## returns false and leaves current_phase unchanged on failure.
func set_phase(next: int) -> bool:
	if not can_transition_to(next):
		return false
	var previous: int = current_phase
	current_phase = next
	phase_changed.emit(previous, next)
	state_changed.emit(previous, next)
	return true


## Alias of set_phase kept for C# TransitionTo parity.
func transition_to(next: int) -> bool:
	return set_phase(next)


## Force back to BOOT, emitting signals if the phase changed. Test helper.
func reset() -> void:
	if current_phase == Phase.BOOT:
		return
	var previous: int = current_phase
	current_phase = Phase.BOOT
	phase_changed.emit(previous, Phase.BOOT)
	state_changed.emit(previous, Phase.BOOT)
