extends Node

const OUTPUT_ROOT := "res://gui-artifacts"
const ACTUAL_ROOT := OUTPUT_ROOT + "/actual"
const COMPARE_ROOT := OUTPUT_ROOT + "/comparison"
const REFERENCE_ROOT := "res://assets/gui/source/references/"
const TARGET_SIZE := Vector2i(1536, 864)

var room: Node

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	room = get_parent()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ACTUAL_ROOT))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(COMPARE_ROOT))
	_capture_sequence.call_deferred()

func _capture_sequence() -> void:
	for _frame: int in range(6):
		await get_tree().process_frame
	print("GUI_CAPTURE gameplay")
	if not await _capture("gameplay", "126112.png"):
		return

	room.mobile_hud.open_bag()
	for _frame: int in range(3):
		await get_tree().process_frame
	print("GUI_CAPTURE inventory")
	if not await _capture("inventory", "126120.png"):
		return
	room.mobile_hud.close_bag()

	room.player.position = Vector2(250.0, 190.0)
	room.select_at(Vector2(288.0, 190.0))
	room.mobile_hud.open_bag()
	for _frame: int in range(3):
		await get_tree().process_frame
	print("GUI_CAPTURE chest")
	if not await _capture("chest", "126122.png"):
		return
	room.mobile_hud.close_bag()

	room.mobile_hud.open_pause()
	room.mobile_hud.open_audio()
	for _frame: int in range(3):
		await get_tree().process_frame
	print("GUI_CAPTURE pause-audio")
	if not await _capture("pause-audio", "126124.png"):
		return
	room.mobile_hud.resume_game()

	room.mini_map.set_map_open(true)
	for _frame: int in range(6):
		await get_tree().process_frame
	print("GUI_CAPTURE map")
	if not await _capture("map", "126126.png"):
		return
	room.mini_map.set_map_open(false)

	room.open_crafting_book()
	for _frame: int in range(4):
		await get_tree().process_frame
	print("GUI_CAPTURE crafting-book")
	if not await _capture_actual("crafting-book"):
		return
	room.crafting_book.close_book()

	if room.inventory.add_item_to_bag_atomic(TamuInventoryBridge.WORKBENCH_STABLE_ID, 1) != 1:
		_fail(9, "Could not seed workbench for placement capture")
		return
	room.player.position = Vector2(120.0, 194.0)
	room.start_placement(TamuInventoryBridge.WORKBENCH_STABLE_ID)
	for _frame: int in range(4):
		await get_tree().process_frame
	print("GUI_CAPTURE placement-preview")
	if not await _capture_actual("placement-preview"):
		return
	room.cancel_placement()

	print("GUI_CAPTURE_OK 7 actual + 5 comparisons at 1536x864")
	get_tree().quit(0)

func _capture_actual(name: String) -> bool:
	RenderingServer.force_draw(false)
	await get_tree().process_frame
	RenderingServer.force_draw(false)
	var actual := get_viewport().get_texture().get_image()
	if actual == null or actual.is_empty():
		return _fail(2, "Empty rendered image for %s" % name)
	if actual.get_size() != TARGET_SIZE:
		return _fail(3, "Unexpected GUI capture size for %s: %s" % [name, actual.get_size()])
	var actual_path := "%s/%s.png" % [ACTUAL_ROOT, name]
	var err := actual.save_png(actual_path)
	if err != OK:
		return _fail(4, "Could not save actual capture %s: %s" % [name, error_string(err)])
	return true

func _capture(name: String, reference_name: String) -> bool:
	if not await _capture_actual(name):
		return false
	var actual := _load_reference(ACTUAL_ROOT + "/" + name + ".png")
	if actual == null or actual.is_empty():
		return _fail(4, "Could not reload actual capture %s" % name)
	var reference := _load_reference(REFERENCE_ROOT + reference_name)
	if reference == null or reference.is_empty():
		return _fail(5, "Could not load GUI reference %s" % reference_name)
	if reference.get_width() != TARGET_SIZE.x or reference.get_height() < TARGET_SIZE.y:
		return _fail(6, "Unexpected reference dimensions for %s: %s" % [reference_name, reference.get_size()])
	var reference_frame := reference.get_region(Rect2i(Vector2i.ZERO, TARGET_SIZE))
	if reference_frame.get_format() != Image.FORMAT_RGBA8:
		reference_frame.convert(Image.FORMAT_RGBA8)
	var actual_rgba := actual.duplicate()
	if actual_rgba.get_format() != Image.FORMAT_RGBA8:
		actual_rgba.convert(Image.FORMAT_RGBA8)
	var comparison := Image.create(TARGET_SIZE.x * 2, TARGET_SIZE.y, false, Image.FORMAT_RGBA8)
	comparison.fill(Color("#11100e"))
	comparison.blit_rect(reference_frame, Rect2i(Vector2i.ZERO, TARGET_SIZE), Vector2i.ZERO)
	comparison.blit_rect(actual_rgba, Rect2i(Vector2i.ZERO, TARGET_SIZE), Vector2i(TARGET_SIZE.x, 0))
	var compare_path := "%s/%s-reference-left_actual-right.png" % [COMPARE_ROOT, name]
	var err := comparison.save_png(compare_path)
	if err != OK:
		return _fail(7, "Could not save comparison %s: %s" % [name, error_string(err)])
	return true

func _load_reference(path: String) -> Image:
	var data := FileAccess.get_file_as_bytes(path)
	if data.size() < 4:
		return null
	var image := Image.new()
	var err := ERR_FILE_UNRECOGNIZED
	if data[0] == 0xff and data[1] == 0xd8 and data[2] == 0xff:
		err = image.load_jpg_from_buffer(data)
	elif data[0] == 0x89 and data[1] == 0x50 and data[2] == 0x4e and data[3] == 0x47:
		err = image.load_png_from_buffer(data)
	if err != OK:
		push_error("Reference decode failed for %s: %s" % [path, error_string(err)])
		return null
	return image

func _fail(code: int, message: String) -> bool:
	push_error(message)
	get_tree().quit(code)
	return false
