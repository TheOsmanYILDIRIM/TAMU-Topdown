extends Node2D
class_name TamuCombatTarget

@onready var health: Health = $Health
@onready var hurt_box: BasicHurtBox2D = $HurtBox

var death_count: int = 0


func _ready() -> void:
	hurt_box.health = health
	health.died.connect(_on_died)
	queue_redraw()


func reset_for_test(max_health: int = 6) -> void:
	health.max = maxi(max_health, 1)
	health.current = health.max
	death_count = 0
	queue_redraw()


func _on_died(_entity: Node) -> void:
	death_count += 1
	queue_redraw()


func _draw() -> void:
	var color := Color("#6b6b72") if health != null and health.is_dead() else Color("#b85d55")
	draw_circle(Vector2.ZERO, 12.0, color, true, -1.0, true)
