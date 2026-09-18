class_name EconomyService
extends RefCounted

## Pure money service. Balance never goes negative. Mirrors C# EconomyService.

signal balance_changed(new_balance: int)

var balance: int = 0
var transaction_log: Array = []


func _init(starting_balance: int = 0) -> void:
	if starting_balance < 0:
		push_error("EconomyService: starting balance cannot be negative.")
		starting_balance = 0
	balance = starting_balance
	if starting_balance > 0:
		transaction_log.append(_entry("Initial", starting_balance))


func _entry(kind: String, amount: int) -> Dictionary:
	return {
		"kind": kind,
		"amount": amount,
		"balance_after": balance,
		"timestamp": Time.get_datetime_string_from_system(true, true),
	}


## Add money. Amount must be > 0.
func add_money(amount: int) -> void:
	if amount <= 0:
		push_error("EconomyService.add_money: amount must be positive.")
		return
	balance += amount
	transaction_log.append(_entry("Credit", amount))
	balance_changed.emit(balance)


## Spend money. Returns false (no state change) on invalid amount or
## insufficient funds. Balance never goes negative.
func spend_money(amount: int) -> bool:
	if amount <= 0 or amount > balance:
		return false
	balance -= amount
	transaction_log.append(_entry("Debit", -amount))
	balance_changed.emit(balance)
	return true


## Apply a mission payout. Amount must be > 0.
func apply_mission_reward(money: int) -> void:
	if money <= 0:
		push_error("EconomyService.apply_mission_reward: reward must be positive.")
		return
	balance += money
	transaction_log.append(_entry("MissionReward", money))
	balance_changed.emit(balance)


## Test/utility helper: clears the log without touching the balance.
func clear_log() -> void:
	transaction_log.clear()
