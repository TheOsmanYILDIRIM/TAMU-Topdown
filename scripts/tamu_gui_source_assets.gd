extends RefCounted
class_name TamuGuiSourceAssets

const COMPONENT_ROOT := "res://assets/gui/source/components/"

const REGIONS: Dictionary = {
	&"slot_normal": ["126108.png", Rect2(72, 28, 650, 668)],
	&"slot_selected": ["126108.png", Rect2(796, 28, 650, 668)],
	&"bag_icon": ["126108.png", Rect2(1540, 72, 580, 570)],
	&"pause_icon": ["126113.png", Rect2(238, 100, 535, 610)],
	&"map_icon": ["126113.png", Rect2(1025, 86, 700, 630)],
	&"survival_panel": ["126116.png", Rect2(28, 205, 1360, 325)],
	&"square_button": ["126116.png", Rect2(1366, 166, 395, 395)],
	&"square_button_active": ["126116.png", Rect2(1740, 166, 397, 395)],
	&"window_panel": ["126117.png", Rect2(0, 32, 1328, 750)],
	&"close_icon": ["126117.png", Rect2(1334, 266, 292, 292)],
	&"inventory_slot": ["126117.png", Rect2(1632, 250, 320, 320)],
	&"slider_track": ["126118.png", Rect2(30, 255, 995, 210)],
	&"slider_handle": ["126118.png", Rect2(1018, 230, 185, 270)],
	&"h_divider": ["126118.png", Rect2(1195, 326, 955, 70)],
	&"title_plaque": ["126127.png", Rect2(14, 268, 472, 205)],
	&"wide_button": ["126127.png", Rect2(490, 260, 748, 206)],
	&"map_frame": ["126127.png", Rect2(1220, 74, 944, 574)],
	&"wide_button_active": ["126128.png", Rect2(44, 120, 2084, 480)],
	&"section_plaque": ["126129.png", Rect2(240, 125, 1690, 480)],
	&"north_indicator": ["126130.png", Rect2(330, 96, 390, 610)],
	&"player_marker": ["126130.png", Rect2(1160, 205, 485, 475)],
	&"bar_health": ["126131.png", Rect2(230, 175, 425, 370)],
	&"bar_hunger": ["126131.png", Rect2(866, 175, 425, 370)],
	&"bar_thirst": ["126131.png", Rect2(1500, 175, 425, 370)],
	&"bar_inactive": ["126133.png", Rect2(180, 130, 955, 930)],
	&"v_divider": ["126134.png", Rect2(372, 130, 150, 1510)],
	&"quantity_badge": ["126138.png", Rect2(390, 500, 485, 270)],
}

const PATCH_MARGINS: Dictionary = {
	&"window_panel": Vector4(34.0, 34.0, 34.0, 34.0),
	&"title_plaque": Vector4(30.0, 20.0, 30.0, 20.0),
	&"section_plaque": Vector4(28.0, 18.0, 28.0, 18.0),
	&"map_frame": Vector4(28.0, 28.0, 28.0, 28.0),
	&"quantity_badge": Vector4(18.0, 14.0, 18.0, 14.0),
	&"survival_panel": Vector4(28.0, 18.0, 28.0, 18.0),
	&"wide_button": Vector4(30.0, 18.0, 30.0, 18.0),
	&"wide_button_active": Vector4(30.0, 18.0, 30.0, 18.0),
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
