class_name MissionEvents
extends RefCounted

## Static Dictionary constructors for mission objective events. Pure data.
## Each event carries a `type` field consumed by MissionObjective.
## consumed by MissionObjective.accepts() / apply_progress().


static func arrived(target_id: String) -> Dictionary:
	return {"type": "Arrived", "target_id": target_id}


static func kill(target_id: String) -> Dictionary:
	return {"type": "Kill", "target_id": target_id}


static func collect(item_id: String, amount: int = 1) -> Dictionary:
	return {"type": "Collect", "item_id": item_id, "amount": amount}


static func deliver(dest_id: String, vehicle_id: String = "") -> Dictionary:
	return {"type": "Deliver", "destination_id": dest_id, "vehicle_id": vehicle_id}


static func checkpoint(index: int) -> Dictionary:
	return {"type": "Checkpoint", "index": index}
