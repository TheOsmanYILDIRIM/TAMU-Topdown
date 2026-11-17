extends GdUnitTestSuite

const PROTOTYPE: PackedScene = preload("res://scenes/prototype.tscn")
const Prototype = preload("res://scripts/prototype.gd")
const PlayerController = preload("res://scripts/player.gd")
const InventoryBridge = preload("res://scripts/inventory_bridge.gd")


func test_floor_touch_moves_player() -> void:
	var room: Prototype = auto_free(PROTOTYPE.instantiate()) as Prototype
	var tree := Engine.get_main_loop() as SceneTree
	_attach_to_test_viewport(room, tree)
	var player: PlayerController = room.player
	var start := player.position
	var target := start + Vector2(32.0, 0.0)
	await _tap(room, target)
	for frame in range(90):
		if player.position.distance_to(target) < 0.75:
			break
		await tree.physics_frame
	assert_bool(player.position.distance_to(start) > 20.0).is_true()
	assert_bool(player.position.distance_to(target) < 0.75).is_true()


func test_touch_selects_exact_object() -> void:
	var room: Prototype = auto_free(PROTOTYPE.instantiate()) as Prototype
	var tree := Engine.get_main_loop() as SceneTree
	_attach_to_test_viewport(room, tree)
	await _tap(room, Vector2(307.0, 190.0))
	assert_str(String(room.selected)).is_equal("Chest")
	await _tap(room, Vector2(331.0, 207.0))
	assert_str(String(room.selected)).is_equal("Tree")
	await _tap(room, Vector2(315.0, 199.0))
	assert_str(String(room.selected)).is_empty()


func test_inventory_transfers_both_directions_through_selected_chest() -> void:
	var room: Prototype = auto_free(PROTOTYPE.instantiate()) as Prototype
	var tree := Engine.get_main_loop() as SceneTree
	_attach_to_test_viewport(room, tree)
	await tree.process_frame
	room.player.position = Vector2(250.0, 190.0)
	room.select_at(Vector2(288.0, 190.0))

	assert_int(room.transfer_to_selected_chest(7)).is_equal(7)
	assert_int(room.inventory.count(room.inventory.bag)).is_equal(5)
	assert_int(room.inventory.count(room.inventory.chest)).is_equal(7)
	assert_int(room.transfer_from_selected_chest(2)).is_equal(2)
	assert_int(room.inventory.count(room.inventory.bag)).is_equal(7)
	assert_int(room.inventory.count(room.inventory.chest)).is_equal(5)
	assert_int(
		room.inventory.count(room.inventory.bag) + room.inventory.count(room.inventory.chest)
	).is_equal(12)


func test_inventory_partial_transfer_stops_at_target_capacity() -> void:
	var inventory := InventoryBridge.new(2, 1)
	_add(inventory.bag, 10)
	_add(inventory.chest, 95)

	assert_str(String(inventory.definition.get("id", ""))).is_equal("core:wood_log")
	assert_int(inventory.registry.get_stack_capacity(InventoryBridge.WOOD_LOG_PLUGIN_ID)).is_equal(99)
	assert_int(inventory.bag_to_chest(10)).is_equal(4)
	assert_int(inventory.count(inventory.bag)).is_equal(6)
	assert_int(inventory.count(inventory.chest)).is_equal(99)
	assert_int(inventory.count(inventory.bag) + inventory.count(inventory.chest)).is_equal(105)


func test_inventory_full_target_preserves_source_and_total() -> void:
	var inventory := InventoryBridge.new(2, 1)
	_add(inventory.bag, 10)
	_add(inventory.chest, 99)

	assert_int(inventory.bag_to_chest(6)).is_equal(0)
	assert_int(inventory.count(inventory.bag)).is_equal(10)
	assert_int(inventory.count(inventory.chest)).is_equal(99)
	assert_int(inventory.count(inventory.bag) + inventory.count(inventory.chest)).is_equal(109)


func _add(storage: InventoryManager, amount: int) -> void:
	var excess: ExcessItems = storage.add(
		InventoryBridge.WOOD_LOG_PLUGIN_ID, amount, null, -1, false
	)
	assert_bool(excess == null).is_true()


func _attach_to_test_viewport(room: Prototype, tree: SceneTree) -> void:
	var viewport: SubViewport = auto_free(SubViewport.new()) as SubViewport
	viewport.size = Vector2i(640, 360)
	tree.root.add_child(viewport)
	viewport.add_child(room)


func _tap(room: Prototype, point: Vector2) -> void:
	await room.get_tree().process_frame
	var event := InputEventScreenTouch.new()
	event.position = room.get_global_transform_with_canvas() * point
	event.pressed = true
	room.get_viewport().push_input(event, true)
	await room.get_tree().process_frame
