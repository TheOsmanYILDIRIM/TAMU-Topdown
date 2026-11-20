extends Node2D

const ROOM := Rect2(30.0, 54.0, 580.0, 274.0)
const CHEST := Vector2(288.0, 190.0)
const TREE := Vector2(351.0, 207.0)
const PICKUP := Vector2(440.0, 190.0)
const PICKUP_TWO := Vector2(500.0, 190.0)
const INTERACTION_DISTANCE: float = 65.0
const PASSIVE_THREAT_DISTANCE: float = 72.0
const ATTACK_WINDOW_SECONDS: float = 0.25
const PlayerController = preload("res://scripts/player.gd")
const InventoryBridge = preload("res://scripts/inventory_bridge.gd")
const QuestBridge = preload("res://scripts/quest_bridge.gd")
const SaveAdapter = preload("res://scripts/save_adapter.gd")
const GuiCaptureDriver = preload("res://scripts/gui_capture_driver.gd")
const CraftingAdapter = preload("res://scripts/crafting_adapter.gd")
const CraftingBookAdapter = preload("res://scripts/crafting_book_adapter.gd")

@onready var player: PlayerController = $Player
@onready var status: Label = $HUD/Status
@onready var bag_to_chest_button: Button = $HUD/BagToChest
@onready var chest_to_bag_button: Button = $HUD/ChestToBag
@onready var take_button: Button = $HUD/TakePickup
@onready var reward_button: Button = $HUD/ClaimReward
@onready var save_button: Button = $HUD/Save
@onready var load_button: Button = $HUD/Load
@onready var combat_target: TamuCombatTarget = $CombatTarget
@onready var passive_animal: TamuPassiveAnimal = $PassiveAnimal
@onready var attack_hit_box: BasicHitBox2D = $Player/AttackHitBox
@onready var attack_window: Timer = $AttackWindow
@onready var interaction_feedback: TamuInteractionFeedbackAdapter = $InteractionFeedback
@onready var mobile_hud: TamuGohudAdapter = $HUD/MobileHud
@onready var mini_map: TamuMiniMapAdapter = $HUD/MiniMap

var selected: StringName = &""
var inventory: TamuInventoryBridge
var quest: TamuQuestBridge
var pickup_taken: bool = false
var pickup_two_taken: bool = false
var attack_active: bool = false
var crafting: TamuCraftingAdapter
var crafting_book: TamuCraftingBookAdapter
var craft_command_sequence := 0
var placement_active := false
var placement_def_id: StringName = &""
var placement_position := Vector2.ZERO
var placement_rotation := 0
var placement_status := ""
var placed_structures: Array[Dictionary] = []


func _ready() -> void:
	inventory = InventoryBridge.new(4, 4)
	crafting = CraftingAdapter.new(inventory)
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
	mobile_hud.bag_to_chest_requested.connect(_on_bag_to_chest_pressed)
	mobile_hud.chest_to_bag_requested.connect(_on_chest_to_bag_pressed)
	mobile_hud.context_action_requested.connect(_on_context_action_requested)
	mobile_hud.craft_book_requested.connect(open_crafting_book)
	crafting_book = CraftingBookAdapter.new()
	crafting_book.name = "CraftingBook"
	crafting_book.setup(inventory, crafting)
	$HUD.add_child(crafting_book)
	crafting_book.craft_requested.connect(_on_craft_requested)
	crafting_book.placement_rotate_requested.connect(rotate_placement)
	crafting_book.placement_cancel_requested.connect(cancel_placement)
	mini_map.set_target(player)
	mobile_hud.bind_survival(player.health, $SurvivalStats as SurvivalStats, $DayNightClock as DayNightClock)
	attack_hit_box.hurt_box_entered.connect(_on_attack_hurt_box_entered)
	attack_window.timeout.connect(_on_attack_window_timeout)
	attack_window.wait_time = ATTACK_WINDOW_SECONDS
	attack_hit_box.monitoring = false
	attack_hit_box.ignore_collisions = true
	_update_inventory_controls()
	if OS.get_cmdline_user_args().has("--gui-capture"):
		var capture_driver := GuiCaptureDriver.new()
		capture_driver.name = "GuiCaptureDriver"
		capture_driver.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child.call_deferred(capture_driver)


func _unhandled_input(event: InputEvent) -> void:
	if crafting_book != null and crafting_book.handle_back_event(event):
		get_viewport().set_input_as_handled()
		return
	if mini_map != null and mini_map.handle_back_event(event):
		get_viewport().set_input_as_handled()
		return
	if mobile_hud != null and mobile_hud.handle_back_event(event):
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		perform_attack()
		get_viewport().set_input_as_handled()
		return

	if placement_active:
		var placement_point: Vector2
		if event is InputEventScreenTouch and event.pressed:
			placement_point = event.position
		elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			placement_point = event.position
		else:
			return
		var placement_local := get_global_transform_with_canvas().affine_inverse() * placement_point
		try_place_at(placement_local)
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
	if (
		combat_target != null
		and combat_target.health != null
		and not combat_target.health.is_dead()
		and point.distance_to(combat_target.position) <= 16.0
	):
		selected = &"CombatTarget"
	elif Rect2(CHEST - Vector2(21.0, 15.0), Vector2(42.0, 30.0)).has_point(point):
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
		_sync_interaction_feedback(false)
		queue_redraw()
		return
	player.stop_walking()
	_update_inventory_controls()
	_sync_interaction_feedback(true)
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
	if selected == &"CombatTarget" and combat_target != null:
		return combat_target.position
	if selected == &"Chest":
		return CHEST
	if selected == &"Tree":
		return TREE
	if selected == &"Pickup":
		return PICKUP
	if selected == &"Pickup2":
		return PICKUP_TWO
	return player.position


func _selection_feedback_radius() -> float:
	if selected == &"CombatTarget":
		return 18.0
	if selected == &"Chest":
		return 27.0
	if selected == &"Tree":
		return 29.0
	if selected == &"Pickup" or selected == &"Pickup2":
		return 18.0
	return 27.0


func _sync_interaction_feedback(tap_feedback: bool = false) -> void:
	if interaction_feedback == null:
		return
	if selected == &"":
		interaction_feedback.clear_target()
		return
	var target_position := _target_for_selected()
	var reachable := player.position.distance_to(target_position) <= INTERACTION_DISTANCE
	interaction_feedback.show_target(
		selected,
		target_position,
		_selection_feedback_radius(),
		reachable,
		tap_feedback
	)


func _chest_reachable() -> bool:
	return selected == &"Chest" and player.position.distance_to(CHEST) <= INTERACTION_DISTANCE


func _pickup_reachable() -> bool:
	if selected == &"Pickup":
		return not pickup_taken and player.position.distance_to(PICKUP) <= INTERACTION_DISTANCE
	if selected == &"Pickup2":
		return not pickup_two_taken and player.position.distance_to(PICKUP_TWO) <= INTERACTION_DISTANCE
	return false


func _combat_target_available() -> bool:
	return (
		selected == &"CombatTarget"
		and combat_target != null
		and combat_target.health != null
		and not combat_target.health.is_dead()
	)


func _combat_target_ui_reachable() -> bool:
	return (
		_combat_target_available()
		and player.position.distance_to(combat_target.position) <= INTERACTION_DISTANCE
	)


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
	_sync_interaction_feedback(false)
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
	cancel_placement()
	placed_structures.clear()
	_update_inventory_controls()
	_sync_interaction_feedback(false)
	queue_redraw()
	return result


func open_crafting_book() -> void:
	if mobile_hud.bag_open:
		mobile_hud.close_bag()
	if mobile_hud.pause_open or placement_active:
		return
	crafting_book.open_book()


func _on_craft_requested(recipe_id: StringName) -> void:
	craft_command_sequence += 1
	var result := crafting.begin(
		"topdown-craft-%d" % craft_command_sequence,
		recipe_id,
		_station_tags_near_player()
	)
	crafting_book.notify_craft_result(result)
	_update_inventory_controls()


func _station_tags_near_player() -> Array:
	var tags: Array = []
	for placed: Dictionary in placed_structures:
		if StringName(placed.get("def_id", "")) != InventoryBridge.WORKBENCH_STABLE_ID:
			continue
		var box: Rect2 = placed.get("box", Rect2())
		var nearest := Vector2(
			clampf(player.position.x, box.position.x, box.end.x),
			clampf(player.position.y, box.position.y, box.end.y)
		)
		if player.position.distance_to(nearest) <= 60.0:
			tags.append(&"core:bench")
			break
	return tags


func start_placement(def_id: StringName) -> Dictionary:
	if def_id != InventoryBridge.WORKBENCH_STABLE_ID:
		return {"ok": false, "status": "not_placeable"}
	placement_active = true
	placement_def_id = def_id
	placement_rotation = 0
	placement_position = player.position + Vector2(48.0, 0.0)
	var preview := preview_placement(placement_position, placement_rotation)
	placement_status = str(preview.get("status", "invalid_surface"))
	crafting_book.set_placement_mode(true, placement_status, placement_rotation)
	queue_redraw()
	return preview


func cancel_placement() -> void:
	if not placement_active:
		return
	placement_active = false
	placement_def_id = &""
	placement_status = ""
	if crafting_book != null:
		crafting_book.set_placement_mode(false)
	queue_redraw()


func rotate_placement() -> void:
	if not placement_active:
		return
	placement_rotation = (placement_rotation + 1) % 4
	var preview := preview_placement(placement_position, placement_rotation)
	placement_status = str(preview.get("status", "invalid_rotation"))
	crafting_book.update_placement_status(placement_status, placement_rotation)
	queue_redraw()


func preview_placement(at: Vector2, rotation: int) -> Dictionary:
	if placement_def_id != InventoryBridge.WORKBENCH_STABLE_ID:
		return {"ok": false, "status": "not_placeable"}
	if rotation < 0 or rotation >= 4:
		return {"ok": false, "status": "invalid_rotation"}
	if at.distance_squared_to(player.position) > 96.0 * 96.0:
		return {"ok": false, "status": "out_of_range"}
	var box := Rect2(at - Vector2(16.0, 16.0), Vector2(32.0, 32.0))
	if not ROOM.has_point(box.position) or not ROOM.has_point(box.end - Vector2(0.01, 0.01)):
		return {"ok": false, "status": "invalid_surface", "box": box}
	var player_box := Rect2(player.position - Vector2(5.0, 5.0), Vector2(10.0, 10.0))
	if box.intersects(player_box, true):
		return {"ok": false, "status": "player_overlap", "box": box}
	var obstacles: Array = [
		Rect2(CHEST - Vector2(21.0, 15.0), Vector2(42.0, 30.0)),
		Rect2(TREE - Vector2(23.0, 23.0), Vector2(46.0, 46.0)),
	]
	if combat_target != null and combat_target.health != null and not combat_target.health.is_dead():
		obstacles.append(Rect2(combat_target.position - Vector2(12.0, 12.0), Vector2(24.0, 24.0)))
	for placed: Dictionary in placed_structures:
		obstacles.append(placed.get("box", Rect2()))
	for obstacle_value: Variant in obstacles:
		var obstacle: Rect2 = obstacle_value
		if box.intersects(obstacle, true):
			return {"ok": false, "status": "obstructed", "box": box}
	if inventory.count_item(inventory.bag, InventoryBridge.WORKBENCH_STABLE_ID) < 1:
		return {"ok": false, "status": "insufficient_materials", "box": box}
	return {"ok": true, "status": "valid", "box": box}


func try_place_at(at: Vector2) -> Dictionary:
	if not placement_active:
		return {"ok": false, "status": "inactive"}
	placement_position = at
	var preview := preview_placement(at, placement_rotation)
	placement_status = str(preview.get("status", "invalid_surface"))
	crafting_book.update_placement_status(placement_status, placement_rotation)
	if not bool(preview.get("ok", false)):
		queue_redraw()
		return preview
	if inventory.remove_item_from_bag_atomic(InventoryBridge.WORKBENCH_STABLE_ID, 1) != 1:
		placement_status = "insufficient_materials"
		crafting_book.update_placement_status(placement_status, placement_rotation)
		queue_redraw()
		return {"ok": false, "status": placement_status}
	var instance_id := _new_uuid_v4()
	placed_structures.append({
		"id": instance_id,
		"def_id": String(InventoryBridge.WORKBENCH_STABLE_ID),
		"box": preview["box"],
		"rotation": placement_rotation,
		"owner_id": "topdown:player",
	})
	placement_active = false
	placement_def_id = &""
	crafting_book.set_placement_mode(false)
	_update_inventory_controls()
	queue_redraw()
	return {"ok": true, "status": "placed", "instance_id": instance_id}


func _new_uuid_v4() -> String:
	var bytes := Crypto.new().generate_random_bytes(16)
	bytes[6] = (bytes[6] & 0x0f) | 0x40
	bytes[8] = (bytes[8] & 0x3f) | 0x80
	var hex := ""
	for value in bytes:
		hex += "%02x" % int(value)
	return "%s-%s-%s-%s-%s" % [
		hex.substr(0, 8),
		hex.substr(8, 4),
		hex.substr(12, 4),
		hex.substr(16, 4),
		hex.substr(20, 12),
	]


func _on_context_action_requested() -> void:
	match selected:
		&"CombatTarget":
			if _combat_target_ui_reachable():
				perform_attack()
		&"Pickup", &"Pickup2":
			take_selected_pickup()
		&"Chest":
			if _chest_reachable():
				mobile_hud.open_bag()


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
	if mobile_hud != null:
		mobile_hud.sync_inventory(inventory, reachable)
		_update_context_action()


func _update_context_action() -> void:
	if mobile_hud == null:
		return
	match selected:
		&"CombatTarget":
			var valid_target := _combat_target_available()
			mobile_hud.set_context_action(
				"Saldır",
				valid_target and _combat_target_ui_reachable(),
				valid_target
			)
		&"Pickup", &"Pickup2":
			var pickup_exists := (
				(selected == &"Pickup" and not pickup_taken)
				or (selected == &"Pickup2" and not pickup_two_taken)
			)
			var can_collect := _pickup_reachable() and inventory.bag_remaining_capacity() > 0
			mobile_hud.set_context_action("Topla", can_collect, pickup_exists)
		&"Chest":
			mobile_hud.set_context_action("Sandığı aç", _chest_reachable(), true)
		_:
			mobile_hud.clear_context_action()


func _update_passive_animal_threat() -> void:
	if passive_animal == null:
		return
	if player.position.distance_to(passive_animal.position) <= PASSIVE_THREAT_DISTANCE:
		passive_animal.set_threat(player.position)
	else:
		passive_animal.clear_threat()


func _process(_delta: float) -> void:
	var craft_result := crafting.tick(_delta, _station_tags_near_player())
	if not craft_result.is_empty():
		crafting_book.notify_craft_result(craft_result)
		_update_inventory_controls()
		if bool(craft_result.get("ok", false)):
			for output_value: Variant in craft_result.get("outputs", []):
				var output := output_value as Dictionary
				if StringName(output.get("def_id", "")) == InventoryBridge.WORKBENCH_STABLE_ID:
					start_placement(InventoryBridge.WORKBENCH_STABLE_ID)
					break
	_update_passive_animal_threat()
	_sync_interaction_feedback(false)
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
	for placed: Dictionary in placed_structures:
		var placed_box: Rect2 = placed.get("box", Rect2())
		draw_rect(placed_box, Color("#8f6848"), true)
		draw_rect(placed_box, Color("#d0ad78"), false, 2.0)
	if placement_active:
		var preview := preview_placement(placement_position, placement_rotation)
		var box: Rect2 = preview.get(
			"box",
			Rect2(placement_position - Vector2(16.0, 16.0), Vector2(32.0, 32.0))
		)
		var fill := Color(0.35, 0.72, 0.48, 0.32) if bool(preview.get("ok", false)) else Color(0.78, 0.28, 0.22, 0.32)
		var edge := Color("#8fd39a") if bool(preview.get("ok", false)) else Color("#df7768")
		draw_rect(box, fill, true)
		draw_rect(box, edge, false, 2.0)
