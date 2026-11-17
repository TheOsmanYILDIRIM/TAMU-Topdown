extends Node2D

const ROOM := Rect2(30.0, 54.0, 580.0, 274.0)
const CHEST := Vector2(288.0, 190.0)
const TREE := Vector2(351.0, 207.0)
const PICKUP := Vector2(440.0, 190.0)
const PICKUP_TWO := Vector2(500.0, 190.0)
const INTERACTION_DISTANCE: float = 65.0
const ATTACK_WINDOW_SECONDS: float = 0.25
const PlayerController = preload("res://scripts/player.gd")
const InventoryBridge = preload("res://scripts/inventory_bridge.gd")
const QuestBridge = preload("res://scripts/quest_bridge.gd")
const SaveAdapter = preload("res://scripts/save_adapter.gd")

@onready var player: PlayerController = $Player
@onready var status: Label = $HUD/Status
@onready var bag_to_chest_button: Button = $HUD/BagToChest
@onready var chest_to_bag_button: Button = $HUD/ChestToBag
@onready var take_button: Button = $HUD/TakePickup
@onready var reward_button: Button = $HUD/ClaimReward
@onready var save_button: Button = $HUD/Save
@onready var load_button: Button = $HUD/Load
@onready var combat_target: TamuCombatTarget = $CombatTarget
@onready var attack_hit_box: BasicHitBox2D = $Player/AttackHitBox
@onready var attack_window: Timer = $AttackWindow

var selected: StringName = &""
var inventory: TamuInventoryBridge
var quest: TamuQuestBridge
var pickup_taken: bool = false
var pickup_two_taken: bool = false
var attack_active: bool = false


func _ready() -> void:
	inventory = InventoryBridge.new(4, 4)
	quest = QuestBridge.new()
	var seed_excess: ExcessItems = inventory.bag.add(
		InventoryBridge.WOOD_LOG_PLUGIN_ID, 12, null, -1, false
	)
	assert(seed_excess == null, "Initial bag inventory did not fit.")
	bag_to_chest_button.pressed.connect(_on_bag_to_chest_pressed)
	chest_to_bag_button.pressed.connect(_on_chest_to_bag_pressed)
	take_button.pressed.connect(_on_take_pickup_pressed)
	reward_button.pressed.connect(_on_claim_reward_pressed)
	save_button.pressed.connect(_on_save_pressed)
	load_button.pressed.connect(_on_load_pressed)
	attack_hit_box.hurt_box_entered.connect(_on_attack_hurt_box_entered)
	attack_window.timeout.connect(_on_attack_window_timeout)
	attack_window.wait_time = ATTACK_WINDOW_SECONDS
	attack_hit_box.monitoring = false
	attack_hit_box.ignore_collisions = true
	_update_inventory_controls()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		perform_attack()
		get_viewport().set_input_as_handled()
		return

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
	elif not pickup_taken and point.distance_to(PICKUP) <= 16.0:
		selected = &"Pickup"
	elif not pickup_two_taken and point.distance_to(PICKUP_TWO) <= 16.0:
		selected = &"Pickup2"
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


func perform_attack() -> bool:
	if attack_active:
		return false
	attack_active = true
	attack_hit_box.ignore_collisions = false
	attack_hit_box.monitoring = true
	attack_window.start()
	return true


func _on_attack_hurt_box_entered(_hurt_box: HurtBox2D) -> void:
	if attack_active:
		attack_hit_box.ignore_collisions = true


func _on_attack_window_timeout() -> void:
	attack_hit_box.monitoring = false
	attack_hit_box.ignore_collisions = true
	attack_active = false


func _target_for_selected() -> Vector2:
	if selected == &"Chest":
		return CHEST
	if selected == &"Tree":
		return TREE
	if selected == &"Pickup":
		return PICKUP
	if selected == &"Pickup2":
		return PICKUP_TWO
	return player.position


func _chest_reachable() -> bool:
	return selected == &"Chest" and player.position.distance_to(CHEST) <= INTERACTION_DISTANCE


func _pickup_reachable() -> bool:
	if selected == &"Pickup":
		return not pickup_taken and player.position.distance_to(PICKUP) <= INTERACTION_DISTANCE
	if selected == &"Pickup2":
		return not pickup_two_taken and player.position.distance_to(PICKUP_TWO) <= INTERACTION_DISTANCE
	return false


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


func take_selected_pickup() -> bool:
	if not _pickup_reachable():
		return false
	var selected_pickup := selected
	var added := inventory.add_to_bag(1)
	if added != 1:
		return false
	quest.record_collection(InventoryBridge.WOOD_LOG_STABLE_ID, added)
	if selected_pickup == &"Pickup":
		pickup_taken = true
	else:
		pickup_two_taken = true
	selected = &""
	_update_inventory_controls()
	queue_redraw()
	return true


func claim_quest_reward() -> int:
	var rewarded := quest.claim_reward(inventory)
	_update_inventory_controls()
	return rewarded


func save_game(slot_id: int = 1) -> Error:
	var state := SaveAdapter.capture(
		player.position, inventory, pickup_taken, pickup_two_taken, quest
	)
	return SaveManager.save_slot(slot_id, state, "Prototype room")


func load_game(slot_id: int = 1) -> Dictionary:
	var result: Dictionary = SaveManager.load_slot(slot_id)
	if not bool(result.get("ok", false)):
		return result
	var state_value: Variant = result.get("state", null)
	if typeof(state_value) != TYPE_DICTIONARY:
		return {"ok": false, "err": ERR_INVALID_DATA, "state": {}, "recovered": bool(result.get("recovered", false))}
	var decoded := SaveAdapter.decode(
		state_value as Dictionary, inventory, quest, PlayerController.BOUNDS
	)
	if not bool(decoded.get("ok", false)):
		return {"ok": false, "err": decoded.get("err", ERR_INVALID_DATA), "state": {}, "recovered": bool(result.get("recovered", false))}

	var previous_inventories := inventory.snapshot_all()
	var restore_err := inventory.restore_all(decoded.get("inventories", {}))
	if restore_err != OK:
		return {"ok": false, "err": restore_err, "state": {}, "recovered": bool(result.get("recovered", false))}
	var quest_err := quest.restore_all(decoded.get("quests", {}))
	if quest_err != OK:
		var rollback_err := inventory.restore_all(previous_inventories)
		assert(rollback_err == OK, "Inventory rollback after quest restore failure failed.")
		return {"ok": false, "err": quest_err, "state": {}, "recovered": bool(result.get("recovered", false))}

	player.position = decoded.get("player_position", player.position)
	player.stop_walking()
	pickup_taken = bool(decoded.get("pickup_taken", pickup_taken))
	pickup_two_taken = bool(decoded.get("pickup_two_taken", pickup_two_taken))
	selected = &""
	_update_inventory_controls()
	queue_redraw()
	return result


func _on_bag_to_chest_pressed() -> void:
	transfer_to_selected_chest(1)


func _on_chest_to_bag_pressed() -> void:
	transfer_from_selected_chest(1)


func _on_take_pickup_pressed() -> void:
	take_selected_pickup()


func _on_claim_reward_pressed() -> void:
	claim_quest_reward()


func _on_save_pressed() -> void:
	save_game(1)


func _on_load_pressed() -> void:
	load_game(1)


func _update_inventory_controls() -> void:
	if inventory == null or quest == null:
		return
	var reachable := _chest_reachable()
	bag_to_chest_button.disabled = not reachable or inventory.count(inventory.bag) <= 0
	chest_to_bag_button.disabled = not reachable or inventory.count(inventory.chest) <= 0
	take_button.disabled = not _pickup_reachable()
	reward_button.disabled = not quest.is_completed() or quest.is_reward_claimed()


func _process(_delta: float) -> void:
	var label := "TAMU • Quest %d/%d" % [quest.progress(), quest.target()]
	if quest.is_reward_claimed():
		label += " • Reward claimed"
	if selected != &"":
		var target_position := _target_for_selected()
		var reachable := player.position.distance_to(target_position) <= INTERACTION_DISTANCE
		label += " • %s • %s" % [selected, "In range" if reachable else "Out of range"]
		if selected == &"Chest" and inventory != null:
			label += " • Bag %d • Chest %d" % [
				inventory.count(inventory.bag), inventory.count(inventory.chest)
			]
	if status.text != label:
		status.text = label
	_update_inventory_controls()


func _draw() -> void:
	draw_rect(ROOM, Color("#20372b"))
	draw_rect(ROOM, Color("#416150"), false, 2.0)
	draw_rect(Rect2(CHEST - Vector2(21.0, 15.0), Vector2(42.0, 30.0)), Color("#b27b3e"))
	draw_circle(TREE, 23.0, Color("#558651"), true, -1.0, true)
	if not pickup_taken:
		draw_circle(PICKUP, 11.0, Color("#c99a58"), true, -1.0, true)
	if not pickup_two_taken:
		draw_circle(PICKUP_TWO, 11.0, Color("#c99a58"), true, -1.0, true)
	if selected != &"":
		draw_arc(_target_for_selected(), 27.0, 0.0, TAU, 40, Color("#f7d38a"), 2.0, true)
