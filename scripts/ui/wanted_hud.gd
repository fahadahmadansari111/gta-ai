extends Control
class_name WantedHUD
## Wanted stars HUD + bridge (Godot port of Unity WantedBridge.cs).
## Syncs pure-logic WantedSystem stars to star display; decays each frame.
## TODO Phase 1: bind real star icon TextureRects (assign via star_icon_paths).

signal stars_changed(stars: int)

@export var stars_label_path: NodePath
@export var star_icon_paths: Array[NodePath] = []
@export var max_stars: int = 5

var _wanted: WantedSystem
var _stars_label: Label


func _ready() -> void:
	_wanted = WantedSystem.new()
	_wanted.stars_changed.connect(_on_stars_changed)
	_stars_label = get_node_or_null(stars_label_path) as Label
	_refresh_display(_wanted.stars)


func _process(delta: float) -> void:
	if _wanted == null:
		return
	# TODO Phase 1: pass real is_hiding (from stealth volumes / crouch).
	_wanted.decay(delta, false)


## Demo hook for crimes; wire to gameplay events in Phase 1.
func report_crime(severity: int) -> void:
	if _wanted != null:
		_wanted.add_crime(severity)


func current_stars() -> int:
	if _wanted == null:
		return 0
	return _wanted.stars


func _on_stars_changed(stars: int) -> void:
	_refresh_display(stars)
	stars_changed.emit(stars)


func _refresh_display(stars: int) -> void:
	# TODO Phase 1: refresh star icon TextureRects instead of the text label.
	if _stars_label != null:
		_stars_label.text = "Wanted: %d" % stars
	for i in range(star_icon_paths.size()):
		var icon: Control = get_node_or_null(star_icon_paths[i]) as Control
		if icon != null:
			icon.visible = i < stars
