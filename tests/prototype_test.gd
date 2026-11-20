extends GdUnitTestSuite

const PROTOTYPE: PackedScene = preload("res://scenes/prototype.tscn")
const Prototype = preload("res://scripts/prototype.gd")
const PlayerController = preload("res://scripts/player.gd")
const InventoryBridge = preload("res://scripts/inventory_bridge.gd")
const SaveAdapter = preload("res://scripts/save_adapter.gd")


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


func test_partial_quest_progress_survives_save_and_load() -> void:
	var slot_id := 9401
	SaveManager.delete_slot(slot_id)
	var room: Prototype = auto_free(PROTOTYPE.instantiate()) as Prototype
	var tree := Engine.get_main_loop() as SceneTree
	_attach_to_test_viewport(room, tree)
	await tree.process_frame

	room.player.position = Prototype.PICKUP
	room.select_at(Prototype.PICKUP)
	assert_bool(room.take_selected_pickup()).is_true()
	assert_int(room.quest.progress()).is_equal(1)
	assert_bool(room.quest.is_completed()).is_false()
	assert_bool(room.quest.is_reward_claimed()).is_false()
	assert_int(room.save_game(slot_id)).is_equal(OK)

	assert_int(room.quest.record_collection(InventoryBridge.WOOD_LOG_STABLE_ID, 1)).is_equal(1)
	assert_bool(room.quest.is_completed()).is_true()

	var loaded := room.load_game(slot_id)
	assert_bool(bool(loaded.get("ok", false))).is_true()
	assert_int(room.quest.progress()).is_equal(1)
	assert_bool(room.quest.is_completed()).is_false()
	assert_bool(room.quest.is_reward_claimed()).is_false()
	assert_bool(room.pickup_taken).is_true()
	assert_bool(room.pickup_two_taken).is_false()

	room.player.position = Prototype.PICKUP_TWO
	room.select_at(Prototype.PICKUP_TWO)
	assert_bool(room.take_selected_pickup()).is_true()
	assert_int(room.quest.progress()).is_equal(2)
	assert_bool(room.quest.is_completed()).is_true()
	assert_int(SaveManager.delete_slot(slot_id)).is_equal(OK)


func test_failed_collection_does_not_advance_quest() -> void:
	var room: Prototype = auto_free(PROTOTYPE.instantiate()) as Prototype
	var tree := Engine.get_main_loop() as SceneTree
	_attach_to_test_viewport(room, tree)
	await tree.process_frame
	room.inventory.bag.clear()
	_add(room.inventory.bag, 396)
	room.player.position = Prototype.PICKUP
	room.select_at(Prototype.PICKUP)

	assert_bool(room.take_selected_pickup()).is_false()
	assert_int(room.inventory.count(room.inventory.bag)).is_equal(396)
	assert_int(room.quest.progress()).is_equal(0)
	assert_bool(room.pickup_taken).is_false()


func test_claimed_reward_is_not_granted_twice_after_load() -> void:
	var slot_id := 9402
	SaveManager.delete_slot(slot_id)
	var room: Prototype = auto_free(PROTOTYPE.instantiate()) as Prototype
	var tree := Engine.get_main_loop() as SceneTree
	_attach_to_test_viewport(room, tree)
	await tree.process_frame

	room.player.position = Prototype.PICKUP
	room.select_at(Prototype.PICKUP)
	assert_bool(room.take_selected_pickup()).is_true()
	room.player.position = Prototype.PICKUP_TWO
	room.select_at(Prototype.PICKUP_TWO)
	assert_bool(room.take_selected_pickup()).is_true()
	assert_bool(room.quest.is_completed()).is_true()

	var before_reward := room.inventory.count(room.inventory.bag)
	assert_int(room.claim_quest_reward()).is_equal(room.quest.reward_amount())
	assert_int(room.inventory.count(room.inventory.bag)).is_equal(before_reward + room.quest.reward_amount())
	assert_bool(room.quest.is_reward_claimed()).is_true()
	assert_int(room.save_game(slot_id)).is_equal(OK)

	var restored: Prototype = auto_free(PROTOTYPE.instantiate()) as Prototype
	_attach_to_test_viewport(restored, tree)
	await tree.process_frame
	var loaded := restored.load_game(slot_id)
	assert_bool(bool(loaded.get("ok", false))).is_true()
	assert_bool(restored.quest.is_completed()).is_true()
	assert_bool(restored.quest.is_reward_claimed()).is_true()
	var loaded_count := restored.inventory.count(restored.inventory.bag)
	assert_int(restored.claim_quest_reward()).is_equal(0)
	assert_int(restored.inventory.count(restored.inventory.bag)).is_equal(loaded_count)
	assert_int(SaveManager.delete_slot(slot_id)).is_equal(OK)


func test_full_bag_reward_is_atomic_and_remains_unclaimed() -> void:
	var room: Prototype = auto_free(PROTOTYPE.instantiate()) as Prototype
	var tree := Engine.get_main_loop() as SceneTree
	_attach_to_test_viewport(room, tree)
	await tree.process_frame

	room.player.position = Prototype.PICKUP
	room.select_at(Prototype.PICKUP)
	assert_bool(room.take_selected_pickup()).is_true()
	room.player.position = Prototype.PICKUP_TWO
	room.select_at(Prototype.PICKUP_TWO)
	assert_bool(room.take_selected_pickup()).is_true()
	var current := room.inventory.count(room.inventory.bag)
	_add(room.inventory.bag, 396 - current)

	assert_int(room.claim_quest_reward()).is_equal(0)
	assert_int(room.inventory.count(room.inventory.bag)).is_equal(396)
	assert_bool(room.quest.is_reward_claimed()).is_false()


func test_legacy_save_without_quest_fields_loads_default_quest_state() -> void:
	var slot_id := 9403
	SaveManager.delete_slot(slot_id)
	var room: Prototype = auto_free(PROTOTYPE.instantiate()) as Prototype
	var tree := Engine.get_main_loop() as SceneTree
	_attach_to_test_viewport(room, tree)
	await tree.process_frame

	var legacy_state := SaveAdapter.capture(
		room.player.position,
		room.inventory,
		room.pickup_taken,
		room.pickup_two_taken,
		room.quest
	)
	legacy_state.erase("quests")
	var legacy_world := legacy_state.get("world", {}) as Dictionary
	legacy_world.erase(SaveAdapter.WORLD_PICKUP_TWO_STABLE_ID)
	assert_int(SaveManager.save_slot(slot_id, legacy_state, "Legacy prototype room")).is_equal(OK)

	assert_int(room.quest.record_collection(InventoryBridge.WOOD_LOG_STABLE_ID, 1)).is_equal(1)
	room.pickup_two_taken = true

	var loaded := room.load_game(slot_id)
	assert_bool(bool(loaded.get("ok", false))).is_true()
	assert_int(room.quest.progress()).is_equal(0)
	assert_bool(room.quest.is_completed()).is_false()
	assert_bool(room.quest.is_reward_claimed()).is_false()
	assert_bool(room.pickup_two_taken).is_false()
	assert_int(SaveManager.delete_slot(slot_id)).is_equal(OK)


func test_combat_hit_uses_real_2d_collision() -> void:
	var room: Prototype = auto_free(PROTOTYPE.instantiate()) as Prototype
	var tree := Engine.get_main_loop() as SceneTree
	_attach_to_test_viewport(room, tree)
	await tree.process_frame
	room.combat_target.reset_for_test()
	room.player.position = room.combat_target.position - Vector2(45.0, 0.0)

	assert_bool(room.perform_attack()).is_true()
	await _wait_for_attack_end(room, tree)
	assert_int(room.combat_target.health.current).is_equal(3)


func test_combat_miss_outside_range_does_not_damage() -> void:
	var room: Prototype = auto_free(PROTOTYPE.instantiate()) as Prototype
	var tree := Engine.get_main_loop() as SceneTree
	_attach_to_test_viewport(room, tree)
	await tree.process_frame
	room.combat_target.reset_for_test()
	room.player.position = room.combat_target.position - Vector2(120.0, 0.0)

	assert_bool(room.perform_attack()).is_true()
	await _wait_for_attack_end(room, tree)
	assert_int(room.combat_target.health.current).is_equal(6)
	assert_int(room.combat_target.death_count).is_equal(0)


func test_combat_same_attack_cannot_damage_target_twice() -> void:
	var room: Prototype = auto_free(PROTOTYPE.instantiate()) as Prototype
	var tree := Engine.get_main_loop() as SceneTree
	_attach_to_test_viewport(room, tree)
	await tree.process_frame
	room.combat_target.reset_for_test()
	room.player.position = room.combat_target.position - Vector2(45.0, 0.0)
	var target_position := room.combat_target.position

	assert_bool(room.perform_attack()).is_true()
	for frame in range(6):
		if room.combat_target.health.current < 6:
			break
		await tree.physics_frame
	assert_int(room.combat_target.health.current).is_equal(3)

	room.combat_target.position = target_position + Vector2(120.0, 0.0)
	await tree.physics_frame
	room.combat_target.position = target_position
	await tree.physics_frame
	await tree.physics_frame
	assert_int(room.combat_target.health.current).is_equal(3)
	await _wait_for_attack_end(room, tree)


func test_combat_death_signal_is_emitted_once() -> void:
	var room: Prototype = auto_free(PROTOTYPE.instantiate()) as Prototype
	var tree := Engine.get_main_loop() as SceneTree
	_attach_to_test_viewport(room, tree)
	await tree.process_frame
	room.combat_target.reset_for_test()
	room.player.position = room.combat_target.position - Vector2(45.0, 0.0)

	for attack_index in range(3):
		assert_bool(room.perform_attack()).is_true()
		await _wait_for_attack_end(room, tree)

	assert_int(room.combat_target.health.current).is_equal(0)
	assert_int(room.combat_target.death_count).is_equal(1)



func test_fsm_passive_animal_flees_and_returns_to_roam() -> void:
	var room: Prototype = auto_free(PROTOTYPE.instantiate()) as Prototype
	var tree := Engine.get_main_loop() as SceneTree
	_attach_to_test_viewport(room, tree)
	await tree.process_frame
	room.combat_target.set_ai_enabled(false)
	var animal: TamuPassiveAnimal = room.passive_animal
	await _wait_for_state(animal.state_machine, "Roam", tree, 30)

	room.player.position = animal.position - Vector2(30.0, 0.0)
	room.player.stop_walking()
	var before_flee := animal.position
	await _wait_for_state(animal.state_machine, "Flee", tree, 30)
	for frame in range(6):
		await tree.physics_frame
	assert_bool(animal.position.x > before_flee.x).is_true()

	room.player.position = Vector2(80.0, 100.0)
	room.player.stop_walking()
	await _wait_for_state(animal.state_machine, "Roam", tree, 30)


func test_fsm_enemy_windup_prevents_early_damage() -> void:
	var room: Prototype = auto_free(PROTOTYPE.instantiate()) as Prototype
	var tree := Engine.get_main_loop() as SceneTree
	_attach_to_test_viewport(room, tree)
	await tree.process_frame
	var enemy: TamuCombatTarget = room.combat_target
	enemy.reset_for_test()
	room.player.health.max = 12
	room.player.health.current = 12
	room.player.position = enemy.position - Vector2(42.0, 0.0)
	room.player.stop_walking()
	enemy.set_ai_enabled(true)

	await _wait_for_state(enemy.state_machine, "Windup", tree, 30)
	var locked_direction := enemy.attack_direction
	var before_health := room.player.health.current
	assert_bool(enemy.telegraph_active).is_true()
	assert_bool(locked_direction.length() > 0.99).is_true()
	for frame in range(4):
		await tree.physics_frame
	assert_str(String(enemy.current_state_name())).is_equal("Windup")
	assert_int(room.player.health.current).is_equal(before_health)
	assert_bool(enemy.attack_direction.is_equal_approx(locked_direction)).is_true()

	for frame in range(40):
		if room.player.health.current < before_health:
			break
		await tree.physics_frame
	assert_int(room.player.health.current).is_equal(before_health - 2)
	assert_int(enemy.damage_event_count).is_equal(1)


func test_fsm_enemy_recovery_blocks_next_attack() -> void:
	var room: Prototype = auto_free(PROTOTYPE.instantiate()) as Prototype
	var tree := Engine.get_main_loop() as SceneTree
	_attach_to_test_viewport(room, tree)
	await tree.process_frame
	var enemy: TamuCombatTarget = room.combat_target
	enemy.reset_for_test()
	room.player.health.max = 12
	room.player.health.current = 12
	room.player.position = enemy.position - Vector2(42.0, 0.0)
	room.player.stop_walking()
	enemy.set_ai_enabled(true)

	await _wait_for_state(enemy.state_machine, "Recover", tree, 60)
	var first_attack_count := enemy.attack_count
	assert_int(first_attack_count).is_equal(1)
	assert_bool(enemy.recovery_active).is_true()
	for frame in range(8):
		await tree.physics_frame
	assert_str(String(enemy.current_state_name())).is_equal("Recover")
	assert_int(enemy.attack_count).is_equal(first_attack_count)

	await _wait_for_attack_count(enemy, 2, tree, 90)
	assert_int(enemy.attack_count).is_equal(2)
	assert_int(enemy.recover_count).is_greater_equal(1)


func test_fsm_enemy_death_stops_behavior_and_attack() -> void:
	var room: Prototype = auto_free(PROTOTYPE.instantiate()) as Prototype
	var tree := Engine.get_main_loop() as SceneTree
	_attach_to_test_viewport(room, tree)
	await tree.process_frame
	var enemy: TamuCombatTarget = room.combat_target
	enemy.reset_for_test()
	room.player.position = enemy.position - Vector2(42.0, 0.0)
	room.player.stop_walking()
	enemy.set_ai_enabled(true)
	await _wait_for_state(enemy.state_machine, "Windup", tree, 30)

	var death_position := enemy.position
	var attacks_before_death := enemy.attack_count
	enemy.health.kill()
	await tree.physics_frame
	assert_bool(enemy.health.is_dead()).is_true()
	assert_int(enemy.death_count).is_equal(1)
	assert_bool(enemy.behavior_stopped).is_true()
	assert_str(String(enemy.current_state_name())).is_equal("Dead")
	assert_bool(enemy.attack_hit_box.ignore_collisions).is_true()

	for frame in range(20):
		await tree.physics_frame
	assert_bool(enemy.position.is_equal_approx(death_position)).is_true()
	assert_int(enemy.attack_count).is_equal(attacks_before_death)


func test_fsm_invalid_transition_is_rejected() -> void:
	var room: Prototype = auto_free(PROTOTYPE.instantiate()) as Prototype
	var tree := Engine.get_main_loop() as SceneTree
	_attach_to_test_viewport(room, tree)
	await tree.process_frame
	room.combat_target.set_ai_enabled(false)
	var machine: StateMachine = room.passive_animal.state_machine
	var rejection := {"count": 0, "requested": "", "reason": ""}
	machine.transition_rejected.connect(
		func(_from_state: String, requested: String, reason: String) -> void:
			rejection["count"] = int(rejection["count"]) + 1
			rejection["requested"] = requested
			rejection["reason"] = reason
	)
	var before_state := String(machine.current_state.name)

	assert_bool(machine.change_state("NotARealState")).is_false()
	assert_str(String(machine.current_state.name)).is_equal(before_state)
	assert_int(int(rejection["count"])).is_equal(1)
	assert_str(String(rejection["requested"])).is_equal("NotARealState")
	assert_str(String(rejection["reason"])).is_equal("missing_state")
	assert_str(machine.last_rejection_reason).is_equal("missing_state")



func test_survival_day_night_fixed_steps_and_wrap() -> void:
	var room: Prototype = auto_free(PROTOTYPE.instantiate()) as Prototype
	var tree := Engine.get_main_loop() as SceneTree
	_attach_to_test_viewport(room, tree)
	await tree.process_frame
	var survival := room.get_node("SurvivalAdapter") as TamuSurvivalAdapter
	var clock := room.get_node("DayNightClock") as DayNightClock
	var tint := room.get_node("WorldTint") as CanvasModulate
	survival.auto_tick = false
	clock.day_length_sec = 100.0
	clock.time_of_day = 0.69
	clock.day = 4
	clock.phase = DayNightClock.phase_for(clock.time_of_day)

	survival.tick(2.0)
	assert_bool(absf(clock.time_of_day - 0.71) < 0.0001).is_true()
	assert_str(String(clock.phase)).is_equal("dusk")
	assert_bool(absf(tint.color.r - clock.light_level()) < 0.0001).is_true()

	clock.time_of_day = 0.95
	clock.phase = DayNightClock.phase_for(clock.time_of_day)
	survival.tick(10.0)
	assert_bool(absf(clock.time_of_day - 0.05) < 0.0001).is_true()
	assert_int(clock.day).is_equal(5)
	assert_str(String(clock.phase)).is_equal("night")


func test_survival_hunger_and_thirst_progress_once_per_step() -> void:
	var room: Prototype = auto_free(PROTOTYPE.instantiate()) as Prototype
	var tree := Engine.get_main_loop() as SceneTree
	_attach_to_test_viewport(room, tree)
	await tree.process_frame
	var survival := room.get_node("SurvivalAdapter") as TamuSurvivalAdapter
	var stats := room.get_node("SurvivalStats") as SurvivalStats
	survival.auto_tick = false
	stats.hunger = 80.0
	stats.thirst = 90.0
	stats.hunger_per_sec = 0.5
	stats.thirst_per_sec = 0.8

	survival.tick(10.0)
	assert_bool(absf(stats.hunger - 75.0) < 0.0001).is_true()
	assert_bool(absf(stats.thirst - 82.0) < 0.0001).is_true()


func test_survival_deprivation_damages_existing_health_once() -> void:
	var room: Prototype = auto_free(PROTOTYPE.instantiate()) as Prototype
	var tree := Engine.get_main_loop() as SceneTree
	_attach_to_test_viewport(room, tree)
	await tree.process_frame
	var survival := room.get_node("SurvivalAdapter") as TamuSurvivalAdapter
	var stats := room.get_node("SurvivalStats") as SurvivalStats
	survival.auto_tick = false
	survival.damage_interval_sec = 1.0
	survival.damage_per_deprived_need = 2
	stats.hunger = 0.0
	stats.thirst = 50.0
	stats.hunger_per_sec = 0.5
	stats.thirst_per_sec = 0.8
	room.player.health.max = 12
	room.player.health.current = 12
	var events := {"damaged": 0}
	room.player.health.damaged.connect(
		func(_entity: Node, _type: HealthActionType.Enum, _amount: int, _incrementer: int, _multiplier: float, _applied: int) -> void:
			events["damaged"] = int(events["damaged"]) + 1
	)

	survival.tick(1.0)
	assert_int(room.player.health.current).is_equal(10)
	assert_int(int(events["damaged"])).is_equal(1)


func test_survival_death_uses_existing_health_path() -> void:
	var room: Prototype = auto_free(PROTOTYPE.instantiate()) as Prototype
	var tree := Engine.get_main_loop() as SceneTree
	_attach_to_test_viewport(room, tree)
	await tree.process_frame
	var survival := room.get_node("SurvivalAdapter") as TamuSurvivalAdapter
	var stats := room.get_node("SurvivalStats") as SurvivalStats
	survival.auto_tick = false
	survival.damage_interval_sec = 1.0
	survival.damage_per_deprived_need = 2
	stats.hunger = 0.0
	stats.thirst = 100.0
	room.player.health.current = 2
	var events := {"died": 0}
	room.player.health.died.connect(
		func(_entity: Node) -> void:
			events["died"] = int(events["died"]) + 1
	)

	survival.tick(1.0)
	assert_bool(room.player.health.is_dead()).is_true()
	assert_int(int(events["died"])).is_equal(1)
	survival.tick(1.0)
	assert_int(int(events["died"])).is_equal(1)


func test_interaction_feedback_highlights_exact_tapped_target() -> void:
	var room: Prototype = auto_free(PROTOTYPE.instantiate()) as Prototype
	var tree := Engine.get_main_loop() as SceneTree
	_attach_to_test_viewport(room, tree)
	await tree.process_frame
	room.player.position = Vector2(250.0, 190.0)
	room.player.stop_walking()

	await _tap(room, Prototype.CHEST)
	var feedback: TamuInteractionFeedbackAdapter = room.interaction_feedback
	assert_str(String(room.selected)).is_equal("Chest")
	assert_str(String(feedback.selected_target)).is_equal("Chest")
	assert_bool(feedback.visible).is_true()
	assert_bool(feedback.position.is_equal_approx(Prototype.CHEST)).is_true()
	assert_bool(feedback.in_range).is_true()
	assert_int(feedback.pulse_count).is_equal(1)


func test_interaction_feedback_replaces_target_and_clears_on_empty_touch() -> void:
	var room: Prototype = auto_free(PROTOTYPE.instantiate()) as Prototype
	var tree := Engine.get_main_loop() as SceneTree
	_attach_to_test_viewport(room, tree)
	await tree.process_frame
	room.player.position = Vector2(320.0, 195.0)
	room.player.stop_walking()

	await _tap(room, Prototype.CHEST)
	var feedback: TamuInteractionFeedbackAdapter = room.interaction_feedback
	assert_str(String(feedback.selected_target)).is_equal("Chest")
	assert_int(feedback.pulse_count).is_equal(1)

	await _tap(room, Prototype.TREE)
	assert_str(String(room.selected)).is_equal("Tree")
	assert_str(String(feedback.selected_target)).is_equal("Tree")
	assert_bool(feedback.position.is_equal_approx(Prototype.TREE)).is_true()
	assert_int(feedback.pulse_count).is_equal(2)

	await _tap(room, Vector2(315.0, 199.0))
	assert_str(String(room.selected)).is_empty()
	assert_str(String(feedback.selected_target)).is_empty()
	assert_bool(feedback.visible).is_false()


func test_interaction_feedback_out_of_range_does_not_enable_interaction() -> void:
	var room: Prototype = auto_free(PROTOTYPE.instantiate()) as Prototype
	var tree := Engine.get_main_loop() as SceneTree
	_attach_to_test_viewport(room, tree)
	await tree.process_frame
	var bag_before := room.inventory.count(room.inventory.bag)
	var chest_before := room.inventory.count(room.inventory.chest)

	await _tap(room, Prototype.CHEST)
	var feedback: TamuInteractionFeedbackAdapter = room.interaction_feedback
	assert_str(String(room.selected)).is_equal("Chest")
	assert_bool(feedback.visible).is_true()
	assert_bool(feedback.in_range).is_false()
	assert_bool(feedback.current_color().is_equal_approx(TamuInteractionFeedbackAdapter.OUT_OF_RANGE_COLOR)).is_true()
	assert_bool(room.bag_to_chest_button.disabled).is_true()
	assert_int(room.transfer_to_selected_chest(1)).is_equal(0)
	assert_int(room.inventory.count(room.inventory.bag)).is_equal(bag_before)
	assert_int(room.inventory.count(room.inventory.chest)).is_equal(chest_before)


func _wait_for_attack_end(room: Prototype, tree: SceneTree) -> void:
	for frame in range(60):
		if not room.attack_active:
			return
		await tree.physics_frame
	assert_bool(room.attack_active).is_false()



func _wait_for_state(
	machine: StateMachine,
	expected_state: String,
	tree: SceneTree,
	max_frames: int
) -> void:
	for frame in range(max_frames):
		if machine.current_state != null and String(machine.current_state.name) == expected_state:
			return
		await tree.physics_frame
	var actual := "" if machine.current_state == null else String(machine.current_state.name)
	assert_str(actual).is_equal(expected_state)


func _wait_for_attack_count(
	enemy: TamuCombatTarget,
	expected_count: int,
	tree: SceneTree,
	max_frames: int
) -> void:
	for frame in range(max_frames):
		if enemy.attack_count >= expected_count:
			return
		await tree.physics_frame
	assert_int(enemy.attack_count).is_greater_equal(expected_count)


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

func test_gohud_quantities_follow_rubonnek_transfer_and_load() -> void:
	var slot_id := 9509
	SaveManager.delete_slot(slot_id)
	var room: Prototype = auto_free(PROTOTYPE.instantiate()) as Prototype
	var tree := Engine.get_main_loop() as SceneTree
	_attach_to_test_viewport(room, tree)
	await tree.process_frame

	assert_int(room.mobile_hud.displayed_hotbar_total()).is_equal(12)
	assert_int(room.mobile_hud.displayed_bag_total()).is_equal(12)
	assert_int(room.mobile_hud.displayed_chest_total()).is_equal(0)

	room.player.position = Vector2(250.0, 190.0)
	room.select_at(Prototype.CHEST)
	assert_int(room.transfer_to_selected_chest(4)).is_equal(4)
	assert_int(room.inventory.count(room.inventory.bag)).is_equal(8)
	assert_int(room.inventory.count(room.inventory.chest)).is_equal(4)
	assert_int(room.mobile_hud.displayed_hotbar_total()).is_equal(8)
	assert_int(room.mobile_hud.displayed_bag_total()).is_equal(8)
	assert_int(room.mobile_hud.displayed_chest_total()).is_equal(4)
	assert_int(room.save_game(slot_id)).is_equal(OK)

	assert_int(room.transfer_to_selected_chest(2)).is_equal(2)
	assert_int(room.mobile_hud.displayed_bag_total()).is_equal(6)
	assert_int(room.mobile_hud.displayed_chest_total()).is_equal(6)

	var loaded := room.load_game(slot_id)
	assert_bool(bool(loaded.get("ok", false))).is_true()
	assert_int(room.inventory.count(room.inventory.bag)).is_equal(8)
	assert_int(room.inventory.count(room.inventory.chest)).is_equal(4)
	assert_int(room.mobile_hud.displayed_hotbar_total()).is_equal(8)
	assert_int(room.mobile_hud.displayed_bag_total()).is_equal(8)
	assert_int(room.mobile_hud.displayed_chest_total()).is_equal(4)
	assert_int(SaveManager.delete_slot(slot_id)).is_equal(OK)


func test_gohud_touch_is_consumed_before_world_input() -> void:
	var room: Prototype = auto_free(PROTOTYPE.instantiate()) as Prototype
	var tree := Engine.get_main_loop() as SceneTree
	_attach_to_test_viewport(room, tree)
	await tree.process_frame
	var start := room.player.position
	room.player.stop_walking()

	var event := InputEventScreenTouch.new()
	event.position = room.mobile_hud.hotbar_touch_point()
	event.pressed = true
	room.get_viewport().push_input(event, true)
	await tree.process_frame
	for frame: int in range(8):
		await tree.physics_frame

	assert_bool(room.player.position.distance_to(start) < 0.01).is_true()
	assert_str(String(room.selected)).is_empty()


func test_gohud_back_closes_open_bag_before_world_behavior() -> void:
	var room: Prototype = auto_free(PROTOTYPE.instantiate()) as Prototype
	var tree := Engine.get_main_loop() as SceneTree
	_attach_to_test_viewport(room, tree)
	await tree.process_frame
	room.mobile_hud.open_bag()
	assert_bool(room.mobile_hud.bag_open).is_true()

	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.pressed = true
	room.get_viewport().push_input(event, true)
	await tree.process_frame

	assert_bool(room.mobile_hud.bag_open).is_false()
	assert_bool(room.mobile_hud.handle_back_event(event)).is_false()


func test_gohud_injected_safe_area_fits_narrow_and_wide() -> void:
	var room: Prototype = auto_free(PROTOTYPE.instantiate()) as Prototype
	var tree := Engine.get_main_loop() as SceneTree
	_attach_to_test_viewport(room, tree)
	await tree.process_frame

	var narrow := Rect2(12.0, 8.0, 296.0, 344.0)
	room.mobile_hud.set_safe_area_override(narrow)
	room.mobile_hud.open_bag()
	await tree.process_frame
	assert_bool(narrow.encloses(room.mobile_hud.hotbar_row_rect())).is_true()
	assert_bool(narrow.encloses(room.mobile_hud.bag_panel_rect())).is_true()

	var wide := Rect2(24.0, 12.0, 592.0, 336.0)
	room.mobile_hud.set_safe_area_override(wide)
	await tree.process_frame
	assert_bool(wide.encloses(room.mobile_hud.hotbar_row_rect())).is_true()
	assert_bool(wide.encloses(room.mobile_hud.bag_panel_rect())).is_true()
	room.mobile_hud.close_bag()



func test_settings_pause_and_resume_freeze_world_but_menu_keeps_working() -> void:
	var room: Prototype = auto_free(PROTOTYPE.instantiate()) as Prototype
	var tree := Engine.get_main_loop() as SceneTree
	_attach_to_test_viewport(room, tree)
	await tree.process_frame
	var start := room.player.position
	room.player.walk_to(start + Vector2(100.0, 0.0))
	await tree.physics_frame
	var paused_at := room.player.position

	room.mobile_hud.open_pause()
	assert_bool(tree.paused).is_true()
	assert_bool(room.mobile_hud.pause_open).is_true()
	assert_bool(room.mobile_hud.pause_overlay.visible).is_true()
	for frame: int in range(8):
		await tree.process_frame
	assert_bool(room.player.position.distance_to(paused_at) < 0.01).is_true()
	assert_bool(room.mobile_hud.resume_button.visible).is_true()

	room.mobile_hud.resume_button.pressed.emit()
	await tree.process_frame
	assert_bool(tree.paused).is_false()
	assert_bool(room.mobile_hud.pause_open).is_false()
	for frame: int in range(12):
		await tree.physics_frame
	assert_bool(room.player.position.distance_to(paused_at) > 1.0).is_true()


func test_settings_audio_reload_is_separate_from_game_save() -> void:
	var slot_id := 9510
	var settings_path := "user://tamu_audio_settings_test_9510.json"
	_remove_settings_files(settings_path)
	SaveManager.delete_slot(slot_id)
	var room: Prototype = auto_free(PROTOTYPE.instantiate()) as Prototype
	var tree := Engine.get_main_loop() as SceneTree
	_attach_to_test_viewport(room, tree)
	await tree.process_frame

	room.mobile_hud.set_audio_settings_file(settings_path)
	assert_int(room.mobile_hud.reset_audio_defaults(false)).is_equal(OK)
	assert_int(room.mobile_hud.set_audio_level("master", 0.35, true)).is_equal(OK)
	assert_int(room.mobile_hud.set_audio_level("music", 0.45, true)).is_equal(OK)
	assert_int(room.mobile_hud.set_audio_level("sfx", 0.55, true)).is_equal(OK)
	assert_bool(FileAccess.file_exists(settings_path)).is_true()
	assert_bool(not settings_path.begins_with("user://saves/")).is_true()
	assert_int(room.save_game(slot_id)).is_equal(OK)

	assert_int(room.mobile_hud.set_audio_level("master", 1.0, false)).is_equal(OK)
	assert_int(room.mobile_hud.set_audio_level("music", 1.0, false)).is_equal(OK)
	assert_int(room.mobile_hud.set_audio_level("sfx", 1.0, false)).is_equal(OK)
	assert_int(room.mobile_hud.reload_audio_settings()).is_equal(OK)
	assert_bool(absf(room.mobile_hud.audio_level("master") - 0.35) < 0.001).is_true()
	assert_bool(absf(room.mobile_hud.audio_level("music") - 0.45) < 0.001).is_true()
	assert_bool(absf(room.mobile_hud.audio_level("sfx") - 0.55) < 0.001).is_true()

	var state_file := FileAccess.open(SaveManager.state_path_for_slot(slot_id), FileAccess.READ)
	assert_bool(state_file != null).is_true()
	var state_text := state_file.get_as_text()
	state_file.close()
	assert_bool(not state_text.contains("audio")).is_true()
	assert_bool(not state_text.contains("tamu_audio_settings")).is_true()

	room.mobile_hud.reset_audio_defaults(false)
	_remove_settings_files(settings_path)
	assert_int(SaveManager.delete_slot(slot_id)).is_equal(OK)


func test_settings_missing_or_corrupt_file_uses_safe_audio_defaults() -> void:
	var settings_path := "user://tamu_audio_settings_test_9511.json"
	_remove_settings_files(settings_path)
	var room: Prototype = auto_free(PROTOTYPE.instantiate()) as Prototype
	var tree := Engine.get_main_loop() as SceneTree
	_attach_to_test_viewport(room, tree)
	await tree.process_frame
	room.mobile_hud.set_audio_settings_file(settings_path)

	assert_int(room.mobile_hud.reload_audio_settings()).is_equal(OK)
	assert_bool(absf(room.mobile_hud.audio_level("master") - 1.0) < 0.001).is_true()
	assert_bool(absf(room.mobile_hud.audio_level("music") - 1.0) < 0.001).is_true()
	assert_bool(absf(room.mobile_hud.audio_level("sfx") - 1.0) < 0.001).is_true()

	_write_text(settings_path, "{broken")
	assert_bool(room.mobile_hud.reload_audio_settings() != OK).is_true()
	assert_bool(absf(room.mobile_hud.audio_level("master") - 1.0) < 0.001).is_true()
	assert_bool(absf(room.mobile_hud.audio_level("music") - 1.0) < 0.001).is_true()
	assert_bool(absf(room.mobile_hud.audio_level("sfx") - 1.0) < 0.001).is_true()
	_remove_settings_files(settings_path)


func test_settings_back_priority_closes_audio_pause_then_bag() -> void:
	var room: Prototype = auto_free(PROTOTYPE.instantiate()) as Prototype
	var tree := Engine.get_main_loop() as SceneTree
	_attach_to_test_viewport(room, tree)
	await tree.process_frame
	var back := InputEventKey.new()
	back.keycode = KEY_ESCAPE
	back.pressed = true

	room.mobile_hud.open_pause()
	room.mobile_hud.open_audio()
	assert_bool(tree.paused).is_true()
	assert_bool(room.mobile_hud.audio_open).is_true()
	assert_bool(room.mobile_hud.handle_back_event(back)).is_true()
	assert_bool(room.mobile_hud.audio_open).is_false()
	assert_bool(room.mobile_hud.pause_open).is_true()
	assert_bool(tree.paused).is_true()

	assert_bool(room.mobile_hud.handle_back_event(back)).is_true()
	assert_bool(room.mobile_hud.pause_open).is_false()
	assert_bool(tree.paused).is_false()

	room.mobile_hud.open_bag()
	assert_bool(room.mobile_hud.bag_open).is_true()
	assert_bool(room.mobile_hud.handle_back_event(back)).is_true()
	assert_bool(room.mobile_hud.bag_open).is_false()
	assert_bool(room.mobile_hud.pause_open).is_false()
	assert_bool(room.mobile_hud.handle_back_event(back)).is_false()


func test_settings_touch_pause_is_consumed_before_world_input() -> void:
	var room: Prototype = auto_free(PROTOTYPE.instantiate()) as Prototype
	var tree := Engine.get_main_loop() as SceneTree
	_attach_to_test_viewport(room, tree)
	await tree.process_frame
	room.player.stop_walking()
	var start := room.player.position
	var pause_point := room.mobile_hud.pause_touch_point()

	await _tap_control(room, pause_point)
	assert_bool(room.mobile_hud.pause_open).is_true()
	assert_bool(tree.paused).is_true()
	assert_bool(room.player.position.distance_to(start) < 0.01).is_true()
	assert_str(String(room.selected)).is_empty()

	if room.mobile_hud.pause_open:
		room.mobile_hud.resume_button.pressed.emit()
	await tree.process_frame
	for frame: int in range(12):
		await tree.physics_frame
	assert_bool(tree.paused).is_false()
	assert_bool(room.player.position.distance_to(start) < 0.01).is_true()
	assert_str(String(room.selected)).is_empty()


func _tap_control(room: Prototype, point: Vector2) -> void:
	var press := InputEventScreenTouch.new()
	press.position = point
	press.pressed = true
	room.get_viewport().push_input(press, true)
	await room.get_tree().process_frame
	var release := InputEventScreenTouch.new()
	release.position = point
	release.pressed = false
	room.get_viewport().push_input(release, true)
	await room.get_tree().process_frame


func _control_center(control: Control) -> Vector2:
	var rect := control.get_global_rect()
	return rect.position + rect.size * 0.5


func _drag_control(room: Prototype, start: Vector2, finish: Vector2, touch_index: int = 0) -> void:
	var press := InputEventScreenTouch.new()
	press.index = touch_index
	press.position = start
	press.pressed = true
	room.get_viewport().push_input(press, true)
	await room.get_tree().process_frame
	var drag := InputEventScreenDrag.new()
	drag.index = touch_index
	drag.position = finish
	drag.relative = finish - start
	room.get_viewport().push_input(drag, true)
	await room.get_tree().process_frame
	var release := InputEventScreenTouch.new()
	release.index = touch_index
	release.position = finish
	release.pressed = false
	room.get_viewport().push_input(release, true)
	await room.get_tree().process_frame


func _remove_settings_files(path: String) -> void:
	for candidate: String in [path, path + ".tmp", path + ".bak"]:
		if FileAccess.file_exists(candidate):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(candidate))



func test_context_touch_attack_selects_and_uses_existing_attack_window() -> void:
	var room: Prototype = auto_free(PROTOTYPE.instantiate()) as Prototype
	var tree := Engine.get_main_loop() as SceneTree
	_attach_to_test_viewport(room, tree)
	await tree.process_frame
	room.combat_target.reset_for_test()
	room.player.position = room.combat_target.position - Vector2(45.0, 0.0)
	room.player.stop_walking()

	await _tap(room, room.combat_target.position)
	await tree.process_frame
	assert_str(String(room.selected)).is_equal("CombatTarget")
	assert_bool(room.mobile_hud.context_action_button.visible).is_true()
	assert_str(room.mobile_hud.context_action_button.text).is_equal("Saldır")
	assert_bool(room.mobile_hud.context_action_button.disabled).is_false()

	await _tap_control(room, room.mobile_hud.context_action_touch_point())
	assert_bool(room.attack_active).is_true()
	await _wait_for_attack_end(room, tree)
	assert_int(room.combat_target.health.current).is_equal(3)


func test_context_touch_collect_respects_full_bag_and_collects_when_space_exists() -> void:
	var room: Prototype = auto_free(PROTOTYPE.instantiate()) as Prototype
	var tree := Engine.get_main_loop() as SceneTree
	_attach_to_test_viewport(room, tree)
	await tree.process_frame
	room.combat_target.set_ai_enabled(false)
	room.player.position = Prototype.PICKUP - Vector2(40.0, 0.0)
	room.player.stop_walking()
	var before := room.inventory.count(room.inventory.bag)

	await _tap(room, Prototype.PICKUP)
	await tree.process_frame
	assert_str(room.mobile_hud.context_action_button.text).is_equal("Topla")
	assert_bool(room.mobile_hud.context_action_button.disabled).is_false()
	await _tap_control(room, room.mobile_hud.context_action_touch_point())
	assert_bool(room.pickup_taken).is_true()
	assert_int(room.inventory.count(room.inventory.bag)).is_equal(before + 1)
	assert_int(room.quest.progress()).is_equal(1)

	var full_room: Prototype = auto_free(PROTOTYPE.instantiate()) as Prototype
	_attach_to_test_viewport(full_room, tree)
	await tree.process_frame
	full_room.combat_target.set_ai_enabled(false)
	full_room.player.position = Prototype.PICKUP - Vector2(40.0, 0.0)
	full_room.player.stop_walking()
	_add(full_room.inventory.bag, full_room.inventory.bag_remaining_capacity())
	await _tap(full_room, Prototype.PICKUP)
	await tree.process_frame
	assert_str(full_room.mobile_hud.context_action_button.text).is_equal("Topla")
	assert_bool(full_room.mobile_hud.context_action_button.disabled).is_true()
	await _tap_control(full_room, full_room.mobile_hud.context_action_touch_point())
	assert_bool(full_room.pickup_taken).is_false()
	assert_int(full_room.quest.progress()).is_equal(0)


func test_context_touch_opens_chest_only_when_selected_and_in_range() -> void:
	var room: Prototype = auto_free(PROTOTYPE.instantiate()) as Prototype
	var tree := Engine.get_main_loop() as SceneTree
	_attach_to_test_viewport(room, tree)
	await tree.process_frame
	room.combat_target.set_ai_enabled(false)
	room.player.position = Vector2(250.0, 190.0)
	room.player.stop_walking()

	await _tap(room, Prototype.CHEST)
	await tree.process_frame
	assert_str(room.mobile_hud.context_action_button.text).is_equal("Sandığı aç")
	assert_bool(room.mobile_hud.context_action_button.disabled).is_false()
	await _tap_control(room, room.mobile_hud.context_action_touch_point())
	assert_bool(room.mobile_hud.is_chest_screen()).is_true()

	var far_room: Prototype = auto_free(PROTOTYPE.instantiate()) as Prototype
	_attach_to_test_viewport(far_room, tree)
	await tree.process_frame
	far_room.combat_target.set_ai_enabled(false)
	far_room.player.position = Vector2(120.0, 194.0)
	far_room.player.stop_walking()
	await _tap(far_room, Prototype.CHEST)
	await tree.process_frame
	assert_str(far_room.mobile_hud.context_action_button.text).is_equal("Sandığı aç")
	assert_bool(far_room.mobile_hud.context_action_button.disabled).is_true()
	await _tap_control(far_room, far_room.mobile_hud.context_action_touch_point())
	assert_bool(far_room.mobile_hud.bag_open).is_false()


func test_context_control_keeps_empty_floor_touch_movement() -> void:
	var room: Prototype = auto_free(PROTOTYPE.instantiate()) as Prototype
	var tree := Engine.get_main_loop() as SceneTree
	_attach_to_test_viewport(room, tree)
	await tree.process_frame
	room.combat_target.set_ai_enabled(false)
	room.player.position = Vector2(250.0, 190.0)
	room.player.stop_walking()
	await _tap(room, Prototype.CHEST)
	assert_str(String(room.selected)).is_equal("Chest")

	var target := Vector2(160.0, 280.0)
	await _tap(room, target)
	assert_str(String(room.selected)).is_empty()
	assert_bool(room.mobile_hud.context_action_button.visible).is_false()
	for frame in range(120):
		if room.player.position.distance_to(target) < 0.75:
			break
		await tree.physics_frame
	assert_bool(room.player.position.distance_to(target) < 0.75).is_true()


func test_audio_sliders_touch_press_drag_release_updates_value_handle_save_and_does_not_leak() -> void:
	var settings_path := "user://tamu_audio_touch_test.json"
	_remove_settings_files(settings_path)
	var room: Prototype = auto_free(PROTOTYPE.instantiate()) as Prototype
	var tree := Engine.get_main_loop() as SceneTree
	_attach_to_test_viewport(room, tree)
	await tree.process_frame
	room.combat_target.set_ai_enabled(false)
	room.player.stop_walking()
	var start := room.player.position
	room.mobile_hud.audio_settings.save_file = settings_path

	await _tap_control(room, room.mobile_hud.pause_touch_point())
	assert_bool(room.mobile_hud.pause_open).is_true()
	assert_bool(tree.paused).is_true()
	await _tap_control(room, _control_center(room.mobile_hud.audio_button))
	assert_bool(room.mobile_hud.audio_open).is_true()

	var expected := {"master": 0.25, "music": 0.5, "sfx": 0.75}
	for key_value: Variant in expected.keys():
		var key := String(key_value)
		var slider := room.mobile_hud.audio_sliders[key] as HSlider
		var rect := slider.get_global_rect()
		var press := rect.position + Vector2(rect.size.x * 0.9, rect.size.y * 0.5)
		var finish := rect.position + Vector2(rect.size.x * float(expected[key]), rect.size.y * 0.5)
		await _drag_control(room, press, finish, 3)
		assert_bool(absf(slider.value - float(expected[key])) <= 0.051).is_true()
		assert_bool(absf(room.mobile_hud.audio_settings.get_level(key) - slider.value) < 0.001).is_true()
		var handle := room.mobile_hud._audio_handles[key] as TextureRect
		var holder := handle.get_parent() as Control
		var usable := maxf(1.0, holder.size.x - handle.size.x)
		assert_bool(absf(handle.position.x / usable - slider.value) < 0.02).is_true()

	assert_bool(FileAccess.file_exists(settings_path)).is_true()
	var saved_value: Variant = JSON.parse_string(FileAccess.get_file_as_string(settings_path))
	assert_bool(saved_value is Dictionary).is_true()
	var saved := saved_value as Dictionary
	var audio := saved.get("audio", {}) as Dictionary
	for key_value: Variant in expected.keys():
		var key := String(key_value)
		assert_bool(
			absf(float(audio.get(key, -1.0)) - room.mobile_hud.audio_settings.get_level(key)) < 0.001
		).is_true()

	await _tap_control(room, _control_center(room.mobile_hud.audio_button))
	assert_bool(room.mobile_hud.audio_open).is_false()
	await _tap_control(room, _control_center(room.mobile_hud.resume_button))
	assert_bool(tree.paused).is_false()
	for frame in range(12):
		await tree.physics_frame
	assert_bool(room.player.position.distance_to(start) < 0.01).is_true()
	assert_str(String(room.selected)).is_empty()
	_remove_settings_files(settings_path)


func test_minimap_tracks_player_marker_in_world_coordinates() -> void:
	var room: Prototype = auto_free(PROTOTYPE.instantiate()) as Prototype
	var tree := Engine.get_main_loop() as SceneTree
	_attach_to_test_viewport(room, tree)
	await tree.process_frame

	room.player.position = Vector2(236.0, 212.0)
	await tree.process_frame

	assert_bool(room.mini_map.camera_world_position().distance_to(room.player.global_position) < 0.01).is_true()
	assert_bool(room.mini_map.marker_screen_position().distance_to(Vector2(80.0, 45.0)) < 0.01).is_true()


func test_minimap_uses_world_coordinates_under_transformed_parent() -> void:
	var room: Prototype = auto_free(PROTOTYPE.instantiate()) as Prototype
	var tree := Engine.get_main_loop() as SceneTree
	_attach_to_test_viewport(room, tree)
	await tree.process_frame

	room.position = Vector2(73.0, 41.0)
	room.rotation = 0.17
	room.scale = Vector2(1.25, 0.8)
	room.player.position = Vector2(180.0, 210.0)
	await tree.process_frame

	assert_bool(room.player.global_position.distance_to(room.player.position) > 1.0).is_true()
	assert_bool(room.mini_map.camera_world_position().distance_to(room.player.global_position) < 0.01).is_true()


func test_minimap_hidden_viewport_stops_and_resumes_rendering() -> void:
	var room: Prototype = auto_free(PROTOTYPE.instantiate()) as Prototype
	var tree := Engine.get_main_loop() as SceneTree
	_attach_to_test_viewport(room, tree)
	await tree.process_frame

	assert_bool(room.mini_map.map_open).is_false()
	assert_bool(room.mini_map.is_rendering()).is_false()
	room.mini_map.set_map_open(true)
	await tree.process_frame
	assert_bool(room.mini_map.map_open).is_true()
	assert_bool(room.mini_map.is_rendering()).is_true()
	room.mini_map.set_map_open(false)
	assert_bool(room.mini_map.map_open).is_false()
	assert_bool(room.mini_map.is_rendering()).is_false()

	room.player.position = Vector2(320.0, 220.0)
	room.mini_map.set_map_open(true)
	await tree.process_frame
	assert_bool(room.mini_map.map_open).is_true()
	assert_bool(room.mini_map.is_rendering()).is_true()
	assert_bool(room.mini_map.camera_world_position().distance_to(room.player.global_position) < 0.01).is_true()


func test_minimap_toggle_touch_is_consumed_before_world_input() -> void:
	var room: Prototype = auto_free(PROTOTYPE.instantiate()) as Prototype
	var tree := Engine.get_main_loop() as SceneTree
	_attach_to_test_viewport(room, tree)
	await tree.process_frame
	room.player.stop_walking()
	var start := room.player.position
	var toggle_point := room.mini_map.toggle_touch_point()

	await _tap_control(room, toggle_point)
	for frame: int in range(8):
		await tree.physics_frame

	assert_bool(room.mini_map.map_open).is_true()
	assert_bool(room.player.position.distance_to(start) < 0.01).is_true()
	assert_str(String(room.selected)).is_empty()



func _wait_for_craft(room: Prototype, tree: SceneTree) -> void:
	for frame: int in range(180):
		if not room.crafting.is_active():
			return
		await tree.process_frame
	assert_bool(room.crafting.is_active()).is_false()


func test_crafting_book_touch_opens_selects_and_crafts_verified_recipes_into_placement() -> void:
	var room: Prototype = auto_free(PROTOTYPE.instantiate()) as Prototype
	var tree := Engine.get_main_loop() as SceneTree
	_attach_to_test_viewport(room, tree)
	await tree.process_frame
	room.combat_target.set_ai_enabled(false)

	await _tap_control(room, room.mobile_hud.craft_touch_point())
	assert_bool(room.crafting_book.is_open()).is_true()
	assert_str(room.crafting_book.current_page).is_equal("library")

	var plank_button := room.crafting_book.schema_button(&"core:planks_from_log")
	assert_bool(plank_button != null).is_true()
	await _tap_control(room, _control_center(plank_button))
	assert_str(room.crafting_book.current_page).is_equal("recipe")
	assert_str(String(room.crafting_book.active_recipe)).is_equal("core:planks_from_log")

	var wood_before := room.inventory.count_item(
		room.inventory.bag, TamuInventoryBridge.WOOD_LOG_STABLE_ID
	)
	await _tap_control(room, room.crafting_book.craft_touch_point())
	assert_bool(room.crafting.is_active()).is_true()
	await _wait_for_craft(room, tree)
	assert_int(room.inventory.count_item(
		room.inventory.bag, TamuInventoryBridge.WOOD_LOG_STABLE_ID
	)).is_equal(wood_before - 1)
	assert_int(room.inventory.count_item(
		room.inventory.bag, TamuInventoryBridge.WOOD_PLANK_STABLE_ID
	)).is_equal(4)

	await _tap_control(room, room.crafting_book.back_touch_point())
	var bench_button := room.crafting_book.schema_button(&"core:bench_from_planks")
	assert_bool(bench_button != null).is_true()
	await _tap_control(room, _control_center(bench_button))
	await _tap_control(room, room.crafting_book.craft_touch_point())
	await _wait_for_craft(room, tree)
	await tree.process_frame
	assert_bool(room.placement_active).is_true()
	assert_str(room.placement_status).is_equal("valid")
	assert_int(room.inventory.count_item(
		room.inventory.bag, TamuInventoryBridge.WORKBENCH_STABLE_ID
	)).is_equal(1)
	assert_bool(room.crafting_book.is_open()).is_false()


func test_failed_crafting_keeps_rubonnek_inventory_unchanged_when_output_is_full() -> void:
	var room: Prototype = auto_free(PROTOTYPE.instantiate()) as Prototype
	var tree := Engine.get_main_loop() as SceneTree
	_attach_to_test_viewport(room, tree)
	await tree.process_frame

	var wood := room.inventory.count_item(
		room.inventory.bag, TamuInventoryBridge.WOOD_LOG_STABLE_ID
	)
	assert_int(room.inventory.remove_item_from_bag_atomic(
		TamuInventoryBridge.WOOD_LOG_STABLE_ID, wood
	)).is_equal(wood)
	assert_int(room.inventory.add_item_to_bag_atomic(
		TamuInventoryBridge.WOOD_PLANK_STABLE_ID, 8
	)).is_equal(8)
	for index: int in range(3):
		assert_int(room.inventory.add_item_to_bag_atomic(
			TamuInventoryBridge.WORKBENCH_STABLE_ID, 1
		)).is_equal(1)

	var before := JSON.stringify(room.inventory.snapshot_all())
	var result := room.crafting.begin("full-output", &"core:bench_from_planks", [])
	assert_bool(bool(result.get("ok", false))).is_false()
	assert_str(str(result.get("status", ""))).is_equal("inventory_full")
	assert_str(JSON.stringify(room.inventory.snapshot_all())).is_equal(before)


func test_placement_preview_rotation_and_cancel_preserve_item() -> void:
	var room: Prototype = auto_free(PROTOTYPE.instantiate()) as Prototype
	var tree := Engine.get_main_loop() as SceneTree
	_attach_to_test_viewport(room, tree)
	await tree.process_frame

	assert_int(room.inventory.add_item_to_bag_atomic(
		TamuInventoryBridge.WORKBENCH_STABLE_ID, 1
	)).is_equal(1)
	var before := room.inventory.count_item(
		room.inventory.bag, TamuInventoryBridge.WORKBENCH_STABLE_ID
	)
	var preview := room.start_placement(TamuInventoryBridge.WORKBENCH_STABLE_ID)
	assert_bool(bool(preview.get("ok", false))).is_true()
	assert_bool(room.placement_active).is_true()
	await _tap_control(room, room.crafting_book.placement_rotate_touch_point())
	assert_int(room.placement_rotation).is_equal(1)
	assert_bool(room.placement_active).is_true()
	await _tap_control(room, room.crafting_book.placement_cancel_touch_point())
	assert_bool(room.placement_active).is_false()
	assert_int(room.inventory.count_item(
		room.inventory.bag, TamuInventoryBridge.WORKBENCH_STABLE_ID
	)).is_equal(before)


func test_invalid_placement_touch_does_not_consume_item_or_move_player() -> void:
	var room: Prototype = auto_free(PROTOTYPE.instantiate()) as Prototype
	var tree := Engine.get_main_loop() as SceneTree
	_attach_to_test_viewport(room, tree)
	await tree.process_frame

	assert_int(room.inventory.add_item_to_bag_atomic(
		TamuInventoryBridge.WORKBENCH_STABLE_ID, 1
	)).is_equal(1)
	room.start_placement(TamuInventoryBridge.WORKBENCH_STABLE_ID)
	var before_item := room.inventory.count_item(
		room.inventory.bag, TamuInventoryBridge.WORKBENCH_STABLE_ID
	)
	var before_pos := room.player.position
	await _tap(room, Vector2(40.0, 194.0))
	assert_bool(room.placement_active).is_true()
	assert_str(room.placement_status).is_equal("invalid_surface")
	assert_int(room.inventory.count_item(
		room.inventory.bag, TamuInventoryBridge.WORKBENCH_STABLE_ID
	)).is_equal(before_item)
	assert_bool(room.player.position.distance_to(before_pos) < 0.01).is_true()


func test_successful_placement_consumes_once_and_restores_floor_movement() -> void:
	var room: Prototype = auto_free(PROTOTYPE.instantiate()) as Prototype
	var tree := Engine.get_main_loop() as SceneTree
	_attach_to_test_viewport(room, tree)
	await tree.process_frame
	room.combat_target.set_ai_enabled(false)

	assert_int(room.inventory.add_item_to_bag_atomic(
		TamuInventoryBridge.WORKBENCH_STABLE_ID, 1
	)).is_equal(1)
	room.start_placement(TamuInventoryBridge.WORKBENCH_STABLE_ID)
	var before_pos := room.player.position
	await _tap(room, Vector2(150.0, 260.0))
	assert_bool(room.placement_active).is_false()
	assert_int(room.placed_structures.size()).is_equal(1)
	assert_int(room.inventory.count_item(
		room.inventory.bag, TamuInventoryBridge.WORKBENCH_STABLE_ID
	)).is_equal(0)
	assert_bool(room.player.position.distance_to(before_pos) < 0.01).is_true()

	var floor_target := Vector2(90.0, 110.0)
	await _tap(room, floor_target)
	for frame: int in range(180):
		if room.player.position.distance_to(floor_target) < 0.75:
			break
		await tree.physics_frame
	assert_bool(room.player.position.distance_to(floor_target) < 0.75).is_true()
