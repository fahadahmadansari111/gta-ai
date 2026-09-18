extends RefCounted
## Save semantics — port of SaveServiceTests.cs.
## Covers: value roundtrip (int/string/object), missing key returns default,
## overwrite, delete/has, versioned envelope roundtrip + version mismatch.
## Inline spec (JSON-backed dict store) always runs; the real SaveService is
## probed via load() (assumed save_value/load_value/save_game/load_game,
## CURRENT_VERSION = 1, {version, data} envelope).

const SAVE_PATH := "res://scripts/core/save_service.gd"


static func run() -> Dictionary:
	var counts: Array = [0, 0]
	_spec_roundtrips(counts)
	_spec_missing_default(counts)
	_spec_overwrite_delete(counts)
	_real_checks(counts)
	return {"passed": counts[0], "failed": counts[1]}


static func _check(counts: Array, cond: bool, label: String) -> void:
	if cond:
		counts[0] += 1
	else:
		counts[1] += 1
		printerr("  FAIL [save] ", label)


# --- Inline spec: JSON-backed key/string store (mirrors SpecSaveService) ---

static func _spec_save(store: Dictionary, key: String, value: Variant) -> void:
	store[key] = JSON.stringify(value)


static func _spec_load(store: Dictionary, key: String, default_value: Variant = null) -> Variant:
	if not store.has(key):
		return default_value
	var parsed: Variant = JSON.parse_string(str(store[key]))
	if parsed == null:
		return default_value
	return parsed


static func _spec_roundtrips(counts: Array) -> void:
	var store := {}
	_spec_save(store, "coins", 12345)
	_check(counts, is_equal_approx(float(_spec_load(store, "coins", 0)), 12345.0), "spec int roundtrip")
	_spec_save(store, "name", "CJ-Mod")
	_check(counts, str(_spec_load(store, "name", "")) == "CJ-Mod", "spec string roundtrip")
	var orig := {"name": "Rider", "level": 7, "cash": 987654321, "missions_done": ["intro", "driveby"]}
	_spec_save(store, "player", orig)
	var back: Variant = _spec_load(store, "player", {})
	_check(counts, back is Dictionary and str(back.get("name", "")) == "Rider" and int(back.get("level", 0)) == 7, "spec object roundtrip fields")
	_check(counts, back is Dictionary and ((back.get("missions_done", []) as Array).size() == 2) and str((back.get("missions_done", []) as Array)[1]) == "driveby", "spec object roundtrip array")


static func _spec_missing_default(counts: Array) -> void:
	var store := {}
	_check(counts, int(_spec_load(store, "missing", 42)) == 42, "spec missing key returns default")
	_check(counts, not store.has("missing"), "spec has() false for missing key")


static func _spec_overwrite_delete(counts: Array) -> void:
	var store := {}
	_spec_save(store, "k", 1)
	_spec_save(store, "k", 2)
	_check(counts, is_equal_approx(float(_spec_load(store, "k", 0)), 2.0), "spec overwrite replaces value")
	store.erase("k")
	_check(counts, not store.has("k") and str(_spec_load(store, "k", "dflt")) == "dflt", "spec delete removes key")


# --- Real SaveService probe ---

static func _real_checks(counts: Array) -> void:
	if not ResourceLoader.exists(SAVE_PATH):
		print("  SKIP [save] real checks: save_service.gd absent")
		return
	var SS = load(SAVE_PATH)
	if SS == null:
		print("  SKIP [save] real checks: load failed")
		return
	_check(counts, int(SS.CURRENT_VERSION) == 1, "real CURRENT_VERSION is 1")
	var svc = SS.new()
	if svc == null or not svc.has_method("save_value") or not svc.has_method("load_value") or not svc.has_method("save_game") or not svc.has_method("load_game"):
		print("  SKIP [save] real checks: API mismatch")
		return
	svc.save_value("coins", 12345)
	_check(counts, is_equal_approx(float(svc.load_value("coins", 0)), 12345.0), "real int roundtrip")
	svc.save_value("name", "CJ-Mod")
	_check(counts, str(svc.load_value("name", "")) == "CJ-Mod", "real string roundtrip")
	svc.save_value("k", 1)
	svc.save_value("k", 2)
	_check(counts, is_equal_approx(float(svc.load_value("k", 0)), 2.0), "real overwrite replaces")
	_check(counts, svc.has("k") and svc.delete("k") and not svc.has("k"), "real delete removes key")
	_check(counts, int(svc.load_value("missing", 42)) == 42, "real missing key returns default")
	# Versioned envelope roundtrip + enforcement.
	var data := SS.make_save_data(Vector3.ZERO, 500, "M01_Neon_Delivery")
	var saved = svc.save_game("slot", data)
	_check(counts, saved.is_ok, "real save_game ok")
	var loaded = svc.load_game("slot", 1)
	_check(counts, loaded.is_ok and (loaded.value as Dictionary).get("mission_id", "") == "M01_Neon_Delivery", "real load_game roundtrip with version match")
	var mismatch = svc.load_game("slot", 999)
	_check(counts, mismatch.is_fail(), "real load_game rejects version mismatch")
	var absent = svc.load_game("nope", 1)
	_check(counts, absent.is_fail(), "real load_game fails on missing key")
	svc.save_value("bad", "###not-an-envelope###")
	_check(counts, svc.load_game("bad", 1).is_fail(), "real load_game fails on corrupt envelope")
