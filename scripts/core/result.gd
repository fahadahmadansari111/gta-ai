class_name Result
extends RefCounted
## Lightweight success/failure wrapper. Port of the C# Result<T>.
## GDScript has no generics: success payload is stored as Variant.

var is_ok: bool = false
var value: Variant = null
var error: String = ""


func _init(p_is_ok: bool = false, p_value: Variant = null, p_error: String = "") -> void:
	is_ok = p_is_ok
	value = p_value
	error = p_error


static func ok(p_value: Variant = null) -> Result:
	return Result.new(true, p_value, "")


static func fail(p_error: String) -> Result:
	if p_error.strip_edges().is_empty():
		push_error("Result.fail: error must not be empty.")
		return Result.new(false, null, "<empty error>")
	return Result.new(false, null, p_error)


func is_fail() -> bool:
	return not is_ok


func value_or(fallback: Variant) -> Variant:
	if is_ok:
		return value
	return fallback


func _to_string() -> String:
	if is_ok:
		return "Ok(%s)" % str(value)
	return "Fail(%s)" % error
