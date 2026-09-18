extends Control
class_name MissionHUD
## Stub mission HUD (Godot port of Unity MissionHUD.cs).
## Pure display, no logic: objective label, timer bar, pass/fail panels.

@export var objective_label_path: NodePath
@export var timer_bar_path: NodePath
@export var success_panel_path: NodePath
@export var fail_panel_path: NodePath

var _objective_label: Label
var _timer_bar: ProgressBar
var _success_panel: Control
var _fail_panel: Control


func _ready() -> void:
	_objective_label = get_node_or_null(objective_label_path) as Label
	_timer_bar = get_node_or_null(timer_bar_path) as ProgressBar
	_success_panel = get_node_or_null(success_panel_path) as Control
	_fail_panel = get_node_or_null(fail_panel_path) as Control
	hide_panels()


## Show current objective, e.g. "GoTo neon_strip_pickup (1/3)".
func show_objective(label: String) -> void:
	if _objective_label != null:
		_objective_label.text = label


## Set timer bar fraction. Pass remaining/total; hides bar when no limit.
func update_timer(remaining_sec: float, total_sec: float) -> void:
	if _timer_bar == null:
		return
	if total_sec <= 0.0:
		_timer_bar.visible = false
		return
	_timer_bar.visible = true
	_timer_bar.value = clampf(remaining_sec / total_sec, 0.0, 1.0)


func show_success(reward_label: String) -> void:
	hide_panels()
	if _success_panel != null:
		_success_panel.visible = true
	show_objective("PASSED — " + reward_label)


func show_fail(reason: String) -> void:
	hide_panels()
	if _fail_panel != null:
		_fail_panel.visible = true
	show_objective("FAILED — " + reason)


func hide_panels() -> void:
	if _success_panel != null:
		_success_panel.visible = false
	if _fail_panel != null:
		_fail_panel.visible = false


# TODO minimap: spawn/refresh a marker for MissionRuntime current objective
# target_id (needs scene minimap controller; keep HUD logic-free until Phase 2).
func refresh_minimap_marker(_target_id: String) -> void:
	pass
