class_name ChunkStreamer
extends RefCounted

## Pure-math chunk streamer for a square city (default 2km x 2km) centered
## on origin: x,z in [-world_size/2, +world_size/2]. Chunk ids are
## Vector2i (column, row) with (0,0) at the south-west corner.
## Mirrors C# ChunkStreamer.

var world_size: float = 2000.0
var chunk_size: float = 250.0
var chunks_per_axis: int = 8


func _init(world_size_meters: float = 2000.0, chunk_size_meters: float = 250.0) -> void:
	if world_size_meters <= 0.0:
		push_error("ChunkStreamer: world size must be positive.")
		world_size_meters = 2000.0
	if chunk_size_meters <= 0.0:
		push_error("ChunkStreamer: chunk size must be positive.")
		chunk_size_meters = 250.0
	world_size = world_size_meters
	chunk_size = chunk_size_meters
	chunks_per_axis = maxi(1, int(ceil(world_size_meters / chunk_size_meters)))


func total_chunks() -> int:
	return chunks_per_axis * chunks_per_axis


## Which chunk contains world position (x, z). Out-of-bounds clamps to edge.
func get_chunk_id(x: float, z: float) -> Vector2i:
	var half: float = world_size / 2.0
	var cx: int = clampi(int(floor((x + half) / chunk_size)), 0, chunks_per_axis - 1)
	var cz: int = clampi(int(floor((z + half) / chunk_size)), 0, chunks_per_axis - 1)
	return Vector2i(cx, cz)


## Square set of chunks around the player, clamped to world bounds.
## radius: Chebyshev radius in chunks (>= 0). 0 = current chunk, 1 = 3x3.
## Returns a Dictionary set: keys are Vector2i, values are true.
func get_active_set(player_x: float, player_z: float, load_radius_chunks: int) -> Dictionary:
	var radius: int = maxi(0, load_radius_chunks)
	var center: Vector2i = get_chunk_id(player_x, player_z)
	var result: Dictionary = {}
	for dx: int in range(-radius, radius + 1):
		for dz: int in range(-radius, radius + 1):
			var cx: int = center.x + dx
			var cz: int = center.y + dz
			if cx >= 0 and cx < chunks_per_axis and cz >= 0 and cz < chunks_per_axis:
				result[Vector2i(cx, cz)] = true
	return result


## Diff an old active set against a new one.
## Returns {"to_load": <in new, not old>, "to_unload": <in old, not new>}.
static func diff(old_set: Dictionary, new_set: Dictionary) -> Dictionary:
	var to_load: Dictionary = {}
	for key: Variant in new_set.keys():
		if not old_set.has(key):
			to_load[key] = true
	var to_unload: Dictionary = {}
	for key: Variant in old_set.keys():
		if not new_set.has(key):
			to_unload[key] = true
	return {"to_load": to_load, "to_unload": to_unload}
