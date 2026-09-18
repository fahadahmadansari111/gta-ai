extends CharacterBody3D
class_name PlayerController
## Phase 1A on-foot third-person glue (Godot port of Unity PlayerController.cs).
## Thin node only: CharacterBody3D movement, Input reads, camera-relative wish
## direction, gravity + jump, interact raycast stub, damage passthrough.
## All locomotion math lives in pure-logic PlayerMoveMath; health/armor in
## PlayerStats (sibling class_names, assumed to exist).

signal health_changed(health: float, armor: float)
signal wasted

@export var speed: float = 4.5
@export var accel: float = 24.0
@export var friction: float = 18.0
@export var sprint_mult: float = 1.6
@export var jump_velocity: float = 4.5
@export var gravity: float = 20.0
@export var interact_distance: float = 3.0
@export var mouse_sensitivity: float = 0.003

var stats: PlayerStats
var planar_velocity: Vector2 = Vector2.ZERO
var vertical_velocity: float = 0.0

var _camera: Camera3D
var _interact_ray: RayCast3D


func _ready() -> void:
	stats = PlayerStats.new()
	stats.health_changed.connect(_on_stats_health_changed)
	stats.wasted.connect(_on_stats_wasted)
	_camera = get_viewport().get_camera_3d()
	# TODO Phase 1B: cache follow-camera pivot rig (SpringArm3D) instead of raw viewport camera.
	_interact_ray = RayCast3D.new()
	_interact_ray.target_position = Vector3(0.0, 0.0, -interact_distance)
	_interact_ray.enabled = true
	add_child(_interact_ray)


func _physics_process(delta: float) -> void:
	var stick: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var sprinting: bool = Input.is_action_pressed("sprint")

	# Camera-relative wish direction on the XZ plane.
	var fwd: Vector3 = Vector3.FORWARD
	if _camera != null:
		fwd = -_camera.global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length_squared() > 0.0001 else Vector3.FORWARD
	var right := Vector3(fwd.z, 0.0, -fwd.x)
	var wish: Vector3 = right * stick.x + fwd * -stick.y
	# NOTE: Input.get_vector y is negative-forward; negate to match camera fwd.
	wish.y = 0.0
	if wish.length_squared() > 1.0:
		wish = wish.normalized()

	var target_speed: float = speed * PlayerMoveMath.sprint_multiplier(sprinting, sprint_mult)
	var step: Vector3 = PlayerMoveMath.move_step(
		planar_velocity, Vector2(wish.x, wish.z),
		target_speed, accel, friction, delta)
	planar_velocity = Vector2(step.x, step.z)

	# Gravity + jump integration (delegates constants to PlayerMoveMath).
	if is_on_floor():
		if vertical_velocity < 0.0:
			vertical_velocity = -0.5
		if Input.is_action_just_pressed("jump"):
			vertical_velocity = PlayerMoveMath.jump_velocity(jump_velocity)
	else:
		vertical_velocity = PlayerMoveMath.apply_gravity(vertical_velocity, gravity, delta)

	velocity = Vector3(planar_velocity.x, vertical_velocity, planar_velocity.y)
	move_and_slide()
	# Keep planar readout in sync after slide (matches Unity PlanarVelocity debug prop).
	planar_velocity = Vector2(velocity.x, velocity.z)

	if Input.is_action_just_pressed("interact"):
		try_interact()


## Interact raycast stub for vehicle enter (EnterExitVehicle consumes this).
## Returns the collider or null; vehicle-enter wiring lands in Phase 1B.
func try_interact() -> Object:
	if _interact_ray == null:
		return null
	_interact_ray.force_raycast_update()
	if _interact_ray.is_colliding():
		return _interact_ray.get_collider()
	return null


## Damage passthrough to pure-logic PlayerStats (hazard volumes call this).
func take_damage(amount: float) -> void:
	if stats != null:
		stats.take_damage(amount)


func heal(amount: float) -> void:
	if stats != null:
		stats.heal(amount)


func _on_stats_health_changed(health: float, armor: float) -> void:
	# TODO Phase 1: push to HUD controller (SetHealth/SetArmor bind).
	health_changed.emit(health, armor)


func _on_stats_wasted() -> void:
	# TODO Phase 1: route to GameState wasted flow + respawn UI.
	wasted.emit()
