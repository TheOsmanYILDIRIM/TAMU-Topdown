class_name SurvivalStats
extends Node
## Survival Core Lite needs-only adaptation.
## Hunger and thirst retain the upstream drain model; health, regen and death are intentionally absent.

signal need_changed(need: StringName, value: float)

@export var max_value: float = 100.0
@export var hunger_per_sec: float = 0.5
@export var thirst_per_sec: float = 0.8
@export var auto_tick: bool = true

var hunger: float = 100.0
var thirst: float = 100.0

func _process(delta: float) -> void:
	if auto_tick:
		tick(delta)

func tick(delta: float) -> void:
	if delta <= 0.0:
		return
	_set_need(&"hunger", hunger - hunger_per_sec * delta)
	_set_need(&"thirst", thirst - thirst_per_sec * delta)

func to_save() -> Dictionary:
	return {"hunger": hunger, "thirst": thirst}

func load_save(d: Dictionary) -> void:
	_set_need(&"hunger", float(d.get("hunger", max_value)))
	_set_need(&"thirst", float(d.get("thirst", max_value)))

func restore(need: StringName, amount: float) -> void:
	match need:
		&"hunger": _set_need(need, hunger + amount)
		&"thirst": _set_need(need, thirst + amount)
		_: push_warning("unknown need %s" % need)

func _set_need(need: StringName, value: float) -> void:
	var clamped := clampf(value, 0.0, max_value)
	match need:
		&"hunger": hunger = clamped
		&"thirst": thirst = clamped
		_: return
	need_changed.emit(need, clamped)
