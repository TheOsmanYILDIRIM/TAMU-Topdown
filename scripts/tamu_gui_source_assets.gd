extends RefCounted
class_name TamuGuiSourceAssets

const COMPONENT_ROOT := "res://assets/gui/source/components/"

const REGIONS: Dictionary = {
	&"slot_normal": ["126108.png", Rect2(108, 60, 572, 586)],
	&"slot_selected": ["126108.png", Rect2(830, 60, 574, 586)],
	&"bag_icon": ["126108.png", Rect2(1612, 131, 439, 468)],
	&"pause_icon": ["126113.png", Rect2(297, 166, 434, 490)],
	&"map_icon": ["126113.png", Rect2(1092, 136, 564, 526)],
	&"health_icon": ["126114.png", Rect2(116, 181, 396, 359)],
	&"hunger_icon": ["126114.png", Rect2(677, 161, 271, 392)],
	&"thirst_icon": ["126114.png", Rect2(1136, 160, 280, 395)],
	&"day_icon": ["126114.png", Rect2(1551, 163, 521, 382)],
	&"survival_panel": ["126116.png", Rect2(65, 243, 1276, 244)],
	&"square_button": ["126116.png", Rect2(1402, 198, 325, 327)],
	&"square_button_active": ["126116.png", Rect2(1776, 200, 329, 326)],
	&"window_panel": ["126117.png", Rect2(31, 62, 1261, 691)],
	&"close_icon": ["126117.png", Rect2(1383, 310, 190, 193)],
	&"inventory_slot": ["126117.png", Rect2(1673, 292, 233, 231)],
	&"slider_track": ["126118.png", Rect2(54, 290, 940, 141)],
	&"slider_handle": ["126118.png", Rect2(1051, 264, 116, 195)],
	&"h_divider": ["126118.png", Rect2(1222, 346, 902, 24)],
	&"title_plaque": ["126127.png", Rect2(35, 299, 428, 134)],
	&"wide_button": ["126127.png", Rect2(518, 291, 693, 142)],
	&"map_frame": ["126127.png", Rect2(1253, 97, 888, 519)],
	&"wide_button_active": ["126128.png", Rect2(87, 152, 1998, 416)],
	&"section_plaque": ["126129.png", Rect2(281, 164, 1609, 399)],
	&"north_indicator": ["126130.png", Rect2(364, 130, 315, 539)],
	&"player_marker": ["126130.png", Rect2(1202, 246, 398, 395)],
	&"bar_health": ["126131.png", Rect2(271, 211, 341, 298)],
	&"bar_hunger": ["126131.png", Rect2(905, 211, 343, 298)],
	&"bar_thirst": ["126131.png", Rect2(1540, 212, 341, 299)],
	&"v_divider": ["126134.png", Rect2(420, 181, 47, 1410)],
	&"quantity_badge": ["126138.png", Rect2(428, 537, 407, 193)],
}

const PATCH_MARGINS: Dictionary = {
	&"window_panel": Vector4(10.0, 10.0, 10.0, 10.0),
	&"title_plaque": Vector4(8.0, 6.0, 8.0, 6.0),
	&"section_plaque": Vector4(8.0, 5.0, 8.0, 5.0),
	&"map_frame": Vector4(9.0, 9.0, 9.0, 9.0),
	&"quantity_badge": Vector4(5.0, 4.0, 5.0, 4.0),
	&"survival_panel": Vector4(8.0, 6.0, 8.0, 6.0),
	&"wide_button": Vector4(10.0, 6.0, 10.0, 6.0),
	&"wide_button_active": Vector4(10.0, 6.0, 10.0, 6.0),
}

const TEXT_COLOR := Color("#ead7aa")
const TEXT_MUTED := Color("#cbb78f")
const OUTLINE_COLOR := Color("#21160f")
const DIM_COLOR := Color(0.58, 0.55, 0.49, 0.82)

static var _cache: Dictionary = {}

static func source_path(name: StringName) -> String:
	if not REGIONS.has(name):
		return ""
	var entry: Array = REGIONS[name]
	return COMPONENT_ROOT + String(entry[0])

static func texture(name: StringName) -> Texture2D:
	if _cache.has(name):
		return _cache[name] as Texture2D
	if not REGIONS.has(name):
		push_error("Unknown TAMU GUI source region: %s" % name)
		return null
	var entry: Array = REGIONS[name]
	var atlas_source := load(COMPONENT_ROOT + String(entry[0])) as Texture2D
	if atlas_source == null:
		push_error("Missing approved GUI source PNG for %s" % name)
		return null
	var atlas := AtlasTexture.new()
	atlas.atlas = atlas_source
	atlas.region = entry[1] as Rect2
	atlas.filter_clip = true
	_cache[name] = atlas
	return atlas

static func nine_patch(name: StringName) -> NinePatchRect:
	var patch := NinePatchRect.new()
	patch.texture = texture(name)
	patch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var margins := PATCH_MARGINS.get(name, Vector4(16.0, 16.0, 16.0, 16.0)) as Vector4
	patch.patch_margin_left = margins.x
	patch.patch_margin_top = margins.y
	patch.patch_margin_right = margins.z
	patch.patch_margin_bottom = margins.w
	return patch

static func style_box(name: StringName) -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = texture(name)
	var margins := PATCH_MARGINS.get(name, Vector4(16.0, 16.0, 16.0, 16.0)) as Vector4
	box.texture_margin_left = margins.x
	box.texture_margin_top = margins.y
	box.texture_margin_right = margins.z
	box.texture_margin_bottom = margins.w
	box.content_margin_left = 8.0
	box.content_margin_top = 4.0
	box.content_margin_right = 8.0
	box.content_margin_bottom = 4.0
	return box

static func apply_text(label: Label, font_size: int, muted: bool = false) -> void:
	label.add_theme_font_size_override(&"font_size", font_size)
	label.add_theme_color_override(&"font_color", TEXT_MUTED if muted else TEXT_COLOR)
	label.add_theme_color_override(&"font_outline_color", OUTLINE_COLOR)
	label.add_theme_constant_override(&"outline_size", 2)
	label.add_theme_constant_override(&"shadow_offset_x", 1)
	label.add_theme_constant_override(&"shadow_offset_y", 1)
	label.add_theme_color_override(&"font_shadow_color", Color(0.04, 0.025, 0.015, 0.8))

static func apply_text_button(button: Button, active: bool, font_size: int = 13) -> void:
	var base_name: StringName = &"wide_button_active" if active else &"wide_button"
	var base := style_box(base_name)
	var hover := style_box(base_name)
	var pressed := style_box(&"wide_button_active")
	for state: StringName in [&"normal", &"hover", &"focus", &"disabled"]:
		button.add_theme_stylebox_override(state, hover if state == &"hover" else base)
	button.add_theme_stylebox_override(&"pressed", pressed)
	button.add_theme_font_size_override(&"font_size", font_size)
	button.add_theme_color_override(&"font_color", TEXT_COLOR)
	button.add_theme_color_override(&"font_hover_color", Color("#f4e4bd"))
	button.add_theme_color_override(&"font_pressed_color", Color("#f6e3a4"))
	button.add_theme_color_override(&"font_outline_color", OUTLINE_COLOR)
	button.add_theme_constant_override(&"outline_size", 2)
	button.focus_mode = Control.FOCUS_NONE

static func make_invisible_slider(slider: HSlider) -> void:
	var empty := StyleBoxEmpty.new()
	for state: StringName in [&"slider", &"grabber_area", &"grabber_area_highlight"]:
		slider.add_theme_stylebox_override(state, empty)
	slider.self_modulate = Color(1.0, 1.0, 1.0, 0.0)
