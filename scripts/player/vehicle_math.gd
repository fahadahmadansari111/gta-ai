class_name VehicleMath
extends RefCounted
## Arcade bicycle-ish vehicle model. Port of the C# VehicleMath.
## Units: speeds in m/s; VehicleTuning.top_speed_kmh converted (/3.6).
## Throttle accel fades near top speed, brake beats coast, yaw rate fades
## with speed, drift factor blends lateral grip.

const COAST_DECEL: float = 3.0
const STEER_HALF_SPEED_KMH: float = 60.0
const GRIP_DECAY_RATE: float = 8.0


## Top speed in m/s derived from tuning.
static func top_speed_ms(tuning: VehicleTuning) -> float:
	return maxf(0.0, tuning.top_speed_kmh / 3.6)


## Integrate longitudinal speed (m/s) for one step.
## throttle clamped 0..1. brake applies tuning.brake;
## no input coasts at COAST_DECEL. Result clamped to [0, top].
static func compute_speed(
	current_speed_ms: float, throttle: float, brake: bool,
	tuning: VehicleTuning, dt: float
) -> float:
	var top_ms: float = top_speed_ms(tuning)
	var speed: float = clampf(current_speed_ms, 0.0, top_ms)
	if dt <= 0.0:
		return speed
	throttle = clampf(throttle, 0.0, 1.0)
	if brake:
		speed -= tuning.brake * dt
	elif throttle > 0.0:
		# Arcade falloff: full accel at standstill, fading near top speed.
		var ratio: float = speed / top_ms if top_ms > 0.0 else 1.0
		var falloff: float = clampf(1.0 - 0.65 * ratio, 0.2, 1.0)
		speed += tuning.accel * throttle * falloff * dt
	else:
		speed -= COAST_DECEL * dt
	return clampf(speed, 0.0, top_ms)


## Yaw rate (rad/s) for a steer input in -1..1. Authority fades with speed:
## rate = steer * tuning.steer / (1 + speed_kmh / 60). Sign follows input.
static func compute_steer_angle(
	speed_kmh: float, steer_input: float, tuning: VehicleTuning
) -> float:
	steer_input = clampf(steer_input, -1.0, 1.0)
	speed_kmh = maxf(0.0, speed_kmh)
	var factor: float = 1.0 / (1.0 + speed_kmh / STEER_HALF_SPEED_KMH)
	return steer_input * tuning.steer * factor


## Apply lateral grip for one step. drift 0 (full grip) decays lateral
## velocity fast; drift 1 (full slide) retains it.
static func apply_drift(
	lateral_velocity: float, tuning: VehicleTuning, dt: float
) -> float:
	if dt <= 0.0:
		return lateral_velocity
	var drift: float = clampf(tuning.drift_factor, 0.0, 1.0)
	var grip: float = 1.0 - drift
	var decay: float = exp(-grip * GRIP_DECAY_RATE * dt)
	return lateral_velocity * decay
