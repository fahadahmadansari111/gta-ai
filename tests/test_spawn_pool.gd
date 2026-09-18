extends RefCounted
## Spawn pool semantics — port of SpawnPoolTests.cs.
## Covers: capacity clamp, fill-to-cap then -1 without growth, despawn frees
## slots with LIFO reuse, double-free no-op, invalid despawn rejected,
## payload store/clear, traffic budget of 25. Inline spec always runs; the
## real SpawnPool is probed via load() when scripts/world lands
## (assumed class_name SpawnPool with try_spawn/despawn).

const POOL_PATHS := [
	"res://scripts/world/spawn_pool.gd",
	"res://scripts/core/spawn_pool.gd",
]
const MAX_TRAFFIC_ACTORS := 25


static func run() -> Dictionary:
	var counts: Array = [0, 0]
	_spec_capacity_clamp(counts)
	_spec_fill_then_minus_one(counts)
	_spec_despawn_reuse(counts)
	_spec_counts(counts)
	_spec_invalid_despawn(counts)
	_spec_payload(counts)
	_spec_traffic_budget(counts)
	_real_checks(counts)
	return {"passed": counts[0], "failed": counts[1]}


static func _check(counts: Array, cond: bool, label: String) -> void:
	if cond:
		counts[0] += 1
	else:
		counts[1] += 1
		printerr("  FAIL [spawn_pool] ", label)


static func _pool_new(cap: int) -> Dictionary:
	var c := maxi(1, cap)
	var free: Array = []
	for i in range(c - 1, -1, -1):
		free.append(i)
	return {"capacity": c, "active": {}, "free": free, "payload": {}}


static func _active_count(p: Dictionary) -> int:
	return (p["active"] as Dictionary).size()


static func _try_spawn(p: Dictionary, payload: Variant = null) -> int:
	var free: Array = p["free"]
	if free.is_empty():
		return -1
	var idx := int(free.pop_back())
	(p["active"] as Dictionary)[idx] = true
	if payload != null:
		(p["payload"] as Dictionary)[idx] = payload
	return idx


static func _despawn(p: Dictionary, idx: int) -> bool:
	if not (p["active"] as Dictionary).has(idx):
		return false
	(p["active"] as Dictionary).erase(idx)
	(p["payload"] as Dictionary).erase(idx)
	(p["free"] as Array).append(idx)
	return true


static func _spec_capacity_clamp(counts: Array) -> void:
	_check(counts, int(_pool_new(0)["capacity"]) == 1, "spec zero capacity clamps to 1")
	_check(counts, int(_pool_new(-5)["capacity"]) == 1, "spec negative capacity clamps to 1")
	_check(counts, int(_pool_new(25)["capacity"]) == 25, "spec positive capacity kept")


static func _spec_fill_then_minus_one(counts: Array) -> void:
	var p := _pool_new(3)
	_check(counts, _try_spawn(p) == 0 and _try_spawn(p) == 1 and _try_spawn(p) == 2, "spec spawns fill 0..cap-1")
	_check(counts, _active_count(p) == 3, "spec full at cap")
	_check(counts, _try_spawn(p) == -1 and _try_spawn(p) == -1, "spec over-cap returns -1 without growth")
	_check(counts, _active_count(p) == 3 and int(p["capacity"]) == 3, "spec capacity never grows")


static func _spec_despawn_reuse(counts: Array) -> void:
	var p := _pool_new(3)
	var a := _try_spawn(p)
	var b := _try_spawn(p)
	_check(counts, _despawn(p, a), "spec despawn frees slot")
	_check(counts, _try_spawn(p) == a and _active_count(p) == 2, "spec freed slot recycled LIFO")


static func _spec_counts(counts: Array) -> void:
	var p := _pool_new(25)
	_check(counts, _active_count(p) == 0, "spec starts empty")
	var s0 := _try_spawn(p)
	var s1 := _try_spawn(p)
	_check(counts, _active_count(p) == 2, "spec count tracks spawns")
	_check(counts, _despawn(p, s0) and _active_count(p) == 1, "spec count tracks despawn")
	_check(counts, not _despawn(p, s0) and _active_count(p) == 1, "spec double-free is no-op")
	_check(counts, _despawn(p, s1) and _active_count(p) == 0, "spec drains to zero")


static func _spec_invalid_despawn(counts: Array) -> void:
	var p := _pool_new(2)
	_check(counts, not _despawn(p, -1) and not _despawn(p, 2) and not _despawn(p, 99), "spec invalid despawn rejected")
	_check(counts, _active_count(p) == 0, "spec invalid despawn changes nothing")


static func _spec_payload(counts: Array) -> void:
	var p := _pool_new(2)
	var slot := _try_spawn(p, "car_07")
	_check(counts, str((p["payload"] as Dictionary).get(slot, "")) == "car_07", "spec payload stored")
	_check(counts, _despawn(p, slot) and not (p["payload"] as Dictionary).has(slot), "spec payload cleared on despawn")
	_check(counts, _try_spawn(p, "ped_03") == slot and str((p["payload"] as Dictionary).get(slot, "")) == "ped_03", "spec slot reused with new payload")


static func _spec_traffic_budget(counts: Array) -> void:
	var p := _pool_new(MAX_TRAFFIC_ACTORS)
	var ok := true
	for i in MAX_TRAFFIC_ACTORS:
		if _try_spawn(p) < 0:
			ok = false
	_check(counts, ok and _active_count(p) == 25, "spec fills traffic budget of 25")
	_check(counts, _try_spawn(p) == -1 and _active_count(p) == 25, "spec 26th actor rejected")


static func _load_first(paths: Array):
	for p in paths:
		if ResourceLoader.exists(str(p)):
			var s = load(str(p))
			if s != null:
				return s
	return null


static func _real_checks(counts: Array) -> void:
	var Pool = _load_first(POOL_PATHS)
	if Pool == null:
		print("  SKIP [spawn_pool] real checks: SpawnPool script absent")
		return
	var p = Pool.new(3)
	if p == null or not p.has_method("try_spawn") or not p.has_method("despawn"):
		print("  SKIP [spawn_pool] real checks: need try_spawn/despawn")
		return
	var cap: Variant = null
	for prop in p.get_property_list():
		if str(prop.get("name", "")) == "capacity":
			cap = p.get("capacity")
	_check(counts, cap == null or int(cap) == 3, "real capacity is 3")
	var a: Variant = p.call("try_spawn")
	var b: Variant = p.call("try_spawn")
	var c: Variant = p.call("try_spawn")
	_check(counts, int(a) == 0 and int(b) == 1 and int(c) == 2, "real spawns fill 0..cap-1")
	_check(counts, int(p.call("try_spawn")) == -1, "real over-cap returns -1")
	_check(counts, bool(p.call("despawn", int(a))) and int(p.call("try_spawn")) == int(a), "real freed slot recycled")
	_check(counts, not bool(p.call("despawn", 99)), "real invalid despawn rejected")
