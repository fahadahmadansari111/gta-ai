class_name MissionGraph
extends RefCounted

## Registry + unlock graph over mission definitions.
## Completion persistence is caller-owned (external Array) plus an internal
## completed set; can_start/available union both. String compare is ordinal
## (GDScript == is exact, case-sensitive). Mirrors C# MissionGraph.

var _missions: Dictionary = {}
var _completed: Dictionary = {}


func count() -> int:
	return _missions.size()


func register(def: MissionDefinition) -> void:
	if def == null or def.id == "":
		push_error("MissionGraph.register: mission id must be non-empty.")
		return
	_missions[def.id] = def


func has(id: String) -> bool:
	return _missions.has(id)


func get_definition(id: String) -> MissionDefinition:
	return _missions.get(id, null)


func is_completed(id: String) -> bool:
	return _completed.has(id)


func completed_ids() -> Array:
	return _completed.keys()


func mark_completed(id: String) -> void:
	if not _missions.has(id):
		push_error("MissionGraph.mark_completed: unknown mission id '%s'." % id)
		return
	_completed[id] = true


## Can the mission be started given an external completed set?
func can_start(id: String, external_completed: Array = []) -> bool:
	if not _missions.has(id):
		return false
	var completed: Dictionary = {}
	for c: Variant in external_completed:
		completed[str(c)] = true
	for k: Variant in _completed.keys():
		completed[k] = true
	if completed.has(id):
		return false
	var def: MissionDefinition = _missions[id]
	var required: String = def.required_mission_id
	if required == "":
		return true
	return completed.has(required)


## All definitions that are startable and not yet completed.
func available(external_completed: Array = []) -> Array[MissionDefinition]:
	var completed: Dictionary = {}
	for c: Variant in external_completed:
		completed[str(c)] = true
	for k: Variant in _completed.keys():
		completed[k] = true
	var result: Array[MissionDefinition] = []
	for key: Variant in _missions.keys():
		var def: MissionDefinition = _missions[key]
		if completed.has(def.id):
			continue
		if def.required_mission_id != "" and not completed.has(def.required_mission_id):
			continue
		result.append(def)
	return result
