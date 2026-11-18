extends RefCounted
class_name TamuGuiAssets

const ATLAS: Texture2D = preload("res://assets/gui/tamu_gui_atlas.png")
const TEXT_COLOR := Color("#eadfc8")
const OUTLINE_COLOR := Color("#25170f")
const DIM_COLOR := Color(0.34, 0.29, 0.24, 0.55)

const REGIONS := {
	&"slot_normal": Rect2(2, 2, 48, 48),
	&"slot_selected": Rect2(52, 2, 48, 48),
	&"bag_icon": Rect2(102, 2, 48, 48),
	&"pause_icon": Rect2(152, 2, 32, 32),
	&"map_icon": Rect2(186, 2, 36, 34),
	&"icon_health": Rect2(224, 2, 24, 22),
	&"icon_hunger": Rect2(250, 2, 20, 24),
	&"icon_thirst": Rect2(272, 2, 20, 24),
	&"icon_daynight": Rect2(294, 2, 32, 23),
	&"survival_panel": Rect2(2, 52, 256, 48),
	&"square_button": Rect2(260, 52, 48, 48),
	&"square_button_active": Rect2(310, 52, 48, 48),
	&"window_panel": Rect2(2, 102, 256, 144),
	&"close_icon": Rect2(260, 102, 28, 28),
	&"inventory_slot": Rect2(290, 102, 48, 48),
	&"slider_track": Rect2(2, 248, 192, 30),
	&"slider_handle": Rect2(196, 248, 20, 32),
	&"h_divider": Rect2(218, 248, 192, 6),
	&"title_plaque": Rect2(2, 282, 112, 36),
	&"wide_button": Rect2(116, 282, 192, 38),
	&"map_frame": Rect2(2, 322, 256, 150),
	&"wide_button_active": Rect2(260, 322, 192, 38),
	&"section_plaque": Rect2(2, 474, 120, 30),
	&"north_indicator": Rect2(124, 474, 40, 64),
	&"player_marker": Rect2(166, 474, 32, 32),
	&"bar_health": Rect2(200, 474, 52, 32),
	&"bar_hunger": Rect2(254, 474, 52, 32),
	&"bar_thirst": Rect2(308, 474, 52, 32),
	&"bar_inactive": Rect2(362, 474, 52, 32),
	&"v_divider": Rect2(416, 474, 8, 128),
	&"quantity_badge": Rect2(426, 474, 52, 28),
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

static func texture(name: StringName) -> AtlasTexture:
	assert(REGIONS.has(name), "Unknown TAMU GUI atlas region: %s" % name)
	var result := AtlasTexture.new()
	result.atlas = ATLAS
	result.region = REGIONS[name] as Rect2
	result.filter_clip = true
	return result

static func nine_patch(name: StringName) -> NinePatchRect:
	var result := NinePatchRect.new()
	result.texture = texture(name)
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if NINE_MARGINS.has(name):
		var m := NINE_MARGINS[name] as Vector4
		result.patch_margin_left = int(m.x)
		result.patch_margin_top = int(m.y)
		result.patch_margin_right = int(m.z)
		result.patch_margin_bottom = int(m.w)
	return result

static func stylebox(name: StringName, content_margin: float = 8.0) -> StyleBoxTexture:
	var result := StyleBoxTexture.new()
	result.texture = texture(name)
	if NINE_MARGINS.has(name):
		var m := NINE_MARGINS[name] as Vector4
		result.set_texture_margin(SIDE_LEFT, m.x)
		result.set_texture_margin(SIDE_TOP, m.y)
		result.set_texture_margin(SIDE_RIGHT, m.z)
		result.set_texture_margin(SIDE_BOTTOM, m.w)
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
