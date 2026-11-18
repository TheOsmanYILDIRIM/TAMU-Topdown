extends GdUnitTestSuite

const PROTOTYPE: PackedScene = preload("res://scenes/prototype.tscn")
const Prototype = preload("res://scripts/prototype.gd")
const SourceAssets = preload("res://scripts/tamu_gui_source_assets.gd")

func test_gui_reference_slot_counts_are_display_only() -> void:
	var room: Prototype = auto_free(PROTOTYPE.instantiate()) as Prototype
	var tree := Engine.get_main_loop() as SceneTree
	_attach(room, tree)
	await tree.process_frame
	assert_int(room.inventory.bag.size()).is_equal(4)
	assert_int(room.inventory.chest.size()).is_equal(4)
	assert_int(room.mobile_hud.hotbar.slot_count).is_equal(4)
	room.mobile_hud.open_bag()
	assert_bool(room.mobile_hud.is_chest_screen()).is_false()
	assert_int(room.mobile_hud.bag_grid.slot_count).is_equal(21)
	room.mobile_hud.close_bag()
	room.player.position = Vector2(250.0, 190.0)
	room.select_at(Prototype.CHEST)
	room.mobile_hud.open_bag()
	assert_bool(room.mobile_hud.is_chest_screen()).is_true()
	assert_int(room.mobile_hud.bag_grid.slot_count).is_equal(15)
	assert_int(room.mobile_hud.chest_grid.slot_count).is_equal(15)
	assert_int(room.inventory.bag.size()).is_equal(4)
	assert_int(room.inventory.chest.size()).is_equal(4)

func test_gui_visible_slot_counts_can_change_without_inventory_migration() -> void:
	var room: Prototype = auto_free(PROTOTYPE.instantiate()) as Prototype
	var tree := Engine.get_main_loop() as SceneTree
	_attach(room, tree)
	await tree.process_frame
	var total_before := room.inventory.count(room.inventory.bag) + room.inventory.count(room.inventory.chest)
	room.mobile_hud.configure_visible_slots(14, 10)
	room.mobile_hud.open_bag()
	assert_int(room.mobile_hud.bag_grid.slot_count).is_equal(14)
	room.mobile_hud.close_bag()
	room.player.position = Vector2(250.0, 190.0)
	room.select_at(Prototype.CHEST)
	room.mobile_hud.open_bag()
	assert_int(room.mobile_hud.bag_grid.slot_count).is_equal(10)
	assert_int(room.mobile_hud.chest_grid.slot_count).is_equal(10)
	assert_int(room.inventory.bag.size()).is_equal(4)
	assert_int(room.inventory.chest.size()).is_equal(4)
	assert_int(room.inventory.count(room.inventory.bag) + room.inventory.count(room.inventory.chest)).is_equal(total_before)

func test_gui_inventory_reflows_inside_injected_safe_area() -> void:
	var room: Prototype = auto_free(PROTOTYPE.instantiate()) as Prototype
	var tree := Engine.get_main_loop() as SceneTree
	_attach(room, tree)
	await tree.process_frame
	var safe := Rect2(12.0, 8.0, 296.0, 344.0)
	room.mobile_hud.set_safe_area_override(safe)
	room.mobile_hud.open_bag()
	await tree.process_frame
	assert_bool(safe.encloses(room.mobile_hud.bag_panel_rect())).is_true()
	assert_int(room.mobile_hud.bag_grid.slot_count).is_equal(21)

func test_gui_survival_values_are_drawn_from_live_game_state() -> void:
	var room: Prototype = auto_free(PROTOTYPE.instantiate()) as Prototype
	var tree := Engine.get_main_loop() as SceneTree
	_attach(room, tree)
	await tree.process_frame
	room.player.health.current = 6
	var stats := room.get_node("SurvivalStats") as SurvivalStats
	var clock := room.get_node("DayNightClock") as DayNightClock
	stats.hunger = 40.0
	stats.thirst = 20.0
	clock.day = 7
	await tree.process_frame
	assert_str(room.mobile_hud.day_label.text).is_equal("Day 7")
	var health_filled := 0
	var expected_fill := SourceAssets.texture(&"bar_health")
	for segment: TextureRect in room.mobile_hud._health_segments:
		if segment.texture == expected_fill:
			health_filled += 1
	assert_int(health_filled).is_equal(3)

func test_gui_does_not_fabricate_missing_item_icon() -> void:
	var room: Prototype = auto_free(PROTOTYPE.instantiate()) as Prototype
	var tree := Engine.get_main_loop() as SceneTree
	_attach(room, tree)
	await tree.process_frame
	var first := room.mobile_hud.hotbar.slot(0)
	assert_bool(first.item_texture == null).is_true()
	assert_int(room.mobile_hud.displayed_hotbar_total()).is_equal(12)

func test_gui_map_screen_is_componentized_and_render_on_demand() -> void:
	var room: Prototype = auto_free(PROTOTYPE.instantiate()) as Prototype
	var tree := Engine.get_main_loop() as SceneTree
	_attach(room, tree)
	await tree.process_frame
	assert_bool(room.mini_map.map_open).is_false()
	assert_bool(room.mini_map.is_rendering()).is_false()
	room.mini_map.set_map_open(true)
	await tree.process_frame
	assert_bool(room.mini_map.map_open).is_true()
	assert_bool(room.mini_map.is_rendering()).is_true()
	assert_bool(room.mini_map.map_panel_rect().size.x > 0.0).is_true()
	room.mini_map.set_map_open(false)
	assert_bool(room.mini_map.is_rendering()).is_false()

func test_gui_legacy_debug_controls_are_not_part_of_runtime_hud() -> void:
	var room: Prototype = auto_free(PROTOTYPE.instantiate()) as Prototype
	var tree := Engine.get_main_loop() as SceneTree
	_attach(room, tree)
	await tree.process_frame
	for node_name: String in ["Status", "BagToChest", "ChestToBag", "TakePickup", "ClaimReward", "Save", "Load"]:
		assert_bool((room.get_node("HUD/" + node_name) as CanvasItem).visible).is_false()

func _attach(room: Prototype, tree: SceneTree) -> void:
	var viewport: SubViewport = auto_free(SubViewport.new()) as SubViewport
	viewport.size = Vector2i(640, 360)
	tree.root.add_child(viewport)
	viewport.add_child(room)


func test_gui_runtime_textures_use_original_component_pngs_not_reference_screens() -> void:
	var slot := SourceAssets.texture(&"slot_normal") as AtlasTexture
	assert_bool(slot != null).is_true()
	assert_bool(slot.atlas != null).is_true()
	assert_str(slot.atlas.resource_path).starts_with("res://assets/gui/source/components/")
	assert_bool(not slot.atlas.resource_path.contains("/references/")).is_true()
	assert_bool(FileAccess.file_exists("res://assets/gui/source/references/126112.png")).is_true()
