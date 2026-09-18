extends Node
class_name SaveBridge
## Versioned save bridge (Godot port of Unity SaveBridge.cs).
## Stores envelope { version, data } as JSON at user://savegame.json via
## FileAccess. Saves on mission pass + NOTIFICATION_WM_CLOSE_REQUEST.
## NOTE: Unity PlayerPrefs has no Godot equivalent; user:// file store is
## the replacement. Payloads are plain Dictionaries built with
## SaveService.make_save_data() (no SaveData class in the GDScript port).

signal save_completed(path: String)
signal load_completed(data: Dictionary)
signal save_failed(reason: String)

const SAVE_PATH: String = "user://savegame.json"

var _saves: SaveService


func _ready() -> void:
	_saves = SaveService.new()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game(SaveService.make_save_data(Vector3.ZERO, 0, ""))


## Serialize payload to a JSON string without storing (debug/test helper).
func to_json(data: Dictionary) -> String:
	return JSON.stringify(data)


## Save with version stamp. Fails on IO / serialization errors.
func save_game(data: Dictionary) -> bool:
	if _saves == null:
		save_failed.emit("SaveBridge not initialized.")
		return false
	var result: Result = _saves.save_game("slot", data, SaveService.CURRENT_VERSION)
	if result.is_fail():
		save_failed.emit(result.error)
		return false
	var f: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		save_failed.emit("Cannot open save file for writing.")
		return false
	f.store_string(str(result.value))
	f.close()
	save_completed.emit(SAVE_PATH)
	return true


## Load with version check; fails on missing file, corrupt JSON, or mismatch.
## Returns {} on failure (check has_save() or the save_failed signal).
func load_game() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		save_failed.emit("Load failed (missing file).")
		return {}
	var raw: String = FileAccess.get_file_as_string(SAVE_PATH)
	if raw.is_empty():
		save_failed.emit("Load failed (empty file).")
		return {}
	var parsed: Variant = JSON.parse_string(raw)
	if not (parsed is Dictionary):
		save_failed.emit("Load failed (corrupt JSON).")
		return {}
	var envelope: Dictionary = parsed as Dictionary
	if int(envelope.get("version", -1)) != SaveService.CURRENT_VERSION:
		save_failed.emit("Load failed (version mismatch).")
		return {}
	var payload: Variant = envelope.get("data", null)
	if not (payload is Dictionary):
		save_failed.emit("Load failed (missing data).")
		return {}
	var out: Dictionary = payload as Dictionary
	load_completed.emit(out)
	return out


## Call on mission pass: stamps mission id + money, then saves.
func notify_mission_passed(mission_id: String, money: int) -> bool:
	var data: Dictionary = SaveService.make_save_data(Vector3.ZERO, money, mission_id)
	return save_game(data)


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func delete_save() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	return DirAccess.remove_absolute(SAVE_PATH) == OK
