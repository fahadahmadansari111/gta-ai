extends Node
class_name Boot
## Persistent boot node (Godot port of Unity Boot scene flow, Scene_List.md).
## Loaded first, never unloaded: caps fps at 60, loads MainCity_Persistent
## deferred/additive, then lets DistrictStreamer take over district slices.

signal boot_completed

@export var main_city_scene: String = "res://scenes/main_city.tscn"
@export var target_fps: int = 60
@export var district_streamer_path: NodePath
@export var traffic_pool_path: NodePath

var _main_city: Node


func _ready() -> void:
	Engine.max_fps = target_fps
	# Connect autoloads (GameState assumed as /root autoload singleton).
	# TODO: GameState.state_changed.connect(...) once autoload signal lands.
	if get_node_or_null("/root/GameState") == null:
		push_warning("[Boot] GameState autoload not found; continuing without it.")
	call_deferred("_load_main_city")


func _load_main_city() -> void:
	if not ResourceLoader.exists(main_city_scene):
		push_warning("[Boot] Missing main city scene: " + main_city_scene)
		boot_completed.emit()
		return
	var packed: PackedScene = load(main_city_scene) as PackedScene
	if packed == null:
		push_warning("[Boot] Failed to load main city scene: " + main_city_scene)
		boot_completed.emit()
		return
	_main_city = packed.instantiate()
	_main_city.name = "MainCity_Persistent"
	add_child(_main_city)
	boot_completed.emit()
