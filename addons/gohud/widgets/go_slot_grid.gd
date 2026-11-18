## TAMU runtime adaptation of gohud GoSlotGrid v1.3.0; display-only.
@tool
class_name GoSlotGrid
extends HFlowContainer

signal slot_pressed(index: int)

@export_range(0, 64) var slot_count := 4:
	set(value):
		slot_count = maxi(0, value)
		_rebuild()
@export_range(16, 96) var cell_size := 48:
	set(value):
		cell_size = value
		for cell: GoSlot in _cells:
			cell.visual_size = cell_size
@export var draggable := false
@export var keyboard_focus := false:
	set(value):
		keyboard_focus = value
		for cell: GoSlot in _cells:
			cell.keyboard_focus = value

var selected := -1:
	set(value):
		selected = value if value >= 0 and value < slot_count else -1
		for index: int in range(_cells.size()):
			_cells[index].selected = index == selected
var _cells: Array[GoSlot] = []
var _data: Array[Dictionary] = []

func _init() -> void:
	name = "SlotGrid"
	mouse_filter = Control.MOUSE_FILTER_PASS
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	alignment = FlowContainer.ALIGNMENT_CENTER
	_data.resize(slot_count)

func _ready() -> void:
	add_theme_constant_override(&"h_separation", 4)
	add_theme_constant_override(&"v_separation", 4)
	_rebuild()

func slot(index: int) -> GoSlot:
	return _cells[index] if index >= 0 and index < _cells.size() else null

func cell(index: int) -> Dictionary:
	return _data[index] if index >= 0 and index < _data.size() else {}

func set_cell(index: int, data: Dictionary) -> void:
	if index < 0 or index >= slot_count:
		return
	_data[index] = data
	if index < _cells.size():
		_paint(index)

func set_cells(list: Array) -> void:
	for index: int in range(slot_count):
		var value: Variant = list[index] if index < list.size() else null
		set_cell(index, value if value is Dictionary else {})

func _rebuild() -> void:
	_data.resize(slot_count)
	if not is_inside_tree():
		return
	while _cells.size() > slot_count:
		var last := _cells.pop_back()
		remove_child(last)
		last.queue_free()
	while _cells.size() < slot_count:
		var index := _cells.size()
		var made := GoSlot.new()
		made.name = "Cell%d" % index
		made.visual_size = cell_size
		made.keyboard_focus = keyboard_focus
		made.mouse_filter = Control.MOUSE_FILTER_STOP
		made.pressed.connect(_on_pressed.bind(index))
		_cells.append(made)
		add_child(made)
		_paint(index)
	if selected >= slot_count:
		selected = -1

func _paint(index: int) -> void:
	var made := _cells[index]
	var data := _data[index]
	made.quantity = int(data["quantity"]) if data.has("quantity") else GoSlot.NONE
	made.caption = str(data.get("caption", ""))
	made.item_texture = data.get("icon", null) as Texture2D
	made.disabled = bool(data.get("disabled", false))
	made.tooltip_text = str(data.get("tooltip", ""))
	made.selected = index == selected
	made.refresh()

func _on_pressed(index: int) -> void:
	slot_pressed.emit(index)
