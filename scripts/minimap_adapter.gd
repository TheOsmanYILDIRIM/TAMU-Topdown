extends Control
class_name TamuMiniMapAdapter

const MiniMapScene = preload("res://addons/minimap/minimap.tscn")
const SourceAssets = preload("res://scripts/tamu_gui_source_assets.gd")

var map_core: TamuMiniMapCore
var toggle_button: TextureButton
var map_open := false
var _overlay: ColorRect
var _panel: Control
var _close_button: TextureButton
var _title_plate: NinePatchRect
var _map_frame: NinePatchRect
var _north_indicator: TextureRect
var _player_marker: TextureRect

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	get_viewport().size_changed.connect(_layout)
	_layout()
	set_map_open(false)

func _build() -> void:
	_overlay = ColorRect.new()
	_overlay.color = Color(0.025, 0.018, 0.012, 0.61)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.z_index = 30
	add_child(_overlay)
	_panel = Control.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.z_index = 31
	_overlay.add_child(_panel)
	_map_frame = SourceAssets.nine_patch(&"map_frame")
	_map_frame.z_index = 1
	_panel.add_child(_map_frame)
	_title_plate = SourceAssets.nine_patch(&"title_plaque")
	_title_plate.z_index = 5
	_panel.add_child(_title_plate)
	var title := Label.new()
	title.text = "Map"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	SourceAssets.apply_text(title, 14)
	title.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_title_plate.add_child(title)
	_close_button = TextureButton.new()
	_close_button.texture_normal = SourceAssets.texture(&"square_button")
	_close_button.texture_pressed = SourceAssets.texture(&"square_button_active")
	_close_button.texture_hover = _close_button.texture_normal
	_close_button.ignore_texture_size = true
	_close_button.stretch_mode = TextureButton.STRETCH_SCALE
	_close_button.focus_mode = Control.FOCUS_NONE
	_close_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_close_button.z_index = 6
	var close_icon := _icon(&"close_icon")
	close_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	close_icon.offset_left = 6.0
	close_icon.offset_top = 6.0
	close_icon.offset_right = -6.0
	close_icon.offset_bottom = -6.0
	_close_button.add_child(close_icon)
	_close_button.pressed.connect(func() -> void: set_map_open(false))
	_panel.add_child(_close_button)
	map_core = MiniMapScene.instantiate() as TamuMiniMapCore
	map_core.name = "Core"
	map_core.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map_frame.add_child(map_core)
	map_core.stretch = true
	if map_core.marker != null:
		map_core.marker.visible = false
	if map_core.border != null:
		map_core.border.visible = false
	_north_indicator = _icon(&"north_indicator")
	_north_indicator.z_index = 3
	_player_marker = _icon(&"player_marker")
	_player_marker.z_index = 3
	_map_frame.add_child(_north_indicator)
	_map_frame.add_child(_player_marker)
	toggle_button = TextureButton.new()
	toggle_button.name = "Toggle"
	toggle_button.ignore_texture_size = true
	toggle_button.stretch_mode = TextureButton.STRETCH_SCALE
	toggle_button.custom_minimum_size = Vector2(38.0, 38.0)
	toggle_button.focus_mode = Control.FOCUS_NONE
	toggle_button.mouse_filter = Control.MOUSE_FILTER_STOP
	toggle_button.tooltip_text = "Mini-map"
	toggle_button.accessibility_name = "Mini-map"
	toggle_button.z_index = 1
	var icon := _icon(&"map_icon")
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 7.0
	icon.offset_top = 7.0
	icon.offset_right = -7.0
	icon.offset_bottom = -7.0
	toggle_button.add_child(icon)
	toggle_button.pressed.connect(toggle_map)
	add_child(toggle_button)
	_overlay.visible = false

func _icon(name: StringName) -> TextureRect:
	var result := TextureRect.new()
	result.texture = SourceAssets.texture(name)
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	result.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return result

func set_target(value: Node2D) -> void:
	if map_core != null:
		map_core.set_target(value)

func toggle_map() -> void:
	set_map_open(not map_open)

func set_map_open(value: bool) -> void:
	map_open = value
	if _overlay != null:
		_overlay.visible = value
	if map_core != null:
		map_core.set_map_visible(value)
	if toggle_button != null:
		toggle_button.texture_normal = SourceAssets.texture(&"square_button_active" if value else &"square_button")
		toggle_button.texture_pressed = SourceAssets.texture(&"square_button_active")
		toggle_button.texture_hover = toggle_button.texture_normal
		toggle_button.z_index = 35 if value else 1
	_layout()

func handle_back_event(event: InputEvent) -> bool:
	if not map_open or not (event is InputEventKey and event.pressed and not event.echo):
		return false
	if event.keycode != KEY_ESCAPE and event.keycode != KEY_BACK:
		return false
	set_map_open(false)
	return true

func is_rendering() -> bool:
	return map_core != null and map_core.is_rendering()

func camera_world_position() -> Vector2:
	return map_core.camera_world_position() if map_core != null else Vector2.ZERO

func marker_screen_position() -> Vector2:
	return map_core.marker_screen_position() if map_core != null else Vector2.ZERO

func toggle_touch_point() -> Vector2:
	return toggle_button.position + toggle_button.size * 0.5 if toggle_button != null else Vector2.ZERO

func map_panel_rect() -> Rect2:
	return _panel.get_rect() if _panel != null else Rect2()

func map_content_rect() -> Rect2:
	return map_core.get_rect() if map_core != null else Rect2()

func _effective_safe_rect() -> Rect2:
	var area := Rect2(Vector2.ZERO, get_viewport_rect().size)
	var window := get_window()
	if window != null and get_viewport() == window:
		var safe := GoSafeArea.usable_rect(window)
		if safe.size.x > 1.0 and safe.size.y > 1.0:
			return safe
	return area

func _layout() -> void:
	if map_core == null or toggle_button == null or _panel == null:
		return
	var area := _effective_safe_rect()
	if area.size.x <= 1.0 or area.size.y <= 1.0:
		return
	var button_size := Vector2(38.0, 38.0)
	toggle_button.position = Vector2(area.end.x - button_size.x - 8.0, area.position.y + 8.0)
	toggle_button.size = button_size
	var panel_size := Vector2(minf(338.0, area.size.x - 18.0), minf(218.0, area.size.y - 18.0))
	_panel.size = panel_size
	_panel.position = area.position + (area.size - panel_size) * 0.5
	_title_plate.position = Vector2((panel_size.x - 128.0) * 0.5, -9.0)
	_title_plate.size = Vector2(128.0, 36.0)
	_close_button.position = Vector2(panel_size.x - 36.0, 12.0)
	_close_button.size = Vector2(30.0, 30.0)
	# Keep one dedicated map frame and place all controls above it.
	_map_frame.position = Vector2(0.0, 10.0)
	_map_frame.size = Vector2(panel_size.x, panel_size.y - 10.0)
	var content_margin := Vector2(18.0, 22.0)
	map_core.set_anchors_preset(Control.PRESET_TOP_LEFT)
	map_core.position = content_margin
	map_core.size = _map_frame.size - content_margin * 2.0
	_north_indicator.position = Vector2(_map_frame.size.x - 43.0, 21.0)
	_north_indicator.size = Vector2(25.0, 43.0)
	_player_marker.size = Vector2(24.0, 24.0)
	_player_marker.position = (_map_frame.size - _player_marker.size) * 0.5
