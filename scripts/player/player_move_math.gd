class_name PlayerMoveMath
extends RefCounted
## On-foot locomotion math on the XZ plane (Vector2 = x/z).
## Port of the C# PlayerMoveMath.
## Semi-implicit Euler: velocity approaches desired velocity first,
## then position integrates the new velocity.

const DEFAULT_WALK_SPEED: float = 4.0
const DEFAULT_SPRINT_FACTOR: float = 1.6
const DEFAULT_ACCEL: float = 24.0
const DEFAULT_FRICTION: float = 20.0


## Speed multiplier for sprinting. Factors below 1 are raised to 1
## so sprint never slows the player.
static func sprint_multiplier(sprinting: bool, sprint_factor: float = DEFAULT_SPRINT_FACTOR) -> float:
	if sprinting:
		return maxf(1.0, sprint_factor)
	return 1.0


## Clamp a velocity vector's magnitude to max_speed, preserving direction.
## Zero input stays zero; non-positive max stops.
static func clamp_speed(vel: Vector2, max_speed: float) -> Vector2:
	if max_speed <= 0.0 or vel == Vector2.ZERO:
		return Vector2.ZERO
	var mag: float = vel.length()
	if mag <= max_speed:
		return vel
	return vel * (max_speed / mag)


static func _move_towards(current: Vector2, target: Vector2, max_delta: float) -> Vector2:
	var delta: Vector2 = target - current
	var dist: float = delta.length()
	if dist <= max_delta or dist == 0.0:
		return target
	return current + delta * (max_delta / dist)


## Advance one locomotion step. Input is any-magnitude stick vector;
## lengths > 1 are normalized, partial tilt scales target speed.
## With input, velocity approaches input * speed at accel; without input
## it decays to rest at friction. Speed is clamped to speed, so callers
## pass walk_speed * sprint_multiplier(sprinting) for sprint.
## Non-positive dt is a no-op. Returns {"pos": Vector2, "vel": Vector2}.
static func move_step(
	pos: Vector2, vel: Vector2, input: Vector2,
	speed: float, accel: float, friction: float, dt: float
) -> Dictionary:
	if dt <= 0.0:
		return {"pos": pos, "vel": vel}
	speed = maxf(0.0, speed)
	accel = maxf(0.0, accel)
	friction = maxf(0.0, friction)

	var stick: Vector2 = input
	var input_mag: float = stick.length()
	if input_mag > 1.0:
		stick /= input_mag
		input_mag = 1.0

	var want: Vector2 = stick * speed
	var rate: float = accel if input_mag > 0.0 else friction

	var new_vel: Vector2 = _move_towards(vel, want, rate * dt)
	new_vel = clamp_speed(new_vel, speed)

	return {"pos": pos + new_vel * dt, "vel": new_vel}
