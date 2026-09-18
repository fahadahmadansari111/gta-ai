class_name WantedSystem
extends RefCounted

## Pure wanted / heat system. Stars 0-5 derived from Heat 0-100.
## Thresholds: 0 stars <20, 1 star <40, 2 stars <60, 3 stars <80,
## 4 stars <95, 5 stars >=95. Mirrors C# WantedSystem.

signal stars_changed(new_stars: int)
signal cleared

const MAX_HEAT: float = 100.0
const MAX_STARS: int = 5
const STAR_THRESHOLDS: Array = [0.0, 20.0, 40.0, 60.0, 80.0, 95.0]
const HIDE_DECAY_RATE: float = 10.0
const OPEN_DECAY_RATE: float = 3.0

var heat: float = 0.0
var stars: int = 0


## Add a crime. Severity clamped to 1-10; each point adds 10 heat
## (severity 2 => +20 => 1 star).
func add_crime(severity: int) -> void:
	var clamped: int = clampi(severity, 1, 10)
	set_heat(heat + float(clamped) * 10.0)


## Decay heat over time. Hiding decays faster than roaming in the open.
func decay(dt: float, is_hiding: bool) -> void:
	if dt <= 0.0 or heat <= 0.0:
		return
	var rate: float = HIDE_DECAY_RATE if is_hiding else OPEN_DECAY_RATE
	set_heat(heat - rate * dt)


## Busted only when a cop is near AND stars >= 3.
func is_busted(cop_near: bool) -> bool:
	return cop_near and stars >= 3


## Proximity overload: 0 = far, 1 = touching. Busted at >= 0.8 with 3+ stars.
func is_busted_by_proximity(cop_proximity: float) -> bool:
	return cop_proximity >= 0.8 and stars >= 3


## Reset heat and stars to zero.
func clear() -> void:
	set_heat(0.0)


## Map a heat value to a star level using the fixed thresholds.
static func stars_for_heat(heat_value: float) -> int:
	if heat_value < STAR_THRESHOLDS[1]:
		return 0
	if heat_value < STAR_THRESHOLDS[2]:
		return 1
	if heat_value < STAR_THRESHOLDS[3]:
		return 2
	if heat_value < STAR_THRESHOLDS[4]:
		return 3
	if heat_value < STAR_THRESHOLDS[5]:
		return 4
	return 5


func set_heat(value: float) -> void:
	var clamped: float = clampf(value, 0.0, MAX_HEAT)
	var heat_changed: bool = absf(clamped - heat) >= 0.0001
	heat = clamped
	var new_stars: int = WantedSystem.stars_for_heat(heat)
	if new_stars != stars:
		stars = new_stars
		stars_changed.emit(stars)
	if heat_changed and heat <= 0.0:
		cleared.emit()
