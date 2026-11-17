extends Node2D

const ROOM := Rect2(30.0, 54.0, 580.0, 274.0)
const CHEST := Vector2(288.0, 190.0)
const TREE := Vector2(351.0, 207.0)
const INTERACTION_DISTANCE: float = 65.0
const PlayerController = preload("res://scripts/player.gd")

@onready var player: PlayerController = $Player
@onready var status: Label = $HUD/Status

var selected: StringName = &""


func _unhandled_input(event: InputEvent) -> void:
	var point: Vector2
	if event is InputEventScreenTouch and event.pressed:
		point = event.position
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		point = event.position
	else:
		return
	var local_point := get_global_transform_with_canvas().affine_inverse() * point
	if ROOM.has_point(local_point):
		select_at(local_point)
		get_viewport().set_input_as_handled()


func select_at(point: Vector2) -> void:
	if Rect2(CHEST - Vector2(21.0, 15.0), Vector2(42.0, 30.0)).has_point(point):
		selected = &"Chest"
	elif point.distance_to(TREE) <= 23.0:
		selected = &"Tree"
	else:
		selected = &""
		player.walk_to(point)
		queue_redraw()
		return
	player.stop_walking()
	queue_redraw()


func _process(_delta: float) -> void:
	var label := "TAMU • Tap the floor or select an object"
	if selected != &"":
		var target := CHEST if selected == &"Chest" else TREE
		var reachable := player.position.distance_to(target) <= INTERACTION_DISTANCE
		label = "%s • %s" % [selected, "In range" if reachable else "Out of range"]
	if status.text != label:
		status.text = label


func _draw() -> void:
	draw_rect(ROOM, Color("#20372b"))
	draw_rect(ROOM, Color("#416150"), false, 2.0)
	draw_rect(Rect2(CHEST - Vector2(21.0, 15.0), Vector2(42.0, 30.0)), Color("#b27b3e"))
	draw_circle(TREE, 23.0, Color("#558651"), true, -1.0, true)
	if selected != &"":
		var target := CHEST if selected == &"Chest" else TREE
		draw_arc(target, 27.0, 0.0, TAU, 40, Color("#f7d38a"), 2.0, true)
