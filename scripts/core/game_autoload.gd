class_name GameAutoload
extends Node
## Global Game singleton stub (register as autoload named "Game").
## Holds shared state: GameState + money + current_mission_id.

var state: GameState
var money: int = 0
var current_mission_id: String = ""


func _init() -> void:
	state = GameState.new()


func _ready() -> void:
	pass


## Attempt a phase transition via the state machine.
func set_phase(next: int) -> bool:
	return state.set_phase(next)


## Enter MISSION phase for the given mission id. Returns false on bad transition.
func start_mission(mission_id: String) -> bool:
	if mission_id.strip_edges().is_empty():
		push_error("GameAutoload.start_mission: mission_id must not be empty.")
		return false
	if not state.set_phase(GameState.Phase.MISSION):
		return false
	current_mission_id = mission_id
	return true


## Leave MISSION phase back to FREE_ROAM and clear the mission id.
func complete_mission() -> bool:
	if not state.set_phase(GameState.Phase.FREE_ROAM):
		return false
	current_mission_id = ""
	return true


func add_money(amount: int) -> void:
	money = maxi(0, money + amount)
