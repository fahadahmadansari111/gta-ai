extends CharacterBody3D
class_name ArcadeCar
## Arcade car glue (Godot port of Unity ArcadeCarController.cs).
## Uses CharacterBody3D (NOT VehicleBody3D) for mobile perf + determinism.
## Reads keyboard Input + mobile override vars, integrates pure-logic
## VehicleMath statics against a VehicleTuning resource.

@export var tuning: VehicleTuning
@export var throttle_action: StringName = &"drive_throttle"
@export var brake_action: StringName = &"drive_brake"
@export var steer_left_action: StringName = &"drive_steer_left"
@export var steer_right_action: StringName = &"drive_steer_right"
@export var reverse_as_brake: bool = true

# Touch button state (wired from on-screen pedals / stick via set_touch_input).
var touch_throttle: float = 0.0
var touch_steer: float = 0.0
var touch_brake: bool = false

# TODO Phase 1B: assign wheel visuals (Array[Node3D]) for spin animation.
@export var wheels: Array[Node3D] = []
@export var wheel_radius: float = 0.35
# TODO Phase 1B: assign drift dust GPUParticles3D, emit when |steer| high + speed high.

var speed_ms: float = 0.0

var speed_kmh: float:
	get:
		return speed_ms * 3.6


func _ready() -> void:
	if tuning == null:
		tuning = VehicleTuning.new()


func set_touch_input(throttle: float, steer: float, brake: bool) -> void:
	touch_throttle = clampf(throttle, 0.0, 1.0)
	touch_steer = clampf(steer, -1.0, 1.0)
	touch_brake = brake


func _physics_process(delta: float) -> void:
	var throttle: float = _get_throttle()
	var steer: float = _get_steer()
	var brake: bool = _is_brake()

	speed_ms = VehicleMath.compute_speed(speed_ms, throttle, brake, tuning, delta)
	var yaw_rate: float = VehicleMath.compute_steer_angle(speed_kmh, steer, tuning)

	# Bicycle-ish: yaw scaled by motion (no turning when parked).
	var motion: float = clampf(speed_ms / 2.0, 0.0, 1.0)
	rotate_y(yaw_rate * motion * delta)

	var forward: Vector3 = -global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized() if forward.length_squared() > 0.0001 else Vector3.FORWARD
	velocity = forward * speed_ms
	move_and_slide()
	# TODO Phase 1B: spin wheels by speed_ms / wheel_radius; emit dust on drift.


func _get_throttle() -> float:
	var t: float = 0.0
	if Input.is_action_pressed(throttle_action):
		t = 1.0
	return maxf(t, touch_throttle)


func _get_steer() -> float:
	var s: float = Input.get_axis(steer_left_action, steer_right_action)
	if absf(touch_steer) > 0.001:
		s = touch_steer
	return clampf(s, -1.0, 1.0)


func _is_brake() -> bool:
	var b: bool = Input.is_action_pressed(brake_action) or touch_brake
	return b
