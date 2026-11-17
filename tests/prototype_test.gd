extends GdUnitTestSuite

const PROTOTYPE: PackedScene = preload("res://scenes/prototype.tscn")
const Prototype = preload("res://scripts/prototype.gd")
const PlayerController = preload("res://scripts/player.gd")


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
