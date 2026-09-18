class_name VehicleTuning
extends Resource
## Arcade vehicle tuning data. Port of the C# VehicleArcadeTuning.
## Plain data + clamping; defaults target a mobile 60fps arcade feel.

const MIN_TOP_SPEED_KMH: float = 60.0
const MAX_TOP_SPEED_KMH: float = 220.0
const MIN_ACCEL: float = 5.0
const MAX_ACCEL: float = 30.0
const MIN_BRAKE: float = 10.0
const MAX_BRAKE: float = 40.0
const MIN_STEER: float = 0.5
const MAX_STEER: float = 3.0
const MIN_DRIFT: float = 0.0
const MAX_DRIFT: float = 1.0

@export_range(60.0, 220.0) var top_speed_kmh: float = 150.0
@export_range(5.0, 30.0) var accel: float = 14.0
@export_range(10.0, 40.0) var brake: float = 22.0
@export_range(0.5, 3.0) var steer: float = 1.6
@export_range(0.0, 1.0) var drift_factor: float = 0.45


func _init(
	p_top_speed_kmh: float = 150.0,
	p_accel: float = 14.0,
	p_brake: float = 22.0,
	p_steer: float = 1.6,
	p_drift_factor: float = 0.45
) -> void:
	top_speed_kmh = p_top_speed_kmh
	accel = p_accel
	brake = p_brake
	steer = p_steer
	drift_factor = p_drift_factor


## Clamp all fields into their arcade-safe ranges (in place).
## Call after deserializing or editing in the inspector.
func validate() -> void:
	if is_nan(top_speed_kmh):
		top_speed_kmh = 150.0
	else:
		top_speed_kmh = clampf(top_speed_kmh, MIN_TOP_SPEED_KMH, MAX_TOP_SPEED_KMH)
	if is_nan(accel):
		accel = 14.0
	else:
		accel = clampf(accel, MIN_ACCEL, MAX_ACCEL)
	if is_nan(brake):
		brake = 22.0
	else:
		brake = clampf(brake, MIN_BRAKE, MAX_BRAKE)
	if is_nan(steer):
		steer = 1.6
	else:
		steer = clampf(steer, MIN_STEER, MAX_STEER)
	if is_nan(drift_factor):
		drift_factor = 0.45
	else:
		drift_factor = clampf(drift_factor, MIN_DRIFT, MAX_DRIFT)


## Copy with validation applied.
func validated_copy() -> VehicleTuning:
	var copy := VehicleTuning.new(top_speed_kmh, accel, brake, steer, drift_factor)
	copy.validate()
	return copy


func _to_string() -> String:
	return "TopSpeedKmh=%s, Accel=%s, Brake=%s, Steer=%s, DriftFactor=%s" % [top_speed_kmh, accel, brake, steer, drift_factor]
