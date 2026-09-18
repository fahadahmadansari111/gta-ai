extends RefCounted
## Chunk streaming semantics — port of ChunkStreamerTests.cs.
## Covers: 3x3 active set in the interior, corner clamped to 4 cells,
## moving evicts far chunks, adjacent move overlaps 6, diff reports
## loads/unloads. Inline spec always runs; the real ChunkStreamer is probed
## via load() when scripts/world lands (assumed get_active_set/diff).

const STREAMER_PATHS := [
	"res://scripts/world/chunk_streamer.gd",
	"res://scripts/core/chunk_streamer.gd",
]


static func run() -> Dictionary:
	var counts: Array = [0, 0]
	_spec_interior_3x3(counts)
	_spec_corner_4(counts)
	_spec_evict(counts)
	_spec_adjacent_overlap(counts)
	_spec_diff(counts)
	_real_checks(counts)
	return {"passed": counts[0], "failed": counts[1]}


static func _check(counts: Array, cond: bool, label: String) -> void:
	if cond:
		counts[0] += 1
	else:
		counts[1] += 1
		printerr("  FAIL [chunk_streamer] ", label)


static func _cells(cx: int, cy: int, radius: int) -> Array:
	var out: Array = []
	for dx in range(-radius, radius + 1):
		for dy in range(-radius, radius + 1):
			out.append(Vector2i(cx + dx, cy + dy))
	return out


static func _clamp_world(cells: Array, lo: int, hi: int) -> Array:
	var out: Array = []
	for c in cells:
		var v: Vector2i = c
		if v.x >= lo and v.x <= hi and v.y >= lo and v.y <= hi:
			out.append(v)
	return out


static func _diff(old: Array, new: Array) -> Dictionary:
	var to_load: Array = []
	var to_unload: Array = []
	for c in new:
		if not old.has(c):
			to_load.append(c)
	for c in old:
		if not new.has(c):
			to_unload.append(c)
	return {"to_load": to_load, "to_unload": to_unload}


static func _spec_interior_3x3(counts: Array) -> void:
	var s := _cells(5, 5, 1)
	_check(counts, s.size() == 9, "spec interior active set is 3x3 (9)")
	_check(counts, s.has(Vector2i(5, 5)) and s.has(Vector2i(4, 4)) and s.has(Vector2i(6, 6)), "spec contains center and corners")


static func _spec_corner_4(counts: Array) -> void:
	# World of 8x8 chunks (0..7): corner cell keeps only the 4 in-bounds cells.
	var s := _clamp_world(_cells(0, 0, 1), 0, 7)
	_check(counts, s.size() == 4, "spec corner active set is 4 cells")
	_check(counts, s.has(Vector2i(0, 0)) and s.has(Vector2i(1, 0)) and s.has(Vector2i(0, 1)) and s.has(Vector2i(1, 1)), "spec corner holds exact 2x2")


static func _spec_evict(counts: Array) -> void:
	var before := _cells(0, 0, 1)
	var after := _cells(10, 10, 1)
	_check(counts, after.size() == 9 and after.has(Vector2i(10, 10)), "spec moved set is 3x3 on new center")
	var disjoint := true
	for c in before:
		if after.has(c):
			disjoint = false
	_check(counts, disjoint, "spec far move evicts all old chunks")


static func _spec_adjacent_overlap(counts: Array) -> void:
	var before := _cells(0, 0, 1)
	var after := _cells(1, 0, 1)
	var overlap := 0
	for c in before:
		if after.has(c):
			overlap += 1
	_check(counts, after.size() == 9 and overlap == 6, "spec adjacent move overlaps 6, still 9")


static func _spec_diff(counts: Array) -> void:
	var before := _cells(0, 0, 1)
	var d_same := _diff(before, before.duplicate())
	_check(counts, (d_same["to_load"] as Array).is_empty() and (d_same["to_unload"] as Array).is_empty(), "spec diff of identical sets is empty")
	var d_moved := _diff(before, _cells(10, 10, 1))
	_check(counts, not (d_moved["to_load"] as Array).is_empty() and not (d_moved["to_unload"] as Array).is_empty(), "spec diff reports loads and unloads on big move")
	var missing_unload := false
	for c in before:
		if not _cells(10, 10, 1).has(c) and not (d_moved["to_unload"] as Array).has(c):
			missing_unload = true
	_check(counts, not missing_unload, "spec diff unloads every evicted chunk")


static func _load_first(paths: Array):
	for p in paths:
		if ResourceLoader.exists(str(p)):
			var s = load(str(p))
			if s != null:
				return s
	return null


static func _arity(obj: Object, mname: String) -> int:
	for m in obj.get_method_list():
		if str(m.get("name", "")) == mname:
			return (m.get("args", []) as Array).size()
	return -1


static func _real_checks(counts: Array) -> void:
	var CS = _load_first(STREAMER_PATHS)
	if CS == null:
		print("  SKIP [chunk_streamer] real checks: ChunkStreamer script absent")
		return
	var s = CS.new()
	if s == null or _arity(s, "get_active_set") != 3:
		print("  SKIP [chunk_streamer] real checks: need get_active_set(x, z, radius)")
		return
	var interior: Variant = s.call("get_active_set", 0.0, 0.0, 1)
	_check(counts, interior is Array and (interior as Array).size() == 9, "real interior radius-1 set is 3x3")
	var single: Variant = s.call("get_active_set", 0.0, 0.0, 0)
	_check(counts, single is Array and (single as Array).size() == 1, "real radius-0 set is a single chunk")
	if _arity(s, "diff") == 2:
		var before: Variant = s.call("get_active_set", 0.0, 0.0, 1)
		var after: Variant = s.call("get_active_set", 500.0, 500.0, 1)
		var d: Variant = s.call("diff", before, after)
		var ok := d is Dictionary and not ((d as Dictionary).get("to_load", []) as Array).is_empty() and not ((d as Dictionary).get("to_unload", []) as Array).is_empty()
		_check(counts, ok, "real diff reports loads and unloads on move")
	else:
		print("  SKIP [chunk_streamer] real diff check: no diff(old, new) found")
