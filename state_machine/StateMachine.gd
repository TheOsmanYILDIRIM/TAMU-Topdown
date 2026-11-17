class_name StateMachine
extends Node
## Runs one State at a time. Every child node that extends State is a state, and
## its node name is its state name.
##
## The active state gets update() every frame and physics_update() every physics
## frame. A state leaves by emitting transitioned("NextStateName"), so states
## never hold a reference to each other or to the machine. Outside code can
## force a change with change_state("StateName").
##
## TAMU keeps the upstream node-based contract but makes invalid state names
## observable instead of silently ignoring them.

signal state_changed(from_state: String, to_state: String)
signal transition_rejected(from_state: String, requested_state: String, reason: String)

## The state to start in. If empty, the first State child is used.
@export var initial_state: State

var current_state: State
var last_rejection_reason: String = ""


func _ready() -> void:
	for child in get_children():
		if child is State:
			child.actor = get_parent()
			child.transitioned.connect(_on_state_transitioned)

	if initial_state != null and initial_state.get_parent() != self:
		push_error("StateMachine: initial_state must be a direct State child of %s" % get_parent().name)
		return

	current_state = initial_state
	if current_state == null:
		for child in get_children():
			if child is State:
				current_state = child
				break
	if current_state == null:
		push_error("StateMachine: no State children under %s" % get_parent().name)
		return

	if not get_parent().is_node_ready():
		await get_parent().ready
	current_state.enter()
	state_changed.emit("", String(current_state.name))


func _process(delta: float) -> void:
	if current_state:
		current_state.update(delta)


func _physics_process(delta: float) -> void:
	if current_state:
		current_state.physics_update(delta)


func _on_state_transitioned(state_name: String) -> void:
	_request_state(state_name)


## Force a change from outside, by state name. Returns false for a missing state
## or a request to re-enter the already-active state.
func change_state(state_name: String) -> bool:
	return _request_state(state_name)


func _request_state(state_name: String) -> bool:
	var new_state := get_node_or_null(NodePath(state_name)) as State
	if new_state == null:
		_reject_transition(state_name, "missing_state")
		return false
	if new_state == current_state:
		_reject_transition(state_name, "already_current")
		return false
	transition_to(new_state)
	return true


func validate_state_names(required_states: PackedStringArray) -> bool:
	var valid := true
	for state_name in required_states:
		var candidate := get_node_or_null(NodePath(state_name))
		if candidate is not State:
			push_error(
				"StateMachine: required state '%s' is missing under %s"
				% [state_name, get_parent().name]
			)
			valid = false
	return valid


func transition_to(new_state: State) -> void:
	var old_name := ""
	if current_state:
		old_name = String(current_state.name)
		current_state.exit()
	current_state = new_state
	current_state.enter()
	last_rejection_reason = ""
	state_changed.emit(old_name, String(current_state.name))


func _reject_transition(requested_state: String, reason: String) -> void:
	var from_state := ""
	if current_state:
		from_state = String(current_state.name)
	last_rejection_reason = reason
	transition_rejected.emit(from_state, requested_state, reason)
	push_warning(
		"StateMachine: rejected transition %s -> %s (%s)"
		% [from_state, requested_state, reason]
	)
