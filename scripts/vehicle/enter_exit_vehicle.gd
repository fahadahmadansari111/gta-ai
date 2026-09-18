extends Node3D
class_name EnterExitVehicle
## Proximity enter/exit glue (Godot port of Unity EnterExitVehicle.cs).
## E key / interact action or touch button toggles between the on-foot
## PlayerController and the ArcadeCar. Emits camera_swap_requested so the
## camera rig can blend (camera work itself lands in Phase 1B).

signal entered_vehicle
signal exited_vehicle
signal camera_swap_requested(is_driving: bool)

@export var player_path: NodePath
@export var vehicle_path: NodePath
@export var vehicle_seat: Node3D
@export var enter_radius: float = 3.0
@export var interact_action: StringName = &"interact"

var is_driving: bool = false

var _player: PlayerController
var _vehicle: ArcadeCar


func _ready() -> void:
	_player = get_node_or_null(player_path) as PlayerController
	_vehicle = get_node_or_null(vehicle_path) as ArcadeCar
	if _vehicle != null:
		_vehicle.set_physics_process(false)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(interact_action):
		try_toggle()


## Touch UI button hook: same toggle as the interact action.
func on_touch_enter_exit_button() -> void:
	try_toggle()


## Touch UI visibility hook: show button only near the vehicle.
func can_enter() -> bool:
	return not is_driving and _is_near_vehicle()


func try_toggle() -> void:
	if is_driving:
		exit_vehicle()
	elif _is_near_vehicle():
		enter_vehicle()


func _is_near_vehicle() -> bool:
	if _player == null or _vehicle == null:
		return false
	return _player.global_position.distance_to(_vehicle.global_position) <= enter_radius


func enter_vehicle() -> void:
	if _player == null or _vehicle == null:
		return
	is_driving = true
	_player.set_physics_process(false)
	_player.set_process_unhandled_input(false)
	_player.visible = false
	_vehicle.set_physics_process(true)
	# TODO Phase 1B: camera switch — blend follow cam to vehicle_seat view.
	entered_vehicle.emit()
	camera_swap_requested.emit(true)


func exit_vehicle() -> void:
	if _player == null or _vehicle == null:
		return
	is_driving = false
	_vehicle.set_physics_process(false)
	var spawn: Vector3 = _vehicle.global_position + _vehicle.global_transform.basis.x * 2.0
	_player.global_position = spawn
	_player.visible = true
	_player.set_physics_process(true)
	_player.set_process_unhandled_input(true)
	# TODO Phase 1B: camera switch — restore on-foot follow cam.
	exited_vehicle.emit()
	camera_swap_requested.emit(false)
