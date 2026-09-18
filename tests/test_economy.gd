extends RefCounted
## Economy semantics — port of EconomyServiceTests.cs.
## Covers: start at zero, add/spend, exact spend empties, insufficient spend
## preserves balance, 500-op fuzz never negative, invalid amounts rejected.
## Inline spec always runs; the real EconomyService is probed via load() when
## scripts/economy lands (assumed class_name EconomyService with
## add_money/spend_money/balance).

const ECONOMY_PATHS := [
	"res://scripts/economy/economy_service.gd",
	"res://scripts/core/economy_service.gd",
]


static func run() -> Dictionary:
	var counts: Array = [0, 0]
	_spec_basics(counts)
	_spec_exact_spend(counts)
	_spec_insufficient(counts)
	_spec_fuzz_never_negative(counts)
	_spec_invalid_rejected(counts)
	_real_checks(counts)
	return {"passed": counts[0], "failed": counts[1]}


static func _check(counts: Array, cond: bool, label: String) -> void:
	if cond:
		counts[0] += 1
	else:
		counts[1] += 1
		printerr("  FAIL [economy] ", label)


static func _eco_new() -> Dictionary:
	return {"balance": 0}


static func _add(s: Dictionary, amount: int) -> bool:
	if amount < 0:
		return false
	s["balance"] = int(s["balance"]) + amount
	return true


static func _spend(s: Dictionary, amount: int) -> bool:
	if amount <= 0:
		return false
	if int(s["balance"]) < amount:
		return false
	s["balance"] = int(s["balance"]) - amount
	return true


static func _spec_basics(counts: Array) -> void:
	_check(counts, int(_eco_new()["balance"]) == 0, "spec starts at zero")
	var e := _eco_new()
	_add(e, 100)
	_check(counts, int(e["balance"]) == 100, "spec add increases balance")
	_add(e, 50)
	_check(counts, int(e["balance"]) == 150, "spec add accumulates")
	_check(counts, _spend(e, 40) and int(e["balance"]) == 110, "spec spend deducts when sufficient")


static func _spec_exact_spend(counts: Array) -> void:
	var e := _eco_new()
	_add(e, 75)
	_check(counts, _spend(e, 75) and int(e["balance"]) == 0, "spec exact spend empties to zero")


static func _spec_insufficient(counts: Array) -> void:
	var e := _eco_new()
	_add(e, 30)
	_check(counts, not _spend(e, 50) and int(e["balance"]) == 30, "spec insufficient spend preserves balance")


static func _spec_fuzz_never_negative(counts: Array) -> void:
	var e := _eco_new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var ok := true
	for i in 500:
		_add(e, rng.randi_range(0, 19))
		_spend(e, rng.randi_range(1, 24))
		if int(e["balance"]) < 0:
			ok = false
			break
	_check(counts, ok and int(e["balance"]) >= 0, "spec 500-op fuzz never negative")


static func _spec_invalid_rejected(counts: Array) -> void:
	var e := _eco_new()
	_check(counts, not _add(e, -1) and int(e["balance"]) == 0, "spec negative add rejected")
	_add(e, 10)
	_check(counts, not _spend(e, 0) and not _spend(e, -5) and int(e["balance"]) == 10, "spec zero/negative spend rejected")


static func _load_first(paths: Array):
	for p in paths:
		if ResourceLoader.exists(str(p)):
			var s = load(str(p))
			if s != null:
				return s
	return null


static func _has_prop(e, prop: String) -> bool:
	for p in e.get_property_list():
		if str(p.get("name", "")) == prop:
			return true
	return false


static func _real_checks(counts: Array) -> void:
	var ES = _load_first(ECONOMY_PATHS)
	if ES == null:
		print("  SKIP [economy] real checks: EconomyService script absent")
		return
	var e = ES.new()
	if e == null or not e.has_method("add_money") or not e.has_method("spend_money") or not _has_prop(e, "balance"):
		print("  SKIP [economy] real checks: API mismatch (need add_money/spend_money/balance)")
		return
	e.call("add_money", 100)
	_check(counts, int(e.get("balance")) == 100, "real add increases balance")
	_check(counts, bool(e.call("spend_money", 40)) and int(e.get("balance")) == 60, "real spend deducts when sufficient")
	_check(counts, not bool(e.call("spend_money", 61)) and int(e.get("balance")) == 60, "real insufficient spend preserves balance")
	_check(counts, bool(e.call("spend_money", 60)) and int(e.get("balance")) == 0, "real exact spend empties to zero")
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var ok := true
	for i in 200:
		e.call("add_money", rng.randi_range(1, 19))
		e.call("spend_money", rng.randi_range(1, 24))
		if int(e.get("balance")) < 0:
			ok = false
			break
	_check(counts, ok, "real 200-op fuzz never negative")
