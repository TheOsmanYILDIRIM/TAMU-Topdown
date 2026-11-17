extends Node2D
class_name TamuPassiveAnimal

const REQUIRED_STATES := PackedStringArray(["Idle", "Roam", "Flee"])
const IDLE_SECONDS: float = 0.12
const ROAM_SPEED: float = 18.0
const FLEE_SPEED: float = 72.0
const MIN_POSITION := Vector2(458.0, 228.0)
const MAX_POSITION := Vector2(592.0, 310.0)

@onready var state_machine: StateMachine = $StateMachine

var threat_active: bool = false
var threat_position: Vector2 = Vector2.ZERO
var _state_time: float = 0.0
var _roam_direction: Vector2 = Vector2.RIGHT


func _ready() -> void:
	assert(
		state_machine.validate_state_names(REQUIRED_STATES),
		"Passive animal FSM is missing a required state."
	)
	queue_redraw()


func set_threat(world_position: Vector2) -> void:
	threat_active = true
	threat_position = world_position


func clear_threat() -> void:
	threat_active = false


func current_state_name() -> StringName:
	if state_machine.current_state == null:
		return &""
	return state_machine.current_state.name


func state_entered(state_name: StringName) -> void:
	match state_name:
		&"Idle":
			_state_time = IDLE_SECONDS
		&"Roam":
			_state_time = 0.0
		&"Flee":
			_state_time = 0.0
	queue_redraw()


func state_exited(_state_name: StringName) -> void:
	pass


func state_physics(state_name: StringName, delta: float) -> void:
	match state_name:
		&"Idle":
			if threat_active:
				_change_state(&"Flee")
				return
			_state_time -= delta
			if _state_time <= 0.0:
				_change_state(&"Roam")
		&"Roam":
			if threat_active:
				_change_state(&"Flee")
				return
			_roam(delta)
		&"Flee":
			if not threat_active:
				_change_state(&"Roam")
				return
			_flee(delta)


func _roam(delta: float) -> void:
	if position.x >= MAX_POSITION.x:
		_roam_direction = Vector2.LEFT
	elif position.x <= MIN_POSITION.x:
		_roam_direction = Vector2.RIGHT
	position += _roam_direction * ROAM_SPEED * delta
	position = position.clamp(MIN_POSITION, MAX_POSITION)
	queue_redraw()


func _flee(delta: float) -> void:
	var away := position - threat_position
	if away.length_squared() < 0.001:
		away = Vector2.RIGHT
	position += away.normalized() * FLEE_SPEED * delta
	position = position.clamp(MIN_POSITION, MAX_POSITION)
	queue_redraw()


func _change_state(next_state: StringName) -> void:
	if current_state_name() == next_state:
		return
	assert(
		state_machine.change_state(String(next_state)),
		"Passive animal rejected valid transition to %s" % next_state
	)


func _draw() -> void:
	var color := Color("#9fb36c") if current_state_name() != &"Flee" else Color("#e3c56c")
	draw_circle(Vector2.ZERO, 9.0, color, true, -1.0, true)
