extends Node2D

const ROOM := Rect2(30.0, 54.0, 580.0, 274.0)
const CHEST := Vector2(288.0, 190.0)
const TREE := Vector2(351.0, 207.0)
const INTERACTION_DISTANCE: float = 65.0
const PlayerController = preload("res://scripts/player.gd")
const InventoryBridge = preload("res://scripts/inventory_bridge.gd")

@onready var player: PlayerController = $Player
@onready var status: Label = $HUD/Status
@onready var bag_to_chest_button: Button = $HUD/BagToChest
@onready var chest_to_bag_button: Button = $HUD/ChestToBag

var selected: StringName = &""
var inventory: TamuInventoryBridge


func _ready() -> void:
	inventory = InventoryBridge.new(4, 4)
	var seed_excess: ExcessItems = inventory.bag.add(
		InventoryBridge.WOOD_LOG_PLUGIN_ID, 12, null, -1, false
	)
	assert(seed_excess == null, "Initial bag inventory did not fit.")
	bag_to_chest_button.pressed.connect(_on_bag_to_chest_pressed)
	chest_to_bag_button.pressed.connect(_on_chest_to_bag_pressed)
	_update_inventory_controls()


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
		_update_inventory_controls()
		queue_redraw()
		return
	player.stop_walking()
	_update_inventory_controls()
	queue_redraw()


func _chest_reachable() -> bool:
	return selected == &"Chest" and player.position.distance_to(CHEST) <= INTERACTION_DISTANCE


func transfer_to_selected_chest(amount: int = 1) -> int:
	if not _chest_reachable():
		return 0
	var moved := inventory.bag_to_chest(amount)
	_update_inventory_controls()
	return moved


func transfer_from_selected_chest(amount: int = 1) -> int:
	if not _chest_reachable():
		return 0
	var moved := inventory.chest_to_bag(amount)
	_update_inventory_controls()
	return moved


func _on_bag_to_chest_pressed() -> void:
	transfer_to_selected_chest(1)


func _on_chest_to_bag_pressed() -> void:
	transfer_from_selected_chest(1)


func _update_inventory_controls() -> void:
	if inventory == null:
		return
	var reachable := _chest_reachable()
	bag_to_chest_button.disabled = not reachable or inventory.count(inventory.bag) <= 0
	chest_to_bag_button.disabled = not reachable or inventory.count(inventory.chest) <= 0


func _process(_delta: float) -> void:
	var label := "TAMU • Tap the floor or select an object"
	if selected != &"":
		var target := CHEST if selected == &"Chest" else TREE
		var reachable := player.position.distance_to(target) <= INTERACTION_DISTANCE
		label = "%s • %s" % [selected, "In range" if reachable else "Out of range"]
		if selected == &"Chest" and inventory != null:
			label += " • Bag %d • Chest %d" % [
				inventory.count(inventory.bag),
				inventory.count(inventory.chest)
			]
	if status.text != label:
		status.text = label
	_update_inventory_controls()


func _draw() -> void:
	draw_rect(ROOM, Color("#20372b"))
	draw_rect(ROOM, Color("#416150"), false, 2.0)
	draw_rect(Rect2(CHEST - Vector2(21.0, 15.0), Vector2(42.0, 30.0)), Color("#b27b3e"))
	draw_circle(TREE, 23.0, Color("#558651"), true, -1.0, true)
	if selected != &"":
		var target := CHEST if selected == &"Chest" else TREE
		draw_arc(target, 27.0, 0.0, TAU, 40, Color("#f7d38a"), 2.0, true)
