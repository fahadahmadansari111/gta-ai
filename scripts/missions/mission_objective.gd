class_name MissionObjective
extends RefCounted

## Single mission objective. Stateless definition; per-run progress lives in
## the context Dictionary owned by MissionRuntime (see MissionRuntime.new_context).
## Context layout:
##   visited: Dictionary (target_id -> true)
##   kills: Dictionary (target_id -> int)
##   collects: Dictionary (item_id -> int)
##   delivered: Dictionary (destination_id -> true)
##   delivered_vehicles: Dictionary (destination_id -> vehicle_id String)
##   survived_seconds: float
##   max_checkpoint: int (-1 = none)

enum Kind { GO_TO, KILL, COLLECT, DELIVER, SURVIVE, RACE_CHECKPOINT }

var kind: Kind = Kind.GO_TO
var target_id: String = ""
var item_id: String = ""
var destination_id: String = ""
## Required vehicle for DELIVER; "" means any vehicle (mirrors C# null).
var vehicle_id: String = ""
var count: int = 1
var radius: float = 3.0
var seconds: float = 0.0
var checkpoint_index: int = -1


func _init(p_kind: Kind = Kind.GO_TO) -> void:
	kind = p_kind


static func new_context() -> Dictionary:
	return {
		"visited": {},
		"kills": {},
		"collects": {},
		"delivered": {},
		"delivered_vehicles": {},
		"survived_seconds": 0.0,
		"max_checkpoint": -1,
	}


static func kind_from_string(s: String) -> Kind:
	match s:
		"GoTo", "GO_TO", "GOTO", "ARRIVED":
			return Kind.GO_TO
		"Kill", "KILL":
			return Kind.KILL
		"Collect", "COLLECT":
			return Kind.COLLECT
		"Deliver", "DELIVER":
			return Kind.DELIVER
		"Survive", "SURVIVE":
			return Kind.SURVIVE
		"RaceCheckpoint", "RACE_CHECKPOINT", "CHECKPOINT":
			return Kind.RACE_CHECKPOINT
	push_error("MissionObjective: unknown kind '%s', defaulting to GO_TO." % s)
	return Kind.GO_TO


static func from_dict(d: Dictionary) -> MissionObjective:
	var type_str: String = str(d.get("type", d.get("objectiveType", d.get("kind", "GoTo"))))
	var obj: MissionObjective = MissionObjective.new(kind_from_string(type_str))
	obj.target_id = str(d.get("targetId", d.get("target_id", "")))
	obj.item_id = str(d.get("itemId", d.get("item_id", "")))
	obj.destination_id = str(d.get("destinationId", d.get("destination_id", "")))
	# Null vehicle (C#) <-> "" (GDScript) both mean "any vehicle".
	var raw_vehicle: Variant = d.get("vehicleId", d.get("vehicle_id", ""))
	obj.vehicle_id = "" if raw_vehicle == null else str(raw_vehicle)
	obj.count = int(d.get("count", 1))
	obj.radius = float(d.get("radius", 3.0))
	obj.seconds = float(d.get("seconds", 0.0))
	obj.checkpoint_index = int(d.get("checkpointIndex", d.get("checkpoint_index", d.get("index", -1))))
	if (obj.kind == Kind.KILL or obj.kind == Kind.COLLECT) and obj.count <= 0:
		push_error("MissionObjective: count must be positive, got %d." % obj.count)
	if obj.kind == Kind.SURVIVE and obj.seconds <= 0.0:
		push_error("MissionObjective: seconds must be positive, got %f." % obj.seconds)
	if obj.kind == Kind.RACE_CHECKPOINT and obj.checkpoint_index < 0:
		push_error("MissionObjective: checkpoint_index must be >= 0.")
	return obj


func objective_type() -> String:
	match kind:
		Kind.GO_TO:
			return "GoTo"
		Kind.KILL:
			return "Kill"
		Kind.COLLECT:
			return "Collect"
		Kind.DELIVER:
			return "Deliver"
		Kind.SURVIVE:
			return "Survive"
		Kind.RACE_CHECKPOINT:
			return "RaceCheckpoint"
	return "GoTo"


func is_completed(ctx: Dictionary) -> bool:
	match kind:
		Kind.GO_TO:
			return (ctx.get("visited", {}) as Dictionary).has(target_id)
		Kind.KILL:
			return int((ctx.get("kills", {}) as Dictionary).get(target_id, 0)) >= count
		Kind.COLLECT:
			return int((ctx.get("collects", {}) as Dictionary).get(item_id, 0)) >= count
		Kind.DELIVER:
			var delivered: Dictionary = ctx.get("delivered", {})
			if not delivered.has(destination_id):
				return false
			if vehicle_id == "":
				return true
			var used: Variant = (ctx.get("delivered_vehicles", {}) as Dictionary).get(destination_id, null)
			# Lenient null match mirrors C#: unrecorded vehicle counts as a match.
			return used == null or str(used) == "" or str(used) == vehicle_id
		Kind.SURVIVE:
			return float(ctx.get("survived_seconds", 0.0)) >= seconds
		Kind.RACE_CHECKPOINT:
			return int(ctx.get("max_checkpoint", -1)) >= checkpoint_index
	return false


func accepts(evt: Dictionary) -> bool:
	var evt_type: String = str(evt.get("type", ""))
	match kind:
		Kind.GO_TO:
			return evt_type == "Arrived" and str(evt.get("target_id", evt.get("targetId", ""))) == target_id
		Kind.KILL:
			return evt_type == "Kill" and str(evt.get("target_id", evt.get("targetId", ""))) == target_id
		Kind.COLLECT:
			return evt_type == "Collect" and str(evt.get("item_id", evt.get("itemId", ""))) == item_id
		Kind.DELIVER:
			if evt_type != "Deliver":
				return false
			if str(evt.get("destination_id", evt.get("destinationId", ""))) != destination_id:
				return false
			# Reject deliveries made with a definitively wrong vehicle.
			var evt_vehicle: Variant = evt.get("vehicle_id", evt.get("vehicleId", null))
			if vehicle_id != "" and evt_vehicle != null and str(evt_vehicle) != "" and str(evt_vehicle) != vehicle_id:
				return false
			return true
		Kind.RACE_CHECKPOINT:
			# Strict equality enforces checkpoint order (mirrors C#).
			return evt_type == "Checkpoint" and int(evt.get("index", evt.get("checkpoint_index", -1))) == checkpoint_index
		Kind.SURVIVE:
			return false
	return false


func apply_progress(ctx: Dictionary, evt: Dictionary) -> void:
	match kind:
		Kind.GO_TO:
			(ctx["visited"] as Dictionary)[str(evt.get("target_id", evt.get("targetId", "")))] = true
		Kind.KILL:
			var kills: Dictionary = ctx["kills"]
			var key: String = str(evt.get("target_id", evt.get("targetId", "")))
			kills[key] = int(kills.get(key, 0)) + 1
		Kind.COLLECT:
			var collects: Dictionary = ctx["collects"]
			var item_key: String = str(evt.get("item_id", evt.get("itemId", "")))
			collects[item_key] = int(collects.get(item_key, 0)) + int(evt.get("amount", 1))
		Kind.DELIVER:
			var dest: String = str(evt.get("destination_id", evt.get("destinationId", "")))
			(ctx["delivered"] as Dictionary)[dest] = true
			var veh: Variant = evt.get("vehicle_id", evt.get("vehicleId", null))
			(ctx["delivered_vehicles"] as Dictionary)[dest] = "" if veh == null else str(veh)
		Kind.RACE_CHECKPOINT:
			var idx: int = int(evt.get("index", evt.get("checkpoint_index", -1)))
			if idx > int(ctx.get("max_checkpoint", -1)):
				ctx["max_checkpoint"] = idx
		Kind.SURVIVE:
			pass
