class_name SaveService
extends RefCounted
## Versioned JSON save/load service. Port of the C# SaveService.
## Payloads are wrapped in a {version, data} envelope via JSON.stringify/parse.
## SaveService.save_game / load_game never throw: they return Result.

const CURRENT_VERSION: int = 1


class InMemoryStore:
	extends RefCounted
	## In-memory key/string backend. Port of the C# InMemorySaveStore.

	var _entries: Dictionary = {}

	func save(key: String, json: String) -> void:
		_entries[key] = json

	func load(key: String) -> String:
		return str(_entries.get(key, ""))

	func has(key: String) -> bool:
		return _entries.has(key)

	func delete(key: String) -> bool:
		return _entries.erase(key)

	func clear() -> void:
		_entries.clear()


var _store: InMemoryStore


func _init(store: InMemoryStore = null) -> void:
	if store == null:
		_store = InMemoryStore.new()
	else:
		_store = store


## Simple key/value API: serialize value as JSON and store it (overwrite).
func save_value(key: String, value: Variant) -> void:
	_store.save(key, JSON.stringify(value))


## Load and deserialize key, or return default_value when missing/null/corrupt.
func load_value(key: String, default_value: Variant = null) -> Variant:
	var raw: String = _store.load(key)
	if raw.is_empty():
		return default_value
	var parsed: Variant = JSON.parse_string(raw)
	if parsed == null:
		return default_value
	return parsed


func has(key: String) -> bool:
	return _store.has(key)


func delete(key: String) -> bool:
	return _store.delete(key)


func clear() -> void:
	_store.clear()


## Save data inside a versioned {version, data} envelope.
## Returns Ok(json_string) on success, Fail(error) otherwise.
func save_game(key: String, data: Variant, version: int = CURRENT_VERSION) -> Result:
	if key.strip_edges().is_empty():
		return Result.fail("Key must not be empty.")
	if data == null:
		return Result.fail("Data must not be null.")
	var envelope: Dictionary = {"version": version, "data": data}
	var json: String = JSON.stringify(envelope)
	if json.is_empty():
		return Result.fail("Save failed for key '%s': stringify returned empty." % key)
	_store.save(key, json)
	return Result.ok(json)


## Load a versioned envelope. Pass expected_version >= 0 to enforce it.
## Missing keys, corrupt JSON, empty payloads and version mismatches yield Fail.
func load_game(key: String, expected_version: int = -1) -> Result:
	if key.strip_edges().is_empty():
		return Result.fail("Key must not be empty.")
	var raw: String = _store.load(key)
	if raw.is_empty():
		return Result.fail("No save found for key '%s'." % key)
	var parsed: Variant = JSON.parse_string(raw)
	if not (parsed is Dictionary):
		return Result.fail("Corrupt save for key '%s': empty envelope." % key)
	var envelope: Dictionary = parsed as Dictionary
	if not envelope.has("version") or not envelope.has("data"):
		return Result.fail("Corrupt save for key '%s': empty envelope." % key)
	var version: int = int(envelope["version"])
	if expected_version >= 0 and version != expected_version:
		return Result.fail("Version mismatch for key '%s': expected %d, got %d." % [key, expected_version, version])
	var data: Variant = envelope["data"]
	if data == null:
		return Result.fail("Corrupt save for key '%s': missing data." % key)
	return Result.ok(data)


## Build a v1 game-save payload dict: {player_pos:[x,y,z], money, mission_id, timestamp}.
static func make_save_data(player_pos: Vector3, money: int, mission_id: String) -> Dictionary:
	return {
		"player_pos": [player_pos.x, player_pos.y, player_pos.z],
		"money": money,
		"mission_id": mission_id,
		"timestamp": int(Time.get_unix_time_from_system()),
	}
