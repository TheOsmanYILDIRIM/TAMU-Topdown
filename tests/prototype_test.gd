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


func test_save_round_trip_restores_player_inventory_and_world_pickup() -> void:
	var slot_id := 9301
	SaveManager.delete_slot(slot_id)
	var room: Prototype = auto_free(PROTOTYPE.instantiate()) as Prototype
	var tree := Engine.get_main_loop() as SceneTree
	_attach_to_test_viewport(room, tree)
	await tree.process_frame

	room.player.position = Vector2(250.0, 190.0)
	room.select_at(Vector2(288.0, 190.0))
	assert_int(room.transfer_to_selected_chest(5)).is_equal(5)

	room.player.position = Vector2(400.0, 190.0)
	room.select_at(Prototype.PICKUP)
	assert_bool(room.take_selected_pickup()).is_true()
	var saved_position := room.player.position
	assert_int(room.save_game(slot_id)).is_equal(OK)

	room.player.position = Vector2(100.0, 100.0)
	room.inventory.bag.clear()
	room.inventory.chest.clear()
	_add(room.inventory.bag, 2)
	room.pickup_taken = false

	var loaded := room.load_game(slot_id)
	assert_bool(bool(loaded.get("ok", false))).is_true()
	assert_bool(bool(loaded.get("recovered", false))).is_false()
	assert_bool(room.player.position.distance_to(saved_position) < 0.01).is_true()
	assert_int(room.inventory.count(room.inventory.bag)).is_equal(8)
	assert_int(room.inventory.count(room.inventory.chest)).is_equal(5)
	assert_bool(room.pickup_taken).is_true()
	assert_int(SaveManager.delete_slot(slot_id)).is_equal(OK)


func test_interrupted_write_recovers_last_good_state() -> void:
	var slot_id := 9302
	SaveManager.delete_slot(slot_id)
	var room: Prototype = auto_free(PROTOTYPE.instantiate()) as Prototype
	var tree := Engine.get_main_loop() as SceneTree
	_attach_to_test_viewport(room, tree)
	await tree.process_frame

	room.player.position = Vector2(250.0, 190.0)
	room.select_at(Vector2(288.0, 190.0))
	assert_int(room.transfer_to_selected_chest(3)).is_equal(3)
	var saved_position := room.player.position
	assert_int(room.save_game(slot_id)).is_equal(OK)

	var state_path: String = SaveManager.state_path_for_slot(slot_id)
	var backup_path: String = SaveManager.backup_path_for_slot(slot_id)
	var tmp_path: String = SaveManager.temp_path_for_slot(slot_id)
	if FileAccess.file_exists(backup_path):
		assert_int(DirAccess.remove_absolute(backup_path)).is_equal(OK)
	assert_int(DirAccess.rename_absolute(state_path, backup_path)).is_equal(OK)
	_write_text(tmp_path, "{\"version\": 1")

	room.player.position = Vector2(500.0, 280.0)
	room.inventory.bag.clear()
	room.inventory.chest.clear()
	_add(room.inventory.bag, 1)

	var loaded := room.load_game(slot_id)
	assert_bool(bool(loaded.get("ok", false))).is_true()
	assert_bool(bool(loaded.get("recovered", false))).is_true()
	assert_bool(room.player.position.distance_to(saved_position) < 0.01).is_true()
	assert_int(room.inventory.count(room.inventory.bag)).is_equal(9)
	assert_int(room.inventory.count(room.inventory.chest)).is_equal(3)
	assert_int(SaveManager.delete_slot(slot_id)).is_equal(OK)


func test_corrupt_or_unsupported_save_does_not_mutate_live_state() -> void:
	var slot_id := 9303
	SaveManager.delete_slot(slot_id)
	var room: Prototype = auto_free(PROTOTYPE.instantiate()) as Prototype
	var tree := Engine.get_main_loop() as SceneTree
	_attach_to_test_viewport(room, tree)
	await tree.process_frame
	assert_int(room.save_game(slot_id)).is_equal(OK)

	room.player.position = Vector2(260.0, 190.0)
	room.inventory.bag.clear()
	room.inventory.chest.clear()
	_add(room.inventory.bag, 4)
	_add(room.inventory.chest, 6)
	room.pickup_taken = true
	var live_position := room.player.position

	var state_path: String = SaveManager.state_path_for_slot(slot_id)
	_write_text(state_path, "{broken")
	var corrupt_result := room.load_game(slot_id)
	assert_bool(bool(corrupt_result.get("ok", true))).is_false()
	_assert_live_state_unchanged(room, live_position, 4, 6, true)

	_write_text(state_path, "{\"version\":999,\"saved_unix\":0,\"data\":{}}")
	var unsupported_result := room.load_game(slot_id)
	assert_bool(bool(unsupported_result.get("ok", true))).is_false()
	_assert_live_state_unchanged(room, live_position, 4, 6, true)
	assert_int(SaveManager.delete_slot(slot_id)).is_equal(OK)


func _assert_live_state_unchanged(
	room: Prototype,
	expected_position: Vector2,
	expected_bag: int,
	expected_chest: int,
	expected_taken: bool
) -> void:
	assert_bool(room.player.position.distance_to(expected_position) < 0.01).is_true()
	assert_int(room.inventory.count(room.inventory.bag)).is_equal(expected_bag)
	assert_int(room.inventory.count(room.inventory.chest)).is_equal(expected_chest)
	assert_bool(room.pickup_taken).is_equal(expected_taken)


func _write_text(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert_bool(file != null).is_true()
	file.store_string(text)
	file.flush()
	file.close()


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
