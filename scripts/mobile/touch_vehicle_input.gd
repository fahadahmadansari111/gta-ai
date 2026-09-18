extends Control
class_name TouchVehicleInput
## Touch joystick -> VehicleMath arcade input stub
## (Godot port of Unity TouchVehicleInput.cs).
## TODO Phase 1: wire on-screen stick + gas/brake TouchScreenButtons to the
## "drive_*" Input actions; until then buttons feed the vars below, which
## ArcadeCar consumes via set_touch_input().

signal throttle_changed(value: float)
signal steer_changed(value: float)
signal brake_changed(pressed: bool)

# Steer -1..1, throttle 0..1, brake 0..1 (mirrors Unity LastInput xyz).
var last_steer: float = 0.0
var last_throttle: float = 0.0
var last_brake: float = 0.0

@export var throttle_action: StringName = &"drive_throttle"
@export var brake_action: StringName = &"drive_brake"


func _ready() -> void:
	# TODO Phase 1: bind on-screen stick node (e.g. $Stick) vector output here.
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	# TODO Phase 1: read touchscreen stick:
	#   steer = stick.get_value().x; throttle/brake from pedal buttons.
	# Scale with VehicleMath: throttle -> compute_speed, stick.x -> compute_steer_angle.
	pass


func get_last_input() -> Vector3:
	return Vector3(last_steer, last_throttle, last_brake)


func set_throttle_button(pressed: bool) -> void:
	# TODO Phase 1B: touch_throttle = 1.0 if pressed else 0.0; forward via
	# ArcadeCar.set_touch_input(throttle, steer, brake) or last_* vars.
	last_throttle = 1.0 if pressed else 0.0
	throttle_changed.emit(last_throttle)


func set_steer_button(direction: float) -> void:
	# TODO Phase 1B: touch_steer = clamp(direction, -1, 1).
	last_steer = clampf(direction, -1.0, 1.0)
	steer_changed.emit(last_steer)


func set_brake_button(pressed: bool) -> void:
	# TODO Phase 1B: touch_brake flag -> VehicleMath.compute_speed brake path.
	last_brake = 1.0 if pressed else 0.0
	brake_changed.emit(pressed)
