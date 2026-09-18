extends Node
class_name SaveBridge
## Versioned save bridge (Godot port of Unity SaveBridge.cs).
## Stores envelope { version, data } as JSON at user://savegame.json via
## FileAccess. Saves on mission pass + NOTIFICATION_WM_CLOSE_REQUEST.
## NOTE: Unity PlayerPrefs has no Godot equivalent; user:// file store is
## the replacement (same JSON envelope shape, CURRENT_VERSION-checked load).

signal save_completed(path: String)
signal load_completed(data: SaveData)
signal save_failed(reason: String)

const SAVE_PATH: String = "user://savegame.json"

var _saves: SaveService


func _ready() -> void:
	_saves = SaveService.new()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game(SaveData.new())


## Serialize payload to a JSON string without storing (debug/test helper).
func to_json(data: SaveData) -> String:
	return JSON.stringify(data.to_dict())


## Save with version stamp. Fails on IO / serialization errors.
func save_game(data: SaveData) -> bool:
	if _saves == null or data == null:
		save_failed.emit("SaveBridge not initialized.")
		return false
	var result: String = _saves.save_game(SAVE_PATH, data, SaveData.CURRENT_VERSION)
	if result.is_empty():
		save_failed.emit("SaveService.save_game failed.")
		return false
	save_completed.emit(SAVE_PATH)
	return true


## Load with version check; fails on missing file, corrupt JSON, or mismatch.
func load_game() -> SaveData:
	if _saves == null:
		save_failed.emit("SaveBridge not initialized.")
		return null
	var data: SaveData = _saves.load_game(SAVE_PATH, SaveData.CURRENT_VERSION)
	if data == null:
		save_failed.emit("Load failed (missing, corrupt, or version mismatch).")
		return null
	load_completed.emit(data)
	return data


## Call on mission pass: stamps mission id + money, then saves.
func notify_mission_passed(mission_id: String, money: int) -> bool:
	var data := SaveData.new()
	data.mission_id = mission_id
	data.money = money
	return save_game(data)


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func delete_save() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	return DirAccess.remove_absolute(SAVE_PATH) == OK
