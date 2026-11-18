## TAMU styling of the narrow gohud GoSlot v1.3.0 runtime adaptation.
@tool
class_name GoSlot
extends Button

const UNKNOWN := -1
const NONE := -2
const MIN_TOUCH_SIZE := 40
const SourceAssets = preload("res://scripts/tamu_gui_source_assets.gd")

@export_range(16, 128) var visual_size: int = 40:
	set(value):
		visual_size = value
		_fit_box()
		_layout_visuals()
@export var visual_kind: StringName = &"hotbar":
	set(value):
		visual_kind = value
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
		refresh()
var item_texture: Texture2D:
	set(value):
		item_texture = value
		refresh()
var touch_peers: Array[Control] = []
var _background: TextureRect
var _item: TextureRect
var _quantity_badge: NinePatchRect
var _quantity: Label

func _init() -> void:
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	text = ""
	_fit_box()

func _ready() -> void:
	var empty := StyleBoxEmpty.new()
	for state: StringName in [&"normal", &"hover", &"pressed", &"focus", &"disabled"]:
		add_theme_stylebox_override(state, empty)
	_background = TextureRect.new()
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_background.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(_background)
	_item = TextureRect.new()
	_item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_item.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_item.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	add_child(_item)
	_quantity_badge = SourceAssets.nine_patch(&"quantity_badge")
	add_child(_quantity_badge)
	_quantity = Label.new()
	_quantity.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_quantity.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_quantity.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	SourceAssets.apply_text(_quantity, 9)
	_quantity_badge.add_child(_quantity)
	_layout_visuals()
	refresh()

func _fit_box() -> void:
	var side := maxi(MIN_TOUCH_SIZE, visual_size)
	custom_minimum_size = Vector2(side, side)

func _layout_visuals() -> void:
	if not is_instance_valid(_background):
		return
	_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_item.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_item.offset_left = 6.0
	_item.offset_top = 6.0
	_item.offset_right = -6.0
	_item.offset_bottom = -6.0
	_quantity_badge.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_quantity_badge.offset_left = -27.0
	_quantity_badge.offset_top = -16.0
	_quantity_badge.offset_right = -2.0
	_quantity_badge.offset_bottom = -2.0
	_quantity.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func refresh() -> void:
	if not is_instance_valid(_background):
		return
	if visual_kind == &"inventory":
		_background.texture = SourceAssets.texture(&"inventory_slot")
	else:
		_background.texture = SourceAssets.texture(&"slot_selected" if selected else &"slot_normal")
	_background.modulate = Color.WHITE if not disabled else SourceAssets.DIM_COLOR
	_item.texture = item_texture
	_item.modulate = Color.WHITE if not disabled else SourceAssets.DIM_COLOR
	_quantity_badge.visible = quantity != NONE
	if _quantity_badge.visible:
		_quantity.text = "…" if quantity == UNKNOWN else str(maxi(0, quantity))
		_quantity_badge.modulate = Color.WHITE if not disabled else SourceAssets.DIM_COLOR
	accessibility_name = caption if quantity == NONE else "%s %s" % [caption, _quantity.text]

func touch_hit(point: Vector2) -> bool:
	var reach := maxf(0.0, (float(MIN_TOUCH_SIZE) - minf(size.x, size.y)) * 0.5)
	return Rect2(Vector2.ZERO, size).grow(reach).has_point(point)
