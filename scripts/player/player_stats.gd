class_name PlayerStats
extends RefCounted
## Player health/armor. Port of the C# PlayerStats.
## Health/armor 0..100, armor soaks damage first.
## Death emits wasted exactly once until respawn is called.

signal wasted
signal health_changed(new_health: float)
signal armor_changed(new_armor: float)

const MAX_HEALTH: float = 100.0
const MAX_ARMOR: float = 100.0

var _health: float = MAX_HEALTH
var _armor: float = 0.0
var _is_wasted: bool = false


func _init(health: float = MAX_HEALTH, armor: float = 0.0) -> void:
	_health = clampf(health, 0.0, MAX_HEALTH)
	_armor = clampf(armor, 0.0, MAX_ARMOR)
	_is_wasted = _health <= 0.0


func get_health() -> float:
	return _health


func get_armor() -> float:
	return _armor


func is_wasted() -> bool:
	return _is_wasted


## Alias for is_wasted (C# IsDead parity).
func is_dead() -> bool:
	return _is_wasted


## Add armor, clamped to 0..100. No effect while wasted or for amount <= 0.
func add_armor(amount: float) -> void:
	if _is_wasted or amount <= 0.0:
		return
	var next: float = clampf(_armor + amount, 0.0, MAX_ARMOR)
	if not is_equal_approx(next, _armor):
		_armor = next
		armor_changed.emit(_armor)


## Apply damage. Armor absorbs first, remainder hits health.
## Non-positive amounts are ignored. Emits wasted at zero.
func take_damage(amount: float) -> void:
	if _is_wasted or amount <= 0.0:
		return
	var remaining: float = amount
	if _armor > 0.0:
		var absorbed: float = minf(_armor, remaining)
		_armor -= absorbed
		remaining -= absorbed
		armor_changed.emit(_armor)
	if remaining > 0.0:
		_health = maxf(0.0, _health - remaining)
		health_changed.emit(_health)
	if _health <= 0.0 and not _is_wasted:
		_is_wasted = true
		wasted.emit()


## Heal up to max. Ignored while wasted or for non-positive amounts.
func heal(amount: float) -> void:
	if _is_wasted or amount <= 0.0:
		return
	var next: float = minf(MAX_HEALTH, _health + amount)
	if not is_equal_approx(next, _health):
		_health = next
		health_changed.emit(_health)


## Reset to full health (and optionally armor) after being wasted.
func respawn(armor: float = 0.0) -> void:
	_health = MAX_HEALTH
	_armor = clampf(armor, 0.0, MAX_ARMOR)
	_is_wasted = false
	health_changed.emit(_health)
	armor_changed.emit(_armor)
