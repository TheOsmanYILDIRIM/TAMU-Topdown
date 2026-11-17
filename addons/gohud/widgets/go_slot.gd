## Narrow TAMU runtime adaptation of gohud GoSlot v1.3.0.
## Source: thruthesky/gohud@5d48e694d572625dcd3a7d22bd2a2357c6b78c32 (MIT).
## It keeps the upstream display-only quantity and 48dp touch semantics without
## importing the unrelated theme, icon, demo, joystick, blur, or menu stacks.
@tool
class_name GoSlot
extends Button

const UNKNOWN := -1
const NONE := -2
const MIN_TOUCH_SIZE := 48

@export_range(16, 128) var visual_size: int = 44:
	set(value):
		visual_size = value
		_fit_box()
		_layout_labels()

@export var accent := Color("#d2a65a"):
	set(value):
		accent = value
		refresh()

@export var quantity: int = UNKNOWN:
	set(value):
		quantity = value
		refresh()

@export var selected := false:
	set(value):
		selected = value
		refresh()

@export var keyboard_focus := false:
	set(value):
		keyboard_focus = value
		focus_mode = Control.FOCUS_ALL if value else Control.FOCUS_NONE

var caption := "":
	set(value):
		caption = value
		if is_instance_valid(_caption):
			_caption.text = caption

var touch_peers: Array[Control] = []
var _caption: Label
var _quantity: Label


func _init() -> void:
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_fit_box()


func _ready() -> void:
	_caption = Label.new()
	_caption.name = "Caption"
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_caption.autowrap_mode = TextServer.AUTOWRAP_OFF
	add_child(_caption)

	_quantity = Label.new()
	_quantity.name = "Quantity"
	_quantity.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_quantity.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_quantity.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_quantity.text_direction = Control.TEXT_DIRECTION_LTR
	add_child(_quantity)

	_layout_labels()
	refresh()


func _fit_box() -> void:
	var side := maxi(MIN_TOUCH_SIZE, visual_size)
	custom_minimum_size = Vector2(side, side)


func _layout_labels() -> void:
	if not is_instance_valid(_caption) or not is_instance_valid(_quantity):
		return
	_caption.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_caption.offset_left = 4.0
	_caption.offset_top = 4.0
	_caption.offset_right = -4.0
	_caption.offset_bottom = -15.0
	_quantity.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_quantity.offset_left = -42.0
	_quantity.offset_top = -20.0
	_quantity.offset_right = -4.0
	_quantity.offset_bottom = -2.0


func refresh() -> void:
	if not is_instance_valid(_caption) or not is_instance_valid(_quantity):
		return

	var face := StyleBoxFlat.new()
	face.bg_color = Color("#17221d") if not disabled else Color("#151a17")
	face.border_color = accent if selected else Color("#69766f")
	if disabled:
		face.border_color = Color("#3e4943")
	face.set_border_width_all(2 if selected else 1)
	face.set_corner_radius_all(8)
	add_theme_stylebox_override(&"normal", face)

	var hover := face.duplicate() as StyleBoxFlat
	hover.bg_color = Color("#203129")
	add_theme_stylebox_override(&"hover", hover)

	var pressed_face := face.duplicate() as StyleBoxFlat
	pressed_face.bg_color = Color("#101713")
	add_theme_stylebox_override(&"pressed", pressed_face)

	_caption.text = caption
	_caption.add_theme_color_override(&"font_color", Color("#eef4ef") if not disabled else Color("#7e8983"))
	_caption.add_theme_font_size_override(&"font_size", 11)

	_quantity.visible = quantity != NONE
	if _quantity.visible:
		_quantity.text = "…" if quantity == UNKNOWN else "×%d" % maxi(0, quantity)
		_quantity.add_theme_color_override(&"font_color", Color("#f6d38d") if not disabled else Color("#7e8983"))
		_quantity.add_theme_font_size_override(&"font_size", 12)

	accessibility_name = caption if quantity == NONE else "%s %s" % [caption, _quantity.text]


func touch_hit(point: Vector2) -> bool:
	var reach := maxf(0.0, (float(MIN_TOUCH_SIZE) - minf(size.x, size.y)) * 0.5)
	return Rect2(Vector2.ZERO, size).grow(reach).has_point(point)
