extends Control
class_name TamuGohudAdapter

signal bag_to_chest_requested
signal chest_to_bag_requested

const PANEL_BG := Color("#101915e8")
const PANEL_BORDER := Color("#65756d")
const ACCENT := Color("#d2a65a")

var inventory: TamuInventoryBridge
var chest_reachable := false
var bag_open := false

var hotbar_frame: PanelContainer
var hotbar: GoSlotGrid
var bag_toggle: Button
var bag_panel: Panel
var bag_grid: GoSlotGrid
var chest_grid: GoSlotGrid
var bag_total: Label
var chest_total: Label
var bag_to_chest_button: Button
var chest_to_bag_button: Button

var _safe_area_override := Rect2()
var _safe_area_override_enabled := false
var _back_override_active := false
var _previous_quit_on_go_back := true


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	_build()
	get_viewport().size_changed.connect(_layout)
	_layout()


func _exit_tree() -> void:
	_restore_back_behavior()


func _build() -> void:
	hotbar_frame = PanelContainer.new()
	hotbar_frame.name = "HotbarFrame"
	hotbar_frame.mouse_filter = Control.MOUSE_FILTER_STOP
	hotbar_frame.add_theme_stylebox_override(&"panel", _panel_style())
	add_child(hotbar_frame)

	hotbar = GoSlotGrid.new()
	hotbar.name = "Hotbar"
	hotbar.slot_count = 4
	hotbar.cell_size = 48
	hotbar.keyboard_focus = false
	hotbar.mouse_filter = Control.MOUSE_FILTER_PASS
	hotbar_frame.add_child(hotbar)

	bag_toggle = Button.new()
	bag_toggle.name = "BagToggle"
	bag_toggle.text = "Bag"
	bag_toggle.custom_minimum_size = Vector2(64.0, 48.0)
	bag_toggle.focus_mode = Control.FOCUS_NONE
	bag_toggle.mouse_filter = Control.MOUSE_FILTER_STOP
	bag_toggle.pressed.connect(toggle_bag)
	add_child(bag_toggle)

	bag_panel = Panel.new()
	bag_panel.name = "BagPanel"
	bag_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	bag_panel.clip_contents = true
	bag_panel.add_theme_stylebox_override(&"panel", _panel_style())
	add_child(bag_panel)

	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 8.0
	scroll.offset_top = 8.0
	scroll.offset_right = -8.0
	scroll.offset_bottom = -8.0
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	bag_panel.add_child(scroll)

	var content := VBoxContainer.new()
	content.name = "Content"
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override(&"separation", 6)
	scroll.add_child(content)

	var title := Label.new()
	title.text = "Bag"
	title.add_theme_font_size_override(&"font_size", 16)
	content.add_child(title)

	bag_total = Label.new()
	bag_total.name = "BagTotal"
	content.add_child(bag_total)

	bag_grid = GoSlotGrid.new()
	bag_grid.name = "BagGrid"
	bag_grid.slot_count = 4
	bag_grid.cell_size = 48
	bag_grid.keyboard_focus = false
	bag_grid.mouse_filter = Control.MOUSE_FILTER_PASS
	content.add_child(bag_grid)

	chest_total = Label.new()
	chest_total.name = "ChestTotal"
	content.add_child(chest_total)

	chest_grid = GoSlotGrid.new()
	chest_grid.name = "ChestGrid"
	chest_grid.slot_count = 4
	chest_grid.cell_size = 48
	chest_grid.keyboard_focus = false
	chest_grid.mouse_filter = Control.MOUSE_FILTER_PASS
	content.add_child(chest_grid)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override(&"separation", 6)
	content.add_child(actions)

	bag_to_chest_button = Button.new()
	bag_to_chest_button.name = "BagToChest"
	bag_to_chest_button.text = "→ Chest"
	bag_to_chest_button.custom_minimum_size = Vector2(96.0, 44.0)
	bag_to_chest_button.focus_mode = Control.FOCUS_NONE
	bag_to_chest_button.mouse_filter = Control.MOUSE_FILTER_STOP
	bag_to_chest_button.pressed.connect(func() -> void: bag_to_chest_requested.emit())
	actions.add_child(bag_to_chest_button)

	chest_to_bag_button = Button.new()
	chest_to_bag_button.name = "ChestToBag"
	chest_to_bag_button.text = "← Bag"
	chest_to_bag_button.custom_minimum_size = Vector2(96.0, 44.0)
	chest_to_bag_button.focus_mode = Control.FOCUS_NONE
	chest_to_bag_button.mouse_filter = Control.MOUSE_FILTER_STOP
	chest_to_bag_button.pressed.connect(func() -> void: chest_to_bag_requested.emit())
	actions.add_child(chest_to_bag_button)

	bag_panel.visible = false


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_BG
	style.border_color = PANEL_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	return style


func sync_inventory(value: TamuInventoryBridge, selected_chest_reachable: bool) -> void:
	inventory = value
	chest_reachable = selected_chest_reachable
	if inventory == null:
		return

	# Rubonnek InventoryManager is the only data owner. These dictionaries are display-only snapshots.
	_draw_storage(hotbar, inventory.bag)
	_draw_storage(bag_grid, inventory.bag)
	_draw_storage(chest_grid, inventory.chest)

	var bag_count := inventory.count(inventory.bag)
	var chest_count := inventory.count(inventory.chest)
	bag_total.text = "Wood ×%d" % bag_count
	chest_total.text = "Chest ×%d" % chest_count if chest_reachable else "Chest — select in range"
	bag_to_chest_button.disabled = not chest_reachable or bag_count <= 0
	chest_to_bag_button.disabled = not chest_reachable or chest_count <= 0


func _draw_storage(grid: GoSlotGrid, storage: InventoryManager) -> void:
	for index: int in range(grid.slot_count):
		if index >= storage.size():
			grid.set_cell(index, {})
			continue
		var amount := storage.get_slot_item_amount(index)
		if amount <= 0:
			grid.set_cell(index, {})
			continue
		grid.set_cell(index, {
			"caption": "Wood",
			"quantity": amount,
			"accent": ACCENT,
			"tooltip": "Wood log ×%d" % amount,
		})


func toggle_bag() -> void:
	if bag_open:
		close_bag()
	else:
		open_bag()


func open_bag() -> void:
	if bag_open:
		return
	bag_open = true
	bag_panel.visible = true
	var tree := get_tree()
	if tree != null:
		var current: Variant = tree.get("quit_on_go_back")
		if current is bool:
			_previous_quit_on_go_back = current
			tree.set("quit_on_go_back", false)
			_back_override_active = true
	_layout()


func close_bag() -> void:
	if not bag_open:
		return
	bag_open = false
	bag_panel.visible = false
	_restore_back_behavior()


func _restore_back_behavior() -> void:
	if not _back_override_active:
		return
	var tree := get_tree()
	if tree != null:
		tree.set("quit_on_go_back", _previous_quit_on_go_back)
	_back_override_active = false


func handle_back_event(event: InputEvent) -> bool:
	if not bag_open:
		return false
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_BACK:
			close_bag()
			return true
	return false


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and bag_open:
		close_bag()


func set_safe_area_override(rect: Rect2) -> void:
	_safe_area_override = rect
	_safe_area_override_enabled = rect.size.x > 0.0 and rect.size.y > 0.0
	_layout()


func clear_safe_area_override() -> void:
	_safe_area_override_enabled = false
	_layout()


func effective_safe_rect() -> Rect2:
	return _effective_safe_rect()


func hotbar_row_rect() -> Rect2:
	return hotbar_frame.get_rect().merge(bag_toggle.get_rect())


func bag_panel_rect() -> Rect2:
	return bag_panel.get_rect()


func hotbar_touch_point() -> Vector2:
	var first := hotbar.slot(0)
	if first == null:
		return hotbar_frame.position + hotbar_frame.size * 0.5
	return hotbar_frame.position + hotbar.position + first.position + first.size * 0.5


func displayed_hotbar_total() -> int:
	return _displayed_total(hotbar)


func displayed_bag_total() -> int:
	return _displayed_total(bag_grid)


func displayed_chest_total() -> int:
	return _displayed_total(chest_grid)


func _displayed_total(grid: GoSlotGrid) -> int:
	var total := 0
	for index: int in range(grid.slot_count):
		var data := grid.cell(index)
		if data.has("quantity"):
			total += int(data["quantity"])
	return total


func _effective_safe_rect() -> Rect2:
	if _safe_area_override_enabled:
		return _safe_area_override
	var viewport_area := Rect2(Vector2.ZERO, get_viewport_rect().size)
	var window := get_window()
	if window != null and get_viewport() == window:
		var safe := GoSafeArea.usable_rect(window)
		if safe.size.x > 1.0 and safe.size.y > 1.0:
			return safe
	return viewport_area


func _layout() -> void:
	if not is_instance_valid(hotbar_frame):
		return
	var area := _effective_safe_rect()
	if area.size.x <= 1.0 or area.size.y <= 1.0:
		return

	var toggle_width := 64.0
	var gap := 8.0
	var hotbar_min := hotbar_frame.get_combined_minimum_size()
	var hotbar_width := minf(216.0, area.size.x - toggle_width - gap)
	hotbar_width = maxf(hotbar_min.x, hotbar_width)
	var row_height := maxf(58.0, hotbar_min.y)
	var row_width := hotbar_width + gap + toggle_width
	var row_x := area.position.x + maxf(0.0, (area.size.x - row_width) * 0.5)
	var row_y := area.end.y - row_height - 8.0
	if row_y < area.position.y:
		row_y = area.position.y

	hotbar_frame.position = Vector2(row_x, row_y)
	hotbar_frame.size = Vector2(hotbar_width, row_height)
	bag_toggle.position = Vector2(row_x + hotbar_width + gap, row_y + (row_height - 48.0) * 0.5)
	bag_toggle.size = Vector2(toggle_width, 48.0)

	var panel_width := minf(300.0, maxf(240.0, area.size.x - 16.0))
	var panel_height := minf(250.0, maxf(210.0, area.size.y - row_height - 24.0))
	bag_panel.position = Vector2(
		area.position.x + (area.size.x - panel_width) * 0.5,
		maxf(area.position.y + 8.0, row_y - panel_height - 8.0)
	)
	bag_panel.size = Vector2(panel_width, panel_height)
