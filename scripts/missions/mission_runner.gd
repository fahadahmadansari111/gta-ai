extends Node
class_name MissionRunner
## Node bridge over pure-logic MissionRuntime
## (Godot port of Unity MissionRunner.cs).
## Loads res://data/missions/<mission_id>.json via FileAccess + JSON,
## builds a MissionDefinition, ticks MissionRuntime in _process, and feeds
## Area3D trigger zones (body_entered -> arrived advance).

signal mission_passed(mission_id: String)
signal mission_failed(mission_id: String, reason: String)
signal objective_changed(label: String)

@export var mission_id: String = "M01_Neon_Delivery"
@export var hud_path: NodePath
@export var trigger_root_path: NodePath

var definition: MissionDefinition
var runtime: MissionRuntime

var _hud: MissionHUD
var _last_status: int = -1
var _last_index: int = -1


func _ready() -> void:
	_hud = get_node_or_null(hud_path) as MissionHUD
	if not start_mission(mission_id):
		push_warning("[MissionRunner] No mission loaded for id: " + mission_id)
	_wire_trigger_zones()


func _process(delta: float) -> void:
	if runtime == null:
		return
	runtime.update(delta)
	# MissionRuntime is signal-free pure logic: detect transitions by polling.
	var st: int = runtime.status
	if st != _last_status:
		_last_status = st
		if st == MissionRuntime.Status.PASSED:
			_on_runtime_passed(mission_id)
		elif st == MissionRuntime.Status.FAILED:
			_on_runtime_failed(mission_id, "Mission failed")
	if runtime.current_index != _last_index:
		_last_index = runtime.current_index
		_on_runtime_objective_changed(_objective_label())
	_push_hud()


## Load data/missions/<id>.json and (re)build the runtime. Returns success.
func start_mission(id: String) -> bool:
	var path: String = "res://data/missions/%s.json" % id
	if not FileAccess.file_exists(path):
		push_error("[MissionRunner] Missing mission file: " + path)
		return false
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("[MissionRunner] Cannot open mission file: " + path)
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("[MissionRunner] Invalid mission JSON: " + path)
		return false
	definition = MissionDefinition.from_dict(parsed)
	runtime = MissionRuntime.new(definition)
	runtime.start()
	_last_status = -1
	_last_index = -1
	return true


## Manual event feed for UI buttons / tests. Events are plain Dictionaries,
## e.g. MissionEvents.arrived(target_id).
func feed_event(evt: Dictionary) -> bool:
	if runtime == null or evt.is_empty():
		return false
	return runtime.advance_on_event(evt)


## Connect Area3D children under trigger_root: each zone name must equal the
## objective target_id (same convention as the Unity name-match stub).
## TODO Phase 1: use a dedicated TriggerZone Area3D script with explicit target_id.
func _wire_trigger_zones() -> void:
	var root: Node = get_node_or_null(trigger_root_path) if not trigger_root_path.is_empty() else get_parent()
	if root == null:
		return
	for child in root.find_children("*", "Area3D", true, false):
		var area: Area3D = child as Area3D
		if area == null:
			continue
		if not area.body_entered.is_connected(_on_trigger_body_entered.bind(area)):
			area.body_entered.connect(_on_trigger_body_entered.bind(area))


func _on_trigger_body_entered(_body: Node3D, area: Area3D) -> void:
	if runtime == null or area == null:
		return
	# Convention: trigger Area3D node name == target_id.
	var target_id: String = area.name
	runtime.advance_on_event(MissionEvents.arrived(target_id))


## Human-readable label for the current objective, e.g. "GoTo gate (1/3)".
func _objective_label() -> String:
	if runtime == null or runtime.definition == null:
		return ""
	var total: int = runtime.definition.objectives.size()
	var cur: MissionObjective = runtime.current_objective()
	if cur == null:
		return "Done (%d/%d)" % [mini(runtime.current_index, total), total]
	var base: String = cur.objective_type()
	match cur.kind:
		MissionObjective.Kind.GO_TO:
			base += " " + cur.target_id
		MissionObjective.Kind.KILL:
			base += " %s x%d" % [cur.target_id, cur.count]
		MissionObjective.Kind.COLLECT:
			base += " %s x%d" % [cur.item_id, cur.count]
		MissionObjective.Kind.DELIVER:
			base += " " + cur.destination_id
		MissionObjective.Kind.SURVIVE:
			base += " %ds" % int(cur.seconds)
		MissionObjective.Kind.RACE_CHECKPOINT:
			base += " #%d" % cur.checkpoint_index
	return "%s (%d/%d)" % [base, mini(runtime.current_index, total), total]


func _push_hud() -> void:
	if _hud == null or runtime == null or runtime.definition == null:
		return
	_hud.show_objective(_objective_label())
	var total_sec: float = runtime.definition.time_limit_sec
	var remaining_sec: float = maxf(0.0, total_sec - runtime.elapsed_seconds)
	_hud.update_timer(remaining_sec, total_sec)


func _on_runtime_passed(id: String) -> void:
	if _hud != null and definition != null:
		_hud.show_success("Reward $%d" % definition.reward_money)
	mission_passed.emit(id)


func _on_runtime_failed(id: String, reason: String) -> void:
	if _hud != null:
		_hud.show_fail(reason)
	mission_failed.emit(id, reason)


func _on_runtime_objective_changed(label: String) -> void:
	if _hud != null:
		_hud.show_objective(label)
	objective_changed.emit(label)
