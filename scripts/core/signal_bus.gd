class_name SignalBus
extends Node
## Publish/subscribe bus. Port of the C# EventBus.
## Single-threaded (Godot main loop): handlers stored as
## Dictionary[String, Array[Callable]], emit iterates a duplicate snapshot
## so handlers may (un)subscribe without mutating the live list.

var _handlers: Dictionary = {}


func subscribe(event_name: String, handler: Callable) -> void:
	if event_name.is_empty():
		push_error("SignalBus.subscribe: event_name must not be empty.")
		return
	if not handler.is_valid():
		push_error("SignalBus.subscribe: handler is not valid.")
		return
	if not _handlers.has(event_name):
		_handlers[event_name] = [] as Array[Callable]
	var list: Array = _handlers[event_name]
	if not list.has(handler):
		list.append(handler)


func unsubscribe(event_name: String, handler: Callable) -> void:
	if not _handlers.has(event_name):
		return
	var list: Array = _handlers[event_name]
	list.erase(handler)
	if list.is_empty():
		_handlers.erase(event_name)


func emit(event_name: String, arg: Variant = null) -> void:
	if not _handlers.has(event_name):
		return
	var snapshot: Array = (_handlers[event_name] as Array).duplicate()
	for handler: Callable in snapshot:
		if handler.is_valid():
			handler.call(arg)


## Alias kept for autoload/signal-style call sites.
func emit_event(event_name: String, arg: Variant = null) -> void:
	emit(event_name, arg)


func subscriber_count(event_name: String) -> int:
	if not _handlers.has(event_name):
		return 0
	return (_handlers[event_name] as Array).size()


func clear() -> void:
	_handlers.clear()
