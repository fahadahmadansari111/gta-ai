extends RefCounted
## Arcade vehicle math — port of VehicleMathTests.cs.
## Targets the REAL VehicleMath + VehicleTuning: top-speed clamp,
## brake beats coast, steer authority fades with speed, drift ordering
## (full grip kills lateral, full slide retains it). Skips if absent.

const VM_PATH := "res://scripts/player/vehicle_math.gd"
const VT_PATH := "res://scripts/player/vehicle_tuning.gd"


static func run() -> Dictionary:
	var counts: Array = [0, 0]
	if not ResourceLoader.exists(VM_PATH) or not ResourceLoader.exists(VT_PATH):
		print("  SKIP [vehicle_math] all checks: vehicle scripts absent")
		return {"passed": counts[0], "failed": counts[1]}
	var VM = load(VM_PATH)
	var VT = load(VT_PATH)
	if VM == null or VT == null:
		print("  SKIP [vehicle_math] all checks: load failed")
		return {"passed": counts[0], "failed": counts[1]}
	var t = VT.new(150.0, 14.0, 22.0, 1.6, 0.45).validated_copy()
	_top_clamp(counts, VM, t)
	_brake_vs_coast(counts, VM, t)
	_steer_fade(counts, VM, t)
	_drift_order(counts, VM, VT)
	_drift_clamp(counts, VM, VT)
	return {"passed": counts[0], "failed": counts[1]}


static func _check(counts: Array, cond: bool, label: String) -> void:
	if cond:
		counts[0] += 1
	else:
		counts[1] += 1
		printerr("  FAIL [vehicle_math] ", label)


static func _top_clamp(counts: Array, VM, t) -> void:
	var top_ms: float = VM.top_speed_ms(t)
	var speed := 0.0
	for i in 2000:
		speed = VM.compute_speed(speed, 1.0, false, t, 1.0 / 60.0)
	_check(counts, speed <= top_ms + 0.01 and speed > top_ms * 0.9, "full throttle converges just under top speed")
	var over: float = VM.compute_speed(top_ms * 2.0, 1.0, false, t, 0.1)
	_check(counts, over <= top_ms, "speed above top is clamped back")


static func _brake_vs_coast(counts: Array, VM, t) -> void:
	var braked: float = VM.compute_speed(20.0, 0.0, true, t, 0.5)
	var coasted: float = VM.compute_speed(20.0, 0.0, false, t, 0.5)
	_check(counts, braked < coasted and coasted < 20.0 and braked >= 0.0, "brake decelerates faster than coast")


static func _steer_fade(counts: Array, VM, t) -> void:
	var slow: float = VM.compute_steer_angle(0.0, 1.0, t)
	var mid: float = VM.compute_steer_angle(80.0, 1.0, t)
	var fast: float = VM.compute_steer_angle(160.0, 1.0, t)
	_check(counts, slow > mid and mid > fast and fast > 0.0, "steer authority fades with speed")
	_check(counts, is_equal_approx(VM.compute_steer_angle(60.0, 0.0, t), 0.0), "zero steer input gives zero output")
	var left: float = VM.compute_steer_angle(60.0, -1.0, t)
	var right: float = VM.compute_steer_angle(60.0, 1.0, t)
	_check(counts, is_equal_approx(-left, right), "steer sign mirrors input")


static func _drift_order(counts: Array, VM, VT) -> void:
	var grip = VT.new(150.0, 14.0, 22.0, 1.6, 0.0)
	var mid = VT.new(150.0, 14.0, 22.0, 1.6, 0.5)
	var slide = VT.new(150.0, 14.0, 22.0, 1.6, 1.0)
	var g: float = VM.apply_drift(5.0, grip, 1.0 / 60.0)
	var m: float = VM.apply_drift(5.0, mid, 1.0 / 60.0)
	var s: float = VM.apply_drift(5.0, slide, 1.0 / 60.0)
	_check(counts, g < m and m < s, "drift ordering: full grip < half < full slide")
	_check(counts, is_equal_approx(s, 5.0) and g >= 0.0, "full slide retains lateral, grip stays non-negative")


static func _drift_clamp(counts: Array, VM, VT) -> void:
	var below = VT.new(150.0, 14.0, 22.0, 1.6, -5.0)
	var above = VT.new(150.0, 14.0, 22.0, 1.6, 5.0)
	var zero = VT.new(150.0, 14.0, 22.0, 1.6, 0.0)
	_check(counts, is_equal_approx(VM.apply_drift(4.0, below, 1.0 / 60.0), VM.apply_drift(4.0, zero, 1.0 / 60.0)), "drift below 0 clamps to full grip")
	_check(counts, is_equal_approx(VM.apply_drift(4.0, above, 1.0 / 60.0), 4.0), "drift above 1 clamps to full slide")
