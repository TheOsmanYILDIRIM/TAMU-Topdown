class_name TamuBehaviorState
extends State
## Small adapter that keeps the upstream State nodes generic while the actor
## owns TAMU-specific movement, combat and timing rules.


func enter() -> void:
	_call_actor(&"state_entered", [name])


func exit() -> void:
	_call_actor(&"state_exited", [name])


func physics_update(delta: float) -> void:
	_call_actor(&"state_physics", [name, delta])


func _call_actor(method: StringName, arguments: Array) -> void:
	if actor == null or not actor.has_method(method):
		push_error("TamuBehaviorState: %s cannot handle %s" % [actor, method])
		return
	actor.callv(method, arguments)
