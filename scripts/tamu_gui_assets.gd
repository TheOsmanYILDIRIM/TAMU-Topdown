extends RefCounted
class_name TamuGuiAssets

const HudFramesData = preload("res://assets/gui/data/hud_frames_data.gd")
const HudIconsData = preload("res://assets/gui/data/hud_icons_data.gd")
const MapFrameData = preload("res://assets/gui/data/map_frame_data.gd")
const MenuAtlasData = preload("res://assets/gui/data/menu_atlas_data.gd")
const SliderAtlasData = preload("res://assets/gui/data/slider_atlas_data.gd")
const SlotMiscData = preload("res://assets/gui/data/slot_misc_data.gd")
const WindowPanelData = preload("res://assets/gui/data/window_panel_data.gd")

const TEXT_COLOR := Color("#eadfc8")
const OUTLINE_COLOR := Color("#25170f")
const DIM_COLOR := Color(0.34, 0.29, 0.24, 0.55)

const REGIONS := {
	&"slot_normal": [&"hud_icons", Rect2(0, 0, 48, 48)],
	&"slot_selected": [&"hud_icons", Rect2(50, 0, 48, 48)],
	&"bag_icon": [&"hud_icons", Rect2(100, 0, 48, 48)],
	&"pause_icon": [&"hud_icons", Rect2(150, 0, 32, 32)],
	&"map_icon": [&"hud_icons", Rect2(184, 0, 36, 34)],
	&"icon_health": [&"hud_icons", Rect2(0, 52, 24, 22)],
	&"icon_hunger": [&"hud_icons", Rect2(26, 52, 20, 24)],
	&"icon_thirst": [&"hud_icons", Rect2(48, 52, 20, 24)],
	&"icon_daynight": [&"hud_icons", Rect2(70, 52, 32, 23)],
	&"player_marker": [&"hud_icons", Rect2(104, 52, 32, 32)],
	&"north_indicator": [&"hud_icons", Rect2(138, 48, 40, 64)],
	&"survival_panel": [&"hud_frames", Rect2(0, 0, 256, 48)],
	&"square_button": [&"hud_frames", Rect2(0, 50, 48, 48)],
	&"square_button_active": [&"hud_frames", Rect2(50, 50, 48, 48)],
	&"bar_health": [&"hud_frames", Rect2(100, 50, 52, 32)],
	&"bar_hunger": [&"hud_frames", Rect2(154, 50, 52, 32)],
	&"bar_thirst": [&"hud_frames", Rect2(100, 84, 52, 32)],
	&"bar_inactive": [&"hud_frames", Rect2(154, 84, 52, 32)],
	&"window_panel": [&"window_panel", Rect2(0, 0, 256, 144)],
	&"title_plaque": [&"menu_atlas", Rect2(0, 0, 112, 36)],
	&"wide_button": [&"menu_atlas", Rect2(116, 0, 192, 38)],
	&"wide_button_active": [&"menu_atlas", Rect2(116, 40, 192, 38)],
	&"section_plaque": [&"menu_atlas", Rect2(0, 40, 120, 30)],
	&"map_frame": [&"map_frame", Rect2(0, 0, 256, 150)],
	&"slider_track": [&"slider_atlas", Rect2(0, 0, 192, 30)],
	&"slider_handle": [&"slider_atlas", Rect2(188, 32, 20, 32)],
	&"h_divider": [&"slider_atlas", Rect2(0, 66, 192, 6)],
	&"v_divider": [&"slider_atlas", Rect2(196, 0, 8, 128)],
	&"inventory_slot": [&"slot_misc", Rect2(0, 0, 48, 48)],
	&"close_icon": [&"slot_misc", Rect2(50, 0, 28, 28)],
	&"quantity_badge": [&"slot_misc", Rect2(80, 0, 52, 28)],
}

const NINE_MARGINS := {
	&"survival_panel": Vector4(12, 12, 12, 12),
	&"square_button": Vector4(10, 10, 10, 10),
	&"square_button_active": Vector4(10, 10, 10, 10),
	&"window_panel": Vector4(14, 14, 14, 14),
	&"inventory_slot": Vector4(10, 10, 10, 10),
	&"slider_track": Vector4(9, 9, 9, 9),
	&"title_plaque": Vector4(12, 12, 12, 12),
	&"wide_button": Vector4(12, 12, 12, 12),
	&"wide_button_active": Vector4(12, 12, 12, 12),
	&"map_frame": Vector4(12, 12, 12, 12),
	&"section_plaque": Vector4(10, 10, 10, 10),
	&"bar_health": Vector4(8, 8, 8, 8),
	&"bar_hunger": Vector4(8, 8, 8, 8),
	&"bar_thirst": Vector4(8, 8, 8, 8),
	&"bar_inactive": Vector4(8, 8, 8, 8),
	&"quantity_badge": Vector4(7, 7, 7, 7),
}

static var _sheet_cache: Dictionary = {}

static func _sheet_data(name: StringName) -> String:
	match name:
		&"hud_frames":
			return HudFramesData.DATA
		&"hud_icons":
			return HudIconsData.DATA
		&"map_frame":
			return MapFrameData.DATA
		&"menu_atlas":
			return MenuAtlasData.DATA
		&"slider_atlas":
			return SliderAtlasData.DATA
		&"slot_misc":
			return SlotMiscData.DATA
		&"window_panel":
			return WindowPanelData.DATA
		_:
			push_error("Unknown TAMU GUI sheet: %s" % name)
			return ""

static func _sheet(name: StringName) -> Texture2D:
	if _sheet_cache.has(name):
		return _sheet_cache[name] as Texture2D
	var raw := Marshalls.base64_to_raw(_sheet_data(name))
	var image := Image.new()
	var error := image.load_png_from_buffer(raw)
	assert(error == OK, "Could not decode TAMU GUI sheet %s: %s" % [name, error_string(error)])
	var result := ImageTexture.create_from_image(image)
	_sheet_cache[name] = result
	return result

static func texture(name: StringName) -> AtlasTexture:
	assert(REGIONS.has(name), "Unknown TAMU GUI region: %s" % name)
	var entry: Array = REGIONS[name]
	var sheet_name: StringName = entry[0]
	var region: Rect2 = entry[1]
	var result := AtlasTexture.new()
	result.atlas = _sheet(sheet_name)
	result.region = region
	result.filter_clip = true
	return result

static func nine_patch(name: StringName) -> NinePatchRect:
	var result := NinePatchRect.new()
	result.texture = texture(name)
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if NINE_MARGINS.has(name):
		var margin: Vector4 = NINE_MARGINS[name]
		result.patch_margin_left = int(margin.x)
		result.patch_margin_top = int(margin.y)
		result.patch_margin_right = int(margin.z)
		result.patch_margin_bottom = int(margin.w)
	return result

static func stylebox(name: StringName, content_margin: float = 8.0) -> StyleBoxTexture:
	var result := StyleBoxTexture.new()
	result.texture = texture(name)
	if NINE_MARGINS.has(name):
		var margin: Vector4 = NINE_MARGINS[name]
		result.set_texture_margin(SIDE_LEFT, margin.x)
		result.set_texture_margin(SIDE_TOP, margin.y)
		result.set_texture_margin(SIDE_RIGHT, margin.z)
		result.set_texture_margin(SIDE_BOTTOM, margin.w)
	for side: int in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		result.set_content_margin(side, content_margin)
	return result

static func apply_text(label: Label, size: int = 14, color: Color = TEXT_COLOR) -> void:
	label.add_theme_font_size_override(&"font_size", size)
	label.add_theme_color_override(&"font_color", color)
	label.add_theme_color_override(&"font_outline_color", OUTLINE_COLOR)
	label.add_theme_constant_override(&"outline_size", 2)

static func apply_text_button(button: Button, active: bool = false, size: int = 15) -> void:
	var normal_name: StringName = &"wide_button_active" if active else &"wide_button"
	for state: StringName in [&"normal", &"hover", &"focus"]:
		button.add_theme_stylebox_override(state, stylebox(normal_name, 10.0))
	button.add_theme_stylebox_override(&"pressed", stylebox(&"wide_button_active", 10.0))
	for color_name: StringName in [&"font_color", &"font_hover_color", &"font_pressed_color"]:
		button.add_theme_color_override(color_name, TEXT_COLOR)
	button.add_theme_color_override(&"font_outline_color", OUTLINE_COLOR)
	button.add_theme_constant_override(&"outline_size", 2)
	button.add_theme_font_size_override(&"font_size", size)
	button.focus_mode = Control.FOCUS_NONE

static func apply_slider(slider: HSlider) -> void:
	slider.add_theme_stylebox_override(&"slider", stylebox(&"slider_track", 0.0))
	slider.add_theme_icon_override(&"grabber", texture(&"slider_handle"))
	slider.add_theme_icon_override(&"grabber_highlight", texture(&"slider_handle"))
	slider.add_theme_icon_override(&"grabber_disabled", texture(&"slider_handle"))
