extends SceneTree

const PROTOTYPE: PackedScene = preload("res://scenes/prototype.tscn")
const Prototype = preload("res://scripts/prototype.gd")
const OUTPUT_ROOT := "res://gui-artifacts"
const ACTUAL_ROOT := OUTPUT_ROOT + "/actual"
const COMPARE_ROOT := OUTPUT_ROOT + "/comparison"
const REFERENCE_ROOT := "res://assets/gui/source/references/"
const TARGET_SIZE := Vector2i(1536, 864)

var room: Node

func _initialize() -> void:
	root.size = TARGET_SIZE
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ACTUAL_ROOT))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(COMPARE_ROOT))
	room = PROTOTYPE.instantiate()
	root.add_child.call_deferred(room)
	_capture_sequence.call_deferred()

func _capture_sequence() -> void:
	for frame: int in range(6):
		await process_frame
	print("GUI_CAPTURE gameplay")
	await _capture("gameplay", "126112.png")

	room.mobile_hud.open_bag()
	for frame: int in range(3):
		await process_frame
	print("GUI_CAPTURE inventory")
	await _capture("inventory", "126120.png")
	room.mobile_hud.close_bag()

	room.player.position = Vector2(250.0, 190.0)
	room.select_at(Prototype.CHEST)
	room.mobile_hud.open_bag()
	for frame: int in range(3):
		await process_frame
	print("GUI_CAPTURE chest")
	await _capture("chest", "126122.png")
	room.mobile_hud.close_bag()

	room.mobile_hud.open_pause()
	room.mobile_hud.open_audio()
	for frame: int in range(3):
		await process_frame
	print("GUI_CAPTURE pause-audio")
	await _capture("pause-audio", "126124.png")
	room.mobile_hud.resume_game()

	room.mini_map.set_map_open(true)
	for frame: int in range(6):
		await process_frame
	print("GUI_CAPTURE map")
	await _capture("map", "126126.png")
	room.mini_map.set_map_open(false)

	print("GUI_CAPTURE_OK 5 actual + 5 comparisons at 1536x864")
	quit(0)

func _capture(name: String, reference_name: String) -> void:
	RenderingServer.force_draw(false)
	await process_frame
	RenderingServer.force_draw(false)
	var actual := root.get_texture().get_image()
	if actual.get_size() != TARGET_SIZE:
		push_error("Unexpected GUI capture size for %s: %s" % [name, actual.get_size()])
		quit(2)
		return
	var actual_path := "%s/%s.png" % [ACTUAL_ROOT, name]
	var err := actual.save_png(actual_path)
	if err != OK:
		push_error("Could not save actual capture %s: %s" % [name, error_string(err)])
		quit(3)
		return

	var reference := _load_reference(REFERENCE_ROOT + reference_name)
	if reference == null or reference.is_empty():
		push_error("Could not load GUI reference %s" % reference_name)
		quit(4)
		return
	if reference.get_width() != TARGET_SIZE.x or reference.get_height() < TARGET_SIZE.y:
		push_error("Unexpected reference dimensions for %s: %s" % [reference_name, reference.get_size()])
		quit(5)
		return
	var reference_frame := reference.get_region(Rect2i(Vector2i.ZERO, TARGET_SIZE))
	var comparison := Image.create(TARGET_SIZE.x * 2, TARGET_SIZE.y, false, Image.FORMAT_RGBA8)
	comparison.fill(Color("#11100e"))
	comparison.blit_rect(reference_frame, Rect2i(Vector2i.ZERO, TARGET_SIZE), Vector2i.ZERO)
	comparison.blit_rect(actual, Rect2i(Vector2i.ZERO, TARGET_SIZE), Vector2i(TARGET_SIZE.x, 0))
	var compare_path := "%s/%s-reference-left_actual-right.png" % [COMPARE_ROOT, name]
	err = comparison.save_png(compare_path)
	if err != OK:
		push_error("Could not save comparison %s: %s" % [name, error_string(err)])
		quit(6)


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
