extends RefCounted
## On-foot locomotion math — port of PlayerMoveMathTests.cs.
## Targets the REAL PlayerMoveMath (Vector2 XZ API): accel along input,
## convergence to max speed, friction to rest, sprint multiplier/clamp,
## clamp_speed, diagonal normalization, partial tilt, dt independence,
## non-positive dt no-op, reverse braking. Skips if the script is absent.

const PM_PATH := "res://scripts/player/player_move_math.gd"
const SPEED := 4.0
const ACCEL := 24.0
const FRICTION := 20.0
const DT := 1.0 / 60.0


static func run() -> Dictionary:
	var counts: Array = [0, 0]
	if not ResourceLoader.exists(PM_PATH):
		print("  SKIP [player_move] all checks: player_move_math.gd absent")
		return {"passed": counts[0], "failed": counts[1]}
	var PM = load(PM_PATH)
	if PM == null:
		print("  SKIP [player_move] all checks: load failed")
		return {"passed": counts[0], "failed": counts[1]}
	_accel(counts, PM)
	_converge(counts, PM)
	_friction(counts, PM)
	_sprint_multiplier(counts, PM)
	_sprint_clamp(counts, PM)
	_clamp_speed(counts, PM)
	_diagonal(counts, PM)
	_partial_tilt(counts, PM)
	_dt_independence(counts, PM)
	_nonpositive_dt(counts, PM)
	_reverse(counts, PM)
	return {"passed": counts[0], "failed": counts[1]}


static func _check(counts: Array, cond: bool, label: String) -> void:
	if cond:
		counts[0] += 1
	else:
		counts[1] += 1
		printerr("  FAIL [player_move] ", label)


static func _step(PM, pos: Vector2, vel: Vector2, input: Vector2, speed: float, dt: float) -> Dictionary:
	return PM.move_step(pos, vel, input, speed, ACCEL, FRICTION, dt)


static func _accel(counts: Array, PM) -> void:
	var r := _step(PM, Vector2.ZERO, Vector2.ZERO, Vector2(0, 1), SPEED, DT)
	var vel: Vector2 = r["vel"]
	var pos: Vector2 = r["pos"]
	_check(counts, vel.y > 0.0 and pos.y > 0.0, "accel builds forward velocity and position")
	_check(counts, is_equal_approx(vel.x, 0.0) and is_equal_approx(pos.x, 0.0), "accel has no lateral drift")


static func _converge(counts: Array, PM) -> void:
	var pos := Vector2.ZERO
	var vel := Vector2.ZERO
	for i in 600:
		var r := _step(PM, pos, vel, Vector2(0, 1), SPEED, DT)
		pos = r["pos"]
		vel = r["vel"]
	_check(counts, is_equal_approx(vel.y, SPEED) and is_equal_approx(vel.x, 0.0), "sustained input converges to max speed")


static func _friction(counts: Array, PM) -> void:
	var pos := Vector2.ZERO
	var vel := Vector2(0, SPEED)
	for i in 600:
		var r := _step(PM, pos, vel, Vector2.ZERO, SPEED, DT)
		pos = r["pos"]
		vel = r["vel"]
	_check(counts, vel.length() < 0.01, "friction brings player to rest")
	var end := pos
	var still := _step(PM, pos, vel, Vector2.ZERO, SPEED, DT)
	_check(counts, (still["pos"] as Vector2).is_equal_approx(end), "at rest, position does not drift")


static func _sprint_multiplier(counts: Array, PM) -> void:
	_check(counts, is_equal_approx(PM.sprint_multiplier(false), 1.0), "sprint multiplier is 1 at rest")
	_check(counts, is_equal_approx(PM.sprint_multiplier(true), PM.DEFAULT_SPRINT_FACTOR), "sprint multiplier is default factor when sprinting")
	_check(counts, is_equal_approx(PM.sprint_multiplier(true, 2.0), 2.0), "sprint multiplier honors custom factor")
	_check(counts, is_equal_approx(PM.sprint_multiplier(false, 2.0), 1.0), "custom factor ignored at rest")


static func _sprint_clamp(counts: Array, PM) -> void:
	var sprint_speed: float = SPEED * PM.sprint_multiplier(true)
	var pos := Vector2.ZERO
	var vel := Vector2.ZERO
	var ok := true
	for i in 600:
		var r := _step(PM, pos, vel, Vector2(0, 1), sprint_speed, DT)
		pos = r["pos"]
		vel = r["vel"]
		if (vel as Vector2).length() > sprint_speed + 0.01:
			ok = false
	_check(counts, ok, "velocity never exceeds sprint speed")
	_check(counts, is_equal_approx((vel as Vector2).length(), sprint_speed), "sustained sprint reaches sprint speed")


static func _clamp_speed(counts: Array, PM) -> void:
	var c: Vector2 = PM.clamp_speed(Vector2(3, 4), 2.5)
	_check(counts, is_equal_approx(c.length(), 2.5) and c.x > 0.0 and c.y > 0.0, "clamp preserves direction at limit")
	var u: Vector2 = PM.clamp_speed(Vector2(1, 0), 5.0)
	_check(counts, u.is_equal_approx(Vector2(1, 0)), "under-limit velocity passes through")
	var z: Vector2 = PM.clamp_speed(Vector2(3, 4), 0.0)
	_check(counts, z.is_equal_approx(Vector2.ZERO), "non-positive max stops")


static func _diagonal(counts: Array, PM) -> void:
	var pos := Vector2.ZERO
	var vel := Vector2.ZERO
	for i in 600:
		var r := _step(PM, pos, vel, Vector2(1, 1), SPEED, DT)
		pos = r["pos"]
		vel = r["vel"]
	_check(counts, is_equal_approx((vel as Vector2).length(), SPEED), "diagonal input capped at max speed")
	_check(counts, is_equal_approx(vel.x, vel.y), "diagonal input stays symmetric")


static func _partial_tilt(counts: Array, PM) -> void:
	var pos := Vector2.ZERO
	var vel := Vector2.ZERO
	for i in 600:
		var r := _step(PM, pos, vel, Vector2(0, 0.5), SPEED, DT)
		pos = r["pos"]
		vel = r["vel"]
	_check(counts, is_equal_approx(vel.y, SPEED * 0.5), "half-tilt stick converges to half speed")


static func _dt_independence(counts: Array, PM) -> void:
	var a_pos := Vector2.ZERO
	var a_vel := Vector2.ZERO
	for i in 60:
		var r := _step(PM, a_pos, a_vel, Vector2(0, 1), SPEED, 1.0 / 60.0)
		a_pos = r["pos"]
		a_vel = r["vel"]
	var b_pos := Vector2.ZERO
	var b_vel := Vector2.ZERO
	for i in 120:
		var r := _step(PM, b_pos, b_vel, Vector2(0, 1), SPEED, 1.0 / 120.0)
		b_pos = r["pos"]
		b_vel = r["vel"]
	_check(counts, absf(a_vel.y - b_vel.y) < 0.05 and absf(a_pos.y - b_pos.y) < 0.05, "result ~independent of step size")


static func _nonpositive_dt(counts: Array, PM) -> void:
	var r := _step(PM, Vector2(1, 2), Vector2(3, 4), Vector2(0, 1), SPEED, 0.0)
	_check(counts, (r["pos"] as Vector2).is_equal_approx(Vector2(1, 2)) and (r["vel"] as Vector2).is_equal_approx(Vector2(3, 4)), "zero dt is no-op")
	var n := _step(PM, Vector2(1, 2), Vector2(3, 4), Vector2(0, 1), SPEED, -0.016)
	_check(counts, (n["pos"] as Vector2).is_equal_approx(Vector2(1, 2)), "negative dt is no-op")


static func _reverse(counts: Array, PM) -> void:
	var first := _step(PM, Vector2.ZERO, Vector2(0, SPEED), Vector2(0, -1), SPEED, DT)
	_check(counts, (first["vel"] as Vector2).y < SPEED, "reverse input brakes forward velocity")
	var pos := Vector2.ZERO
	var vel := Vector2(0, SPEED)
	for i in 600:
		var r := _step(PM, pos, vel, Vector2(0, -1), SPEED, DT)
		pos = r["pos"]
		vel = r["vel"]
	_check(counts, is_equal_approx(vel.y, -SPEED), "sustained reverse reaches full reverse speed")
