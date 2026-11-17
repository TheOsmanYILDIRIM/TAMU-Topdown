extends Node2D
class_name TamuCombatTarget

var required_states: PackedStringArray = PackedStringArray(["Roam", "Chase", "Windup", "Attack", "Recover", "Dead"])
const CHASE_RADIUS: float = 140.0
const LEASH_RADIUS: float = 190.0
const ATTACK_RANGE: float = 54.0
const ROAM_SPEED: float = 12.0
const CHASE_SPEED: float = 64.0
const WINDUP_SECONDS: float = 0.18
const ATTACK_SECONDS: float = 0.08
const RECOVER_SECONDS: float = 0.30
const ATTACK_OFFSET: float = 24.0
const ROAM_MIN_X: float = 170.0
const ROAM_MAX_X: float = 270.0

@onready var health: Health = $Health
@onready var hurt_box: BasicHurtBox2D = $HurtBox
@onready var state_machine: StateMachine = $StateMachine
@onready var attack_hit_box: BasicHitBox2D = $AttackHitBox

var death_count: int = 0
var attack_count: int = 0
var windup_count: int = 0
var recover_count: int = 0
var damage_event_count: int = 0
var attack_direction: Vector2 = Vector2.LEFT
var telegraph_active: bool = false
var recovery_active: bool = false
var behavior_stopped: bool = false
var ai_enabled: bool = true
var target: Node2D
var _state_time: float = 0.0
var _roam_direction: Vector2 = Vector2.RIGHT


func _ready() -> void:
	hurt_box.health = health
	target = get_node_or_null("../Player") as Node2D
	health.died.connect(_on_died)
	attack_hit_box.hurt_box_entered.connect(_on_enemy_attack_hurt_box_entered)
	attack_hit_box.ignore_collisions = true
	attack_hit_box.monitoring = false
	assert(
		state_machine.validate_state_names(required_states),
		"Enemy FSM is missing a required state."
	)
	queue_redraw()


func reset_for_test(max_health: int = 6) -> void:
	health.max = maxi(max_health, 1)
	health.current = health.max
	death_count = 0
	attack_count = 0
	windup_count = 0
	recover_count = 0
	damage_event_count = 0
	telegraph_active = false
	recovery_active = false
	behavior_stopped = false
	ai_enabled = false
	_disable_attack()
	if state_machine.current_state != null and state_machine.current_state.name != &"Roam":
		assert(state_machine.change_state("Roam"), "Failed to reset enemy FSM to Roam.")
	queue_redraw()


func set_ai_enabled(enabled: bool) -> void:
	ai_enabled = enabled
	if not enabled:
		_disable_attack()
		telegraph_active = false
		recovery_active = false
		queue_redraw()
		return
	if health.is_dead():
		behavior_stopped = true
		return
	behavior_stopped = false
	if state_machine.current_state != null and state_machine.current_state.name != &"Roam":
		assert(state_machine.change_state("Roam"), "Failed to enable enemy FSM from Roam.")
	queue_redraw()


func current_state_name() -> StringName:
	if state_machine.current_state == null:
		return &""
	return state_machine.current_state.name


func state_entered(state_name: StringName) -> void:
	match state_name:
		&"Roam":
			telegraph_active = false
			recovery_active = false
			_disable_attack()
		&"Chase":
			telegraph_active = false
			recovery_active = false
			_disable_attack()
		&"Windup":
			_disable_attack()
			telegraph_active = true
			recovery_active = false
			_state_time = WINDUP_SECONDS
			windup_count += 1
			_lock_attack_direction()
		&"Attack":
			telegraph_active = false
			recovery_active = false
			_state_time = ATTACK_SECONDS
			attack_count += 1
			attack_hit_box.position = attack_direction * ATTACK_OFFSET
			attack_hit_box.ignore_collisions = false
			attack_hit_box.set_deferred("monitoring", true)
		&"Recover":
			_disable_attack()
			telegraph_active = false
			recovery_active = true
			_state_time = RECOVER_SECONDS
			recover_count += 1
		&"Dead":
			_disable_attack()
			telegraph_active = false
			recovery_active = false
			behavior_stopped = true
	queue_redraw()


func state_exited(_state_name: StringName) -> void:
	pass


func state_physics(state_name: StringName, delta: float) -> void:
	if not ai_enabled or health.is_dead() or behavior_stopped:
		return
	match state_name:
		&"Roam":
			_roam(delta)
		&"Chase":
			_chase(delta)
		&"Windup":
			_state_time -= delta
			if _state_time <= 0.0:
				_change_state(&"Attack")
		&"Attack":
			_state_time -= delta
			if _state_time <= 0.0:
				_change_state(&"Recover")
		&"Recover":
			_state_time -= delta
			if _state_time <= 0.0:
				_change_state(&"Chase")


func _roam(delta: float) -> void:
	if _target_distance() <= CHASE_RADIUS:
		_change_state(&"Chase")
		return
	if position.x >= ROAM_MAX_X:
		_roam_direction = Vector2.LEFT
	elif position.x <= ROAM_MIN_X:
		_roam_direction = Vector2.RIGHT
	position.x += _roam_direction.x * ROAM_SPEED * delta
	queue_redraw()


func _chase(delta: float) -> void:
	if target == null:
		_change_state(&"Roam")
		return
	var distance := _target_distance()
	if distance > LEASH_RADIUS:
		_change_state(&"Roam")
		return
	if distance <= ATTACK_RANGE:
		_change_state(&"Windup")
		return
	var direction := (target.position - position).normalized()
	position += direction * CHASE_SPEED * delta
	queue_redraw()


func _target_distance() -> float:
	if target == null:
		return INF
	return position.distance_to(target.position)


func _lock_attack_direction() -> void:
	if target == null:
		attack_direction = Vector2.LEFT
		return
	var direction := target.position - position
	attack_direction = direction.normalized() if direction.length_squared() > 0.001 else Vector2.LEFT


func _disable_attack() -> void:
	attack_hit_box.ignore_collisions = true
	attack_hit_box.set_deferred("monitoring", false)


func _change_state(next_state: StringName) -> void:
	if current_state_name() == next_state:
		return
	assert(
		state_machine.change_state(String(next_state)),
		"Enemy rejected valid transition to %s" % next_state
	)


func _on_enemy_attack_hurt_box_entered(_hurt_box: HurtBox2D) -> void:
	if current_state_name() != &"Attack" or attack_hit_box.ignore_collisions:
		return
	damage_event_count += 1
	attack_hit_box.ignore_collisions = true


func _on_died(_entity: Node) -> void:
	death_count += 1
	behavior_stopped = true
	ai_enabled = false
	attack_hit_box.ignore_collisions = true
	if state_machine.current_state != null and state_machine.current_state.name != &"Dead":
		assert(state_machine.change_state("Dead"), "Failed to enter enemy Dead state.")
	queue_redraw()


func _draw() -> void:
	var color := Color("#6b6b72") if health != null and health.is_dead() else Color("#b85d55")
	draw_circle(Vector2.ZERO, 12.0, color, true, -1.0, true)
	if telegraph_active:
		draw_line(
			Vector2.ZERO,
			attack_direction * 34.0,
			Color("#f2c66d"),
			3.0,
			true
		)
