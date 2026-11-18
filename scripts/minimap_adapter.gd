extends Control
class_name TamuMiniMapAdapter

const MiniMapScene = preload("res://addons/minimap/minimap.tscn")

var map_core: TamuMiniMapCore
var toggle_button: Button
var map_open: bool = true


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	get_viewport().size_changed.connect(_layout)
	_layout()


func _build() -> void:
	map_core = MiniMapScene.instantiate() as TamuMiniMapCore
	map_core.name = "Core"
	map_core.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(map_core)

	toggle_button = Button.new()
	toggle_button.name = "Toggle"
	toggle_button.text = "Hide Map"
	toggle_button.custom_minimum_size = Vector2(76.0, 36.0)
	toggle_button.focus_mode = Control.FOCUS_NONE
	toggle_button.mouse_filter = Control.MOUSE_FILTER_STOP
	toggle_button.pressed.connect(toggle_map)
	add_child(toggle_button)


func set_target(value: Node2D) -> void:
	if map_core != null:
		map_core.set_target(value)


func toggle_map() -> void:
	set_map_open(not map_open)


func set_map_open(value: bool) -> void:
	map_open = value
	if map_core != null:
		map_core.set_map_visible(value)
	if toggle_button != null:
		toggle_button.text = "Hide Map" if value else "Map"


func is_rendering() -> bool:
	return map_core != null and map_core.is_rendering()


func camera_world_position() -> Vector2:
	return map_core.camera_world_position() if map_core != null else Vector2.ZERO


func marker_screen_position() -> Vector2:
	return map_core.marker_screen_position() if map_core != null else Vector2.ZERO


func toggle_touch_point() -> Vector2:
	if toggle_button == null:
		return Vector2.ZERO
	return toggle_button.position + toggle_button.size * 0.5


func _effective_safe_rect() -> Rect2:
	var viewport_area := Rect2(Vector2.ZERO, get_viewport_rect().size)
	var window := get_window()
	if window != null and get_viewport() == window:
		var safe := GoSafeArea.usable_rect(window)
		if safe.size.x > 1.0 and safe.size.y > 1.0:
			return safe
	return viewport_area


func _layout() -> void:
	if map_core == null or toggle_button == null:
		return
	var area := _effective_safe_rect()
	if area.size.x <= 1.0 or area.size.y <= 1.0:
		return
	var margin := 8.0
	var toggle_size := Vector2(76.0, 36.0)
	var map_size := Vector2(160.0, 90.0)
	var x := area.position.x + margin
	var toggle_y := minf(area.end.y - toggle_size.y - margin, area.position.y + 84.0)
	toggle_button.position = Vector2(x, maxf(area.position.y + margin, toggle_y))
	toggle_button.size = toggle_size
	map_core.position = Vector2(
		x,
		minf(area.end.y - map_size.y - margin, toggle_button.position.y + toggle_size.y + 4.0)
	)
	map_core.size = map_size
