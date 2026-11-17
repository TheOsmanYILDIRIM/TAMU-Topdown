extends CharacterBody2D

const SPEED: float = 150.0
const BOUNDS := Rect2(42.0, 66.0, 556.0, 250.0)

@onready var health: Health = $Health
@onready var hurt_box: BasicHurtBox2D = $HurtBox

var destination: Vector2
var has_destination: bool = false


func _ready() -> void:
	hurt_box.health = health


func walk_to(point: Vector2) -> void:
	destination = point.clamp(BOUNDS.position, BOUNDS.end)
	has_destination = true


func stop_walking() -> void:
	has_destination = false


func _physics_process(delta: float) -> void:
	var direction := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	velocity = direction * SPEED
	if direction != Vector2.ZERO:
		stop_walking()
	elif has_destination:
		var offset := destination - position
		if offset.length() <= SPEED * delta:
			velocity = offset / delta
			stop_walking()
		else:
			velocity = offset.normalized() * SPEED
	move_and_slide()
	position = position.clamp(BOUNDS.position, BOUNDS.end)


func _draw() -> void:
	draw_circle(Vector2.ZERO, 12.0, Color("#dbc597"), true, -1.0, true)
