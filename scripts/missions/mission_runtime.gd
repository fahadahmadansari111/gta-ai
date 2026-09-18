class_name MissionRuntime
extends RefCounted

## Tracks a single run of a MissionDefinition.
## Sequential objectives, timeout fail, out-of-order events ignored.
## Terminal states (PASSED/FAILED) are sticky. Mirrors C# MissionRuntime.

enum Status { INACTIVE, ACTIVE, PASSED, FAILED }

var definition: MissionDefinition
var status: Status = Status.INACTIVE
var current_index: int = 0
var elapsed_seconds: float = 0.0
var context: Dictionary = MissionObjective.new_context()


func _init(def: MissionDefinition = null) -> void:
	if def == null:
		definition = MissionDefinition.new()
	else:
		definition = def


func current_objective() -> MissionObjective:
	if definition == null or definition.objectives.is_empty():
		return null
	if current_index < 0 or current_index >= definition.objectives.size():
		return null
	return definition.objectives[current_index]


func is_terminal() -> bool:
	return status == Status.PASSED or status == Status.FAILED


## Begin the run. Resets elapsed time, objective index and context.
## No-op when already Active. Empty objective list => instantly PASSED.
func start() -> void:
	if status == Status.ACTIVE:
		return
	context = MissionObjective.new_context()
	elapsed_seconds = 0.0
	current_index = 0
	status = Status.ACTIVE
	if definition == null or definition.objectives.is_empty():
		status = Status.PASSED


## Advance the clock. Handles Survive objectives and timeout fail.
func update(dt: float) -> void:
	if status != Status.ACTIVE:
		return
	if dt < 0.0:
		push_error("MissionRuntime.update: dt must be >= 0.")
		return
	elapsed_seconds += dt
	context["survived_seconds"] = float(context.get("survived_seconds", 0.0)) + dt
	_drain_completed()
	if status != Status.ACTIVE:
		return
	if definition != null and definition.time_limit_sec > 0.0 and elapsed_seconds >= definition.time_limit_sec:
		fail()


## Feed one domain event into the current objective.
## Out-of-order / foreign events are ignored. Returns true only if the
## event advanced the objective index or completed the mission, so partial
## counts (e.g. 1 of 3 kills) return false — mirrors C# semantics.
func advance_on_event(evt: Dictionary) -> bool:
	if evt.is_empty():
		push_error("MissionRuntime.advance_on_event: evt must not be empty.")
		return false
	if status != Status.ACTIVE:
		return false
	var current: MissionObjective = current_objective()
	if current == null:
		return false
	if not current.accepts(evt):
		return false
	current.apply_progress(context, evt)
	var before: int = current_index
	_drain_completed()
	return current_index != before or status == Status.PASSED


## Force-fail an active run (e.g. player died / busted / quit).
func fail() -> void:
	if status == Status.ACTIVE:
		status = Status.FAILED


func _drain_completed() -> void:
	while status == Status.ACTIVE:
		var current: MissionObjective = current_objective()
		if current == null:
			status = Status.PASSED
			return
		if not current.is_completed(context):
			return
		current_index += 1
		if definition == null or current_index >= definition.objectives.size():
			status = Status.PASSED
			return
