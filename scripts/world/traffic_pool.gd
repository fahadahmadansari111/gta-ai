extends Node3D
class_name TrafficPool
## Phase 1C traffic/ped pool stub (Godot port of Unity TrafficPoolBridge.cs).
## Prewarms up to 25 pooled actors and reuses them via pure-logic SpawnPool
## slot logic. No per-frame instantiate.

@export var car_scene: PackedScene
@export var ped_scene: PackedScene
@export var max_active: int = 25
@export var pool_root_path: NodePath

var _pool: SpawnPool
var _instances: Array[Node3D] = []
var _slot_by_instance: Dictionary = {}


func _ready() -> void:
	_pool = SpawnPool.new(max_active)
	prewarm()


## Instantiate all pooled actors once, hidden, under the pool root.
func prewarm() -> void:
	var n: int = clampi(max_active, 1, SpawnPool.MAX_TRAFFIC_ACTORS)
	var root: Node = get_node_or_null(pool_root_path) if not pool_root_path.is_empty() else self
	if root == null:
		root = self
	for i in range(n):
		if _instances.size() >= n:
			break
		# Alternate car/ped scenes so the 25-slot budget covers both archetypes.
		var packed: PackedScene = car_scene if i % 2 == 0 else ped_scene
		if packed == null:
			continue
		var actor: Node3D = packed.instantiate() as Node3D
		if actor == null:
			continue
		root.add_child(actor)
		actor.visible = false
		actor.set_process(false)
		actor.set_physics_process(false)
		# TODO Phase 1C: configure per-archetype LOD (car: VisibilityRange x3,
		# ped: x2 + impostor) and shared materials to hold draw calls in budget.
		_instances.append(actor)


## Activate a pooled actor at a transform. Returns null when pool is exhausted.
func try_spawn(spawn_position: Vector3, spawn_rotation_y: float) -> Node3D:
	var slot: int = _pool.try_spawn()
	if slot < 0 or slot >= _instances.size():
		if slot >= 0:
			_pool.despawn(slot)
		return null
	var actor: Node3D = _instances[slot]
	_slot_by_instance[actor.get_instance_id()] = slot
	actor.global_position = spawn_position
	actor.rotation.y = spawn_rotation_y
	actor.visible = true
	actor.set_process(true)
	actor.set_physics_process(true)
	return actor


## Return an actor to the pool (hide + free its slot).
func despawn(actor: Node3D) -> void:
	if actor == null or not is_instance_valid(actor):
		return
	var key: int = actor.get_instance_id()
	if not _slot_by_instance.has(key):
		return
	var slot: int = _slot_by_instance[key]
	_slot_by_instance.erase(key)
	actor.visible = false
	actor.set_process(false)
	actor.set_physics_process(false)
	_pool.despawn(slot)


## Pure-logic occupancy (mirrors visible pooled actors).
func active_count() -> int:
	return _pool.active_count()
