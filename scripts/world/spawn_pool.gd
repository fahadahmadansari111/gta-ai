class_name SpawnPool
extends RefCounted

## Fixed-size slot pool with preallocated free stack (zero growth after
## construction). Payloads are generic bookkeeping via Array; the scene
## side maps slot indices to pooled nodes. Mirrors C# SpawnPool<T>.

const MAX_TRAFFIC: int = 25

var capacity: int = 25
var active_count: int = 0
var free_count: int = 0

var _payloads: Array = []
var _active: Array = []
var _free_stack: Array = []


func _init(p_capacity: int = MAX_TRAFFIC) -> void:
	capacity = p_capacity if p_capacity > 0 else 1
	_payloads.resize(capacity)
	_active = []
	_active.resize(capacity)
	_active.fill(false)
	_free_stack = []
	# Fill so try_spawn pops lowest indices first (deterministic reuse, mirrors C#).
	for i: int in range(capacity - 1, -1, -1):
		_free_stack.append(i)
	free_count = capacity
	active_count = 0


func is_full() -> bool:
	return active_count >= capacity


## Occupy one free slot (optionally storing a payload).
## Returns the slot index, or -1 when full.
func try_spawn(payload: Variant = null) -> int:
	if free_count <= 0:
		return -1
	free_count -= 1
	var slot: int = int(_free_stack[free_count])
	_active[slot] = true
	_payloads[slot] = payload
	active_count += 1
	return slot


## Free a slot for reuse. Returns false when out of range or already free.
func despawn(index: int) -> bool:
	if index < 0 or index >= capacity or not bool(_active[index]):
		return false
	_active[index] = false
	_payloads[index] = null
	_free_stack[free_count] = index
	free_count += 1
	active_count -= 1
	return true


func is_active(index: int) -> bool:
	return index >= 0 and index < capacity and bool(_active[index])


func get_payload(index: int) -> Variant:
	if index >= 0 and index < capacity:
		return _payloads[index]
	return null


## Free every slot. Payloads are cleared.
func clear() -> void:
	_active.fill(false)
	_payloads.fill(null)
	_free_stack.clear()
	for i: int in range(capacity - 1, -1, -1):
		_free_stack.append(i)
	free_count = capacity
	active_count = 0
