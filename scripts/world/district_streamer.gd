extends Node
class_name DistrictStreamer
## Phase 1C district streamer (Godot port of Unity DistrictStreamer.cs).
## Polls player XZ at 2Hz and additively loads/unloads 500x500m districts
## named res://scenes/district_X_Z.tscn via pure-logic ChunkStreamer math.
## NOTE: Unity Addressables have no Godot equivalent; plain PackedScene
## load/instantiate is the replacement (no handle tracking needed).

signal districts_changed(active: Array)

@export var player_path: NodePath
@export var load_radius_chunks: int = 1
@export var poll_interval_seconds: float = 0.5
@export var world_size_meters: float = 2000.0
@export var district_size_meters: float = 500.0

var _streamer: ChunkStreamer
var _active: Dictionary = {}
var _loaded_nodes: Dictionary = {}
var _timer: float = 0.0
var _player: Node3D


func _ready() -> void:
	_streamer = ChunkStreamer.new(world_size_meters, district_size_meters)
	_player = get_node_or_null(player_path) as Node3D


func _process(delta: float) -> void:
	if _player == null:
		return
	_timer += delta
	if _timer < poll_interval_seconds:
		return
	_timer = 0.0
	poll(_player.global_position.x, _player.global_position.z)


func poll(x: float, z: float) -> void:
	var next: Array = _streamer.get_active_set(x, z, maxi(0, load_radius_chunks))
	var diff: Dictionary = ChunkStreamer.diff(_active.keys(), next)
	var to_load: Array = diff.get("to_load", [])
	var to_unload: Array = diff.get("to_unload", [])
	if to_load.is_empty() and to_unload.is_empty():
		return
	for id in to_load:
		_load_district(id)
	for id in to_unload:
		_unload_district(id)
	_active.clear()
	for id in next:
		_active[id] = true
	districts_changed.emit(_active.keys())


static func district_scene_path(id: Vector2i) -> String:
	return "res://scenes/district_%d_%d.tscn" % [id.x, id.y]


func _load_district(id: Vector2i) -> void:
	if _loaded_nodes.has(id):
		return
	var path: String = district_scene_path(id)
	if not ResourceLoader.exists(path):
		push_warning("[DistrictStreamer] Missing district scene: " + path)
		return
	var packed: PackedScene = load(path) as PackedScene
	if packed == null:
		push_warning("[DistrictStreamer] Failed to load: " + path)
		return
	var node: Node = packed.instantiate()
	node.name = "District_%d_%d" % [id.x, id.y]
	_loaded_nodes[id] = node
	# TODO Phase 1C: add Boot-screen loading wedge + retry on failure.
	call_deferred("add_child", node)


func _unload_district(id: Vector2i) -> void:
	if not _loaded_nodes.has(id):
		return
	var node: Node = _loaded_nodes[id] as Node
	_loaded_nodes.erase(id)
	if is_instance_valid(node):
		remove_child(node)
		node.queue_free()
