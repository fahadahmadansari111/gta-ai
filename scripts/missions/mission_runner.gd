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


func _ready() -> void:
	_hud = get_node_or_null(hud_path) as MissionHUD
	if not start_mission(mission_id):
		push_warning("[MissionRunner] No mission loaded for id: " + mission_id)
	_wire_trigger_zones()


func _process(delta: float) -> void:
	if runtime == null:
		return
	runtime.update(delta)
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
	runtime.mission_passed.connect(_on_runtime_passed)
	runtime.mission_failed.connect(_on_runtime_failed)
	runtime.objective_changed.connect(_on_runtime_objective_changed)
	runtime.start()
	return true


## Manual event feed for UI buttons / tests.
func feed_event(evt: ObjectiveEvent) -> bool:
	if runtime == null or evt == null:
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
	runtime.advance_on_event(ArrivedEvent.new(target_id))


func _push_hud() -> void:
	if _hud == null or runtime == null:
		return
	_hud.show_objective(runtime.current_objective_label())
	_hud.update_timer(runtime.remaining_seconds(), runtime.total_seconds())


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
