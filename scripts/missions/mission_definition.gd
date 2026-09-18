class_name MissionDefinition
extends RefCounted

## Static mission definition. Pure data, no engine deps.
## Mirrors C# MissionDefinition + MissionRewards + MissionStartCondition.

var id: String = ""
var title: String = ""
var description: String = ""
var objectives: Array[MissionObjective] = []
var reward_money: int = 0
var required_mission_id: String = ""
## 0.0 (or negative) means no time limit (mirrors C# nullable TimeLimitSec).
var time_limit_sec: float = 0.0


func _init(
	p_id: String = "",
	p_title: String = "",
	p_description: String = "",
	p_objectives: Array[MissionObjective] = [],
	p_reward_money: int = 0,
	p_required_mission_id: String = "",
	p_time_limit_sec: float = 0.0
) -> void:
	id = p_id
	title = p_title
	description = p_description
	objectives = []
	for o: MissionObjective in p_objectives:
		objectives.append(o)
	reward_money = p_reward_money
	required_mission_id = p_required_mission_id
	time_limit_sec = p_time_limit_sec


static func from_dict(d: Dictionary) -> MissionDefinition:
	var def: MissionDefinition = MissionDefinition.new()
	def.id = str(d.get("id", d.get("Id", "")))
	def.title = str(d.get("title", d.get("Title", "")))
	def.description = str(d.get("description", d.get("Description", "")))
	# Rewards: accept flat reward_money / money / Rewards{money}.
	var rewards: Variant = d.get("rewards", d.get("Rewards", null))
	if rewards is Dictionary:
		def.reward_money = int((rewards as Dictionary).get("money", (rewards as Dictionary).get("Money", 0)))
	else:
		def.reward_money = int(d.get("reward_money", d.get("money", d.get("Money", 0))))
	# Start condition: accept flat or nested StartCondition{requiredMissionId}.
	var start_cond: Variant = d.get("startCondition", d.get("StartCondition", null))
	if start_cond is Dictionary:
		var req: Variant = (start_cond as Dictionary).get("requiredMissionId", (start_cond as Dictionary).get("required_mission_id", ""))
		def.required_mission_id = "" if req == null else str(req)
	else:
		var flat_req: Variant = d.get("required_mission_id", d.get("requiredMissionId", ""))
		def.required_mission_id = "" if flat_req == null else str(flat_req)
	def.time_limit_sec = float(d.get("time_limit_sec", d.get("timeLimitSec", d.get("TimeLimitSec", 0.0))))
	if def.time_limit_sec < 0.0:
		def.time_limit_sec = 0.0
	var raw_objs: Array = d.get("objectives", d.get("Objectives", []))
	var parsed: Array[MissionObjective] = []
	for raw: Variant in raw_objs:
		if raw is Dictionary:
			parsed.append(MissionObjective.from_dict(raw))
		elif raw is MissionObjective:
			parsed.append(raw)
	def.objectives = parsed
	return def


static func from_json(json_text: String) -> MissionDefinition:
	var parsed_json: Variant = JSON.parse_string(json_text)
	if parsed_json is Dictionary:
		return MissionDefinition.from_dict(parsed_json)
	push_error("MissionDefinition.from_json: invalid JSON.")
	return MissionDefinition.new()
