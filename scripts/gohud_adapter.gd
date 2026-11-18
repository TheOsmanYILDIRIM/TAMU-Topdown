extends Control
class_name TamuGohudAdapter

signal bag_to_chest_requested
signal chest_to_bag_requested

const AudioSettings = preload("res://addons/settings_menus/audio_settings.gd")
const GuiAssets = preload("res://scripts/tamu_gui_assets.gd")
const HOTBAR_SLOTS := 4
const DEFAULT_INVENTORY_VISIBLE_SLOTS := 21
const DEFAULT_CHEST_VISIBLE_SLOTS := 15
const SLOT_SIZE := 48
const SLOT_GAP := 4
const SURVIVAL_SEGMENTS := 5

@export_range(1, 64) var inventory_visible_slots := DEFAULT_INVENTORY_VISIBLE_SLOTS
@export_range(1, 64) var chest_visible_slots := DEFAULT_CHEST_VISIBLE_SLOTS

var inventory: TamuInventoryBridge
var chest_reachable := false
var bag_open := false
var pause_open := false
var audio_open := false

var hotbar_frame: Control
var hotbar: GoSlotGrid
var bag_toggle: TextureButton
var bag_panel: Control
var bag_grid: GoSlotGrid
var chest_grid: GoSlotGrid
var bag_total: Label
var chest_total: Label
var bag_to_chest_button: Button
var chest_to_bag_button: Button

var pause_button: TextureButton
var pause_overlay: ColorRect
var pause_panel: Control
var audio_panel: Control
var resume_button: Button
var audio_button: Button
var audio_back_button: Button
var audio_sliders: Dictionary = {}
var audio_settings: TamuAudioSettings
var _syncing_audio_controls := false

var survival_panel: Control
var day_label: Label
var _health_segments: Array[TextureRect] = []
var _hunger_segments: Array[TextureRect] = []
var _thirst_segments: Array[TextureRect] = []
var _survival_health: Health
var _survival_stats: SurvivalStats
var _survival_clock: DayNightClock

var _bag_overlay: ColorRect
var _storage_title: Label
var _storage_title_plate: NinePatchRect
var _storage_close_button: TextureButton
var _section_title_plate: NinePatchRect
var _storage_chest_mode := false
var _hotbar_divider: TextureRect
var _pause_close_button: TextureButton
var _audio_divider: TextureRect
var _safe_area_override := Rect2()
var _safe_area_override_enabled := false
var _back_override_active := false
var _previous_quit_on_go_back := true

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	audio_settings = AudioSettings.new()
	audio_settings.load_and_apply()
	_build_survival_hud()
	_build_hotbar()
	_build_storage_menu()
	_build_settings_menu()
	get_viewport().size_changed.connect(_layout)
	_layout()

func _process(_delta: float) -> void:
	_sync_survival_controls()

func _exit_tree() -> void:
	var tree := get_tree()
	if pause_open and tree != null:
		tree.paused = false
	_restore_back_behavior()

func _texture_rect(name: StringName) -> TextureRect:
	var r := TextureRect.new()
	r.texture = GuiAssets.texture(name)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return r

func _close_button(callable: Callable) -> TextureButton:
	var b := TextureButton.new()
	b.texture_normal = GuiAssets.texture(&"close_icon")
	b.texture_pressed = b.texture_normal
	b.texture_hover = b.texture_normal
	b.ignore_texture_size = true
	b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	b.pressed.connect(callable)
	return b

func _square_icon_button(icon_name: StringName, tooltip: String) -> TextureButton:
	var b := TextureButton.new()
	b.texture_normal = GuiAssets.texture(&"square_button")
	b.texture_pressed = GuiAssets.texture(&"square_button_active")
	b.texture_hover = b.texture_normal
	b.ignore_texture_size = true
	b.stretch_mode = TextureButton.STRETCH_SCALE
	b.custom_minimum_size = Vector2(42.0, 42.0)
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	b.tooltip_text = tooltip
	b.accessibility_name = tooltip
	var icon := _texture_rect(icon_name)
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 8.0
	icon.offset_top = 8.0
	icon.offset_right = -8.0
	icon.offset_bottom = -8.0
	b.add_child(icon)
	return b

func _build_survival_hud() -> void:
	survival_panel = Control.new()
	survival_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(survival_panel)
	var art := GuiAssets.nine_patch(&"survival_panel")
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	survival_panel.add_child(art)
	var x := 9.0
	x = _add_survival_need(x, &"icon_health", &"bar_health", _health_segments)
	x = _add_survival_need(x, &"icon_hunger", &"bar_hunger", _hunger_segments)
	x = _add_survival_need(x, &"icon_thirst", &"bar_thirst", _thirst_segments)
	var day_icon := _texture_rect(&"icon_daynight")
	day_icon.position = Vector2(x + 2.0, 8.0)
	day_icon.size = Vector2(29.0, 22.0)
	survival_panel.add_child(day_icon)
	day_label = Label.new()
	day_label.text = "Day 1"
	day_label.position = Vector2(x + 30.0, 6.0)
	day_label.size = Vector2(54.0, 26.0)
	day_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	GuiAssets.apply_text(day_label, 11)
	survival_panel.add_child(day_label)

func _add_survival_need(x: float, icon_name: StringName, fill_name: StringName, row: Array[TextureRect]) -> float:
	var icon := _texture_rect(icon_name)
	icon.position = Vector2(x, 8.0)
	icon.size = Vector2(22.0, 22.0)
	survival_panel.add_child(icon)
	var sx := x + 23.0
	for index: int in range(SURVIVAL_SEGMENTS):
		var piece := _texture_rect(fill_name)
		piece.position = Vector2(sx + float(index) * 9.0, 14.0)
		piece.size = Vector2(8.0, 10.0)
		survival_panel.add_child(piece)
		row.append(piece)
	return sx + float(SURVIVAL_SEGMENTS) * 9.0 + 7.0

func bind_survival(health: Health, stats: SurvivalStats, clock: DayNightClock) -> void:
	_survival_health = health
	_survival_stats = stats
	_survival_clock = clock
	_sync_survival_controls()

func _sync_survival_controls() -> void:
	if _survival_health == null or _survival_stats == null or _survival_clock == null:
		return
	_update_segment_row(_health_segments, _survival_health.percent(), &"bar_health")
	_update_segment_row(_hunger_segments, _survival_stats.hunger / maxf(1.0, _survival_stats.max_value), &"bar_hunger")
	_update_segment_row(_thirst_segments, _survival_stats.thirst / maxf(1.0, _survival_stats.max_value), &"bar_thirst")
	day_label.text = "Day %d" % _survival_clock.day

func _update_segment_row(row: Array[TextureRect], ratio: float, fill_name: StringName) -> void:
	var filled := clampi(ceili(clampf(ratio, 0.0, 1.0) * float(SURVIVAL_SEGMENTS)), 0, SURVIVAL_SEGMENTS)
	for index: int in range(row.size()):
		row[index].texture = GuiAssets.texture(fill_name if index < filled else &"bar_inactive")

func _build_hotbar() -> void:
	hotbar_frame = Control.new()
	hotbar_frame.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(hotbar_frame)
	hotbar = GoSlotGrid.new()
	hotbar.slot_count = HOTBAR_SLOTS
	hotbar.cell_size = SLOT_SIZE
	hotbar.keyboard_focus = false
	hotbar.selected = 0
	hotbar_frame.add_child(hotbar)
	_hotbar_divider = _texture_rect(&"v_divider")
	add_child(_hotbar_divider)
	bag_toggle = TextureButton.new()
	bag_toggle.texture_normal = GuiAssets.texture(&"bag_icon")
	bag_toggle.texture_pressed = bag_toggle.texture_normal
	bag_toggle.texture_hover = bag_toggle.texture_normal
	bag_toggle.ignore_texture_size = true
	bag_toggle.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	bag_toggle.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
	bag_toggle.focus_mode = Control.FOCUS_NONE
	bag_toggle.mouse_filter = Control.MOUSE_FILTER_STOP
	bag_toggle.tooltip_text = "Inventory"
	bag_toggle.pressed.connect(toggle_bag)
	add_child(bag_toggle)

func _build_storage_menu() -> void:
	_bag_overlay = ColorRect.new()
	_bag_overlay.color = Color(0.025, 0.02, 0.015, 0.64)
	_bag_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_bag_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bag_overlay.z_index = 30
	add_child(_bag_overlay)
	bag_panel = Control.new()
	bag_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	bag_panel.z_index = 31
	_bag_overlay.add_child(bag_panel)
	var art := GuiAssets.nine_patch(&"window_panel")
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bag_panel.add_child(art)
	_storage_title_plate = GuiAssets.nine_patch(&"title_plaque")
	bag_panel.add_child(_storage_title_plate)
	_storage_title = Label.new()
	_storage_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_storage_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	GuiAssets.apply_text(_storage_title, 15)
	_storage_title_plate.add_child(_storage_title)
	_storage_close_button = _close_button(close_bag)
	bag_panel.add_child(_storage_close_button)
	_section_title_plate = GuiAssets.nine_patch(&"section_plaque")
	bag_panel.add_child(_section_title_plate)
	var section_title := Label.new()
	section_title.text = "Inventory"
	section_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	section_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	GuiAssets.apply_text(section_title, 11)
	section_title.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_section_title_plate.add_child(section_title)
	bag_grid = GoSlotGrid.new()
	bag_grid.slot_count = inventory_visible_slots
	bag_grid.cell_size = SLOT_SIZE
	bag_grid.slot_pressed.connect(_on_bag_slot_pressed)
	bag_panel.add_child(bag_grid)
	chest_grid = GoSlotGrid.new()
	chest_grid.slot_count = chest_visible_slots
	chest_grid.cell_size = SLOT_SIZE
	chest_grid.slot_pressed.connect(_on_chest_slot_pressed)
	bag_panel.add_child(chest_grid)
	bag_total = Label.new()
	bag_total.visible = false
	bag_panel.add_child(bag_total)
	chest_total = Label.new()
	chest_total.visible = false
	bag_panel.add_child(chest_total)
	bag_to_chest_button = Button.new()
	bag_to_chest_button.visible = false
	bag_to_chest_button.pressed.connect(func() -> void: bag_to_chest_requested.emit())
	bag_panel.add_child(bag_to_chest_button)
	chest_to_bag_button = Button.new()
	chest_to_bag_button.visible = false
	chest_to_bag_button.pressed.connect(func() -> void: chest_to_bag_requested.emit())
	bag_panel.add_child(chest_to_bag_button)
	_bag_overlay.visible = false

func configure_visible_slots(inventory_slots: int, chest_slots: int) -> void:
	inventory_visible_slots = maxi(1, inventory_slots)
	chest_visible_slots = maxi(1, chest_slots)
	if bag_grid != null:
		bag_grid.slot_count = chest_visible_slots if _storage_chest_mode else inventory_visible_slots
	if chest_grid != null:
		chest_grid.slot_count = chest_visible_slots
	_layout_storage_panel()
	if inventory != null:
		sync_inventory(inventory, chest_reachable)

func sync_inventory(value: TamuInventoryBridge, selected_chest_reachable: bool) -> void:
	inventory = value
	chest_reachable = selected_chest_reachable
	if inventory == null:
		return
	if bag_open and _storage_chest_mode and not chest_reachable:
		_set_storage_mode(false)
	_draw_storage(hotbar, inventory.bag)
	_draw_storage(bag_grid, inventory.bag)
	_draw_storage(chest_grid, inventory.chest)
	var bc := inventory.count(inventory.bag)
	var cc := inventory.count(inventory.chest)
	bag_total.text = str(bc)
	chest_total.text = str(cc)
	bag_to_chest_button.disabled = not chest_reachable or bc <= 0
	chest_to_bag_button.disabled = not chest_reachable or cc <= 0

func _draw_storage(grid: GoSlotGrid, storage: InventoryManager) -> void:
	if grid == null:
		return
	for index: int in range(grid.slot_count):
		if index >= storage.size():
			grid.set_cell(index, {})
			continue
		var amount := storage.get_slot_item_amount(index)
		if amount <= 0:
			grid.set_cell(index, {})
		else:
			# The current catalog has no approved wood icon. Do not fabricate one.
			grid.set_cell(index, {"caption": "Wood", "quantity": amount, "tooltip": "Wood log ×%d" % amount})

func _on_bag_slot_pressed(index: int) -> void:
	if _storage_chest_mode and chest_reachable and inventory != null and index < inventory.bag.size() and inventory.bag.get_slot_item_amount(index) > 0:
		bag_to_chest_requested.emit()

func _on_chest_slot_pressed(index: int) -> void:
	if _storage_chest_mode and chest_reachable and inventory != null and index < inventory.chest.size() and inventory.chest.get_slot_item_amount(index) > 0:
		chest_to_bag_requested.emit()

func toggle_bag() -> void:
	if bag_open:
		close_bag()
	else:
		open_bag()

func open_bag() -> void:
	if bag_open or pause_open:
		return
	bag_open = true
	_set_storage_mode(chest_reachable)
	_bag_overlay.visible = true
	_update_back_override()
	_layout()

func close_bag() -> void:
	if not bag_open:
		return
	bag_open = false
	_bag_overlay.visible = false
	_update_back_override()

func is_chest_screen() -> bool:
	return bag_open and _storage_chest_mode

func _set_storage_mode(chest_mode: bool) -> void:
	_storage_chest_mode = chest_mode
	_storage_title.text = "Chest" if chest_mode else "Inventory"
	_section_title_plate.visible = chest_mode
	chest_grid.visible = chest_mode
	bag_grid.slot_count = chest_visible_slots if chest_mode else inventory_visible_slots
	chest_grid.slot_count = chest_visible_slots
	_layout_storage_panel()
	if inventory != null:
		_draw_storage(bag_grid, inventory.bag)
		_draw_storage(chest_grid, inventory.chest)

func _build_settings_menu() -> void:
	pause_button = _square_icon_button(&"pause_icon", "Pause")
	pause_button.pressed.connect(open_pause)
	add_child(pause_button)
	pause_overlay = ColorRect.new()
	pause_overlay.color = Color(0.025, 0.02, 0.015, 0.64)
	pause_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	pause_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_overlay.z_index = 40
	add_child(pause_overlay)
	pause_panel = Control.new()
	pause_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	pause_overlay.add_child(pause_panel)
	var art := GuiAssets.nine_patch(&"window_panel")
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_panel.add_child(art)
	var title_plate := GuiAssets.nine_patch(&"title_plaque")
	title_plate.position = Vector2(72.0, -10.0)
	title_plate.size = Vector2(136.0, 38.0)
	pause_panel.add_child(title_plate)
	var title := Label.new()
	title.text = "Paused"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	GuiAssets.apply_text(title, 15)
	title.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title_plate.add_child(title)
	_pause_close_button = _close_button(resume_game)
	pause_panel.add_child(_pause_close_button)
	resume_button = _menu_button("Resume")
	resume_button.position = Vector2(40.0, 38.0)
	resume_button.size = Vector2(200.0, 34.0)
	resume_button.pressed.connect(resume_game)
	pause_panel.add_child(resume_button)
	audio_button = _menu_button("Audio")
	audio_button.position = Vector2(40.0, 76.0)
	audio_button.size = Vector2(200.0, 34.0)
	audio_button.pressed.connect(open_audio)
	pause_panel.add_child(audio_button)
	_audio_divider = _texture_rect(&"h_divider")
	_audio_divider.position = Vector2(38.0, 113.0)
	_audio_divider.size = Vector2(204.0, 6.0)
	pause_panel.add_child(_audio_divider)
	audio_panel = Control.new()
	audio_panel.position = Vector2(28.0, 121.0)
	audio_panel.size = Vector2(224.0, 94.0)
	pause_panel.add_child(audio_panel)
	_add_audio_slider(0.0, "Master Volume", "master")
	_add_audio_slider(31.0, "Music", "music")
	_add_audio_slider(62.0, "SFX", "sfx")
	audio_back_button = Button.new()
	audio_back_button.visible = false
	audio_back_button.pressed.connect(close_audio)
	pause_panel.add_child(audio_back_button)
	pause_overlay.visible = false
	audio_panel.visible = false

func _menu_button(text_value: String) -> Button:
	var b := Button.new()
	b.text = text_value
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	GuiAssets.apply_text_button(b, false, 14)
	return b

func _add_audio_slider(y: float, text_value: String, bus_key: String) -> void:
	var label := Label.new()
	label.text = text_value
	label.position = Vector2(0.0, y)
	label.size = Vector2(86.0, 28.0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	GuiAssets.apply_text(label, 10)
	audio_panel.add_child(label)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.position = Vector2(86.0, y + 1.0)
	slider.size = Vector2(138.0, 27.0)
	slider.mouse_filter = Control.MOUSE_FILTER_STOP
	GuiAssets.apply_slider(slider)
	slider.value_changed.connect(func(v: float) -> void:
		if not _syncing_audio_controls and audio_settings != null:
			audio_settings.set_level(bus_key, v, true)
	)
	audio_panel.add_child(slider)
	audio_sliders[bus_key] = slider

func open_pause() -> void:
	if pause_open:
		return
	if bag_open:
		close_bag()
	pause_open = true
	audio_open = false
	pause_overlay.visible = true
	audio_panel.visible = false
	GuiAssets.apply_text_button(audio_button, false, 14)
	_sync_audio_controls()
	_layout()
	var tree := get_tree()
	if tree != null:
		tree.paused = true
	_update_back_override()

func resume_game() -> void:
	if not pause_open:
		return
	audio_open = false
	pause_open = false
	pause_overlay.visible = false
	audio_panel.visible = false
	var tree := get_tree()
	if tree != null:
		tree.paused = false
	_update_back_override()

func open_audio() -> void:
	if not pause_open:
		return
	if audio_open:
		close_audio()
		return
	audio_open = true
	audio_panel.visible = true
	GuiAssets.apply_text_button(audio_button, true, 14)
	_sync_audio_controls()
	_layout()

func close_audio() -> void:
	if not audio_open:
		return
	audio_open = false
	audio_panel.visible = false
	GuiAssets.apply_text_button(audio_button, false, 14)
	_layout()

func set_audio_level(bus_key: String, value: float, persist: bool = true) -> Error:
	if audio_settings == null:
		return ERR_UNCONFIGURED
	var err := audio_settings.set_level(bus_key, value, persist)
	_sync_audio_controls()
	return err

func audio_level(bus_key: String) -> float:
	return audio_settings.get_level(bus_key) if audio_settings != null else 1.0

func set_audio_settings_file(path: String) -> void:
	if audio_settings == null:
		audio_settings = AudioSettings.new(path)
	else:
		audio_settings.save_file = path

func reload_audio_settings() -> Error:
	if audio_settings == null:
		return ERR_UNCONFIGURED
	var err := audio_settings.load_and_apply()
	_sync_audio_controls()
	return err

func reset_audio_defaults(persist: bool = false) -> Error:
	if audio_settings == null:
		return ERR_UNCONFIGURED
	var err := audio_settings.reset_to_defaults(persist)
	_sync_audio_controls()
	return err

func audio_settings_file() -> String:
	return audio_settings.save_file if audio_settings != null else ""

func _sync_audio_controls() -> void:
	if audio_settings == null or audio_sliders.is_empty():
		return
	_syncing_audio_controls = true
	for key_value: Variant in audio_sliders.keys():
		var key := String(key_value)
		(audio_sliders[key] as HSlider).set_value_no_signal(audio_settings.get_level(key))
	_syncing_audio_controls = false

func _update_back_override() -> void:
	var tree := get_tree()
	if tree == null:
		return
	var needs := bag_open or pause_open
	if needs and not _back_override_active:
		var current: Variant = tree.get("quit_on_go_back")
		if current is bool:
			_previous_quit_on_go_back = current
			tree.set("quit_on_go_back", false)
			_back_override_active = true
	elif not needs:
		_restore_back_behavior()

func _restore_back_behavior() -> void:
	if not _back_override_active:
		return
	var tree := get_tree()
	if tree != null:
		tree.set("quit_on_go_back", _previous_quit_on_go_back)
	_back_override_active = false

func _unhandled_input(event: InputEvent) -> void:
	if handle_back_event(event):
		get_viewport().set_input_as_handled()

func handle_back_event(event: InputEvent) -> bool:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return false
	if event.keycode != KEY_ESCAPE and event.keycode != KEY_BACK:
		return false
	if audio_open:
		close_audio()
		return true
	if pause_open:
		resume_game()
		return true
	if bag_open:
		close_bag()
		return true
	return false

func _notification(what: int) -> void:
	if what != NOTIFICATION_WM_GO_BACK_REQUEST:
		return
	if audio_open:
		close_audio()
	elif pause_open:
		resume_game()
	elif bag_open:
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
	return hotbar_frame.position + hotbar.position + first.position + first.size * 0.5 if first != null else hotbar_frame.position + hotbar_frame.size * 0.5

func pause_touch_point() -> Vector2:
	return pause_button.position + pause_button.size * 0.5

func pause_overlay_touch_point() -> Vector2:
	return Vector2(16.0, 180.0)

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
	var area := Rect2(Vector2.ZERO, get_viewport_rect().size)
	var window := get_window()
	if window != null and get_viewport() == window:
		var safe := GoSafeArea.usable_rect(window)
		if safe.size.x > 1.0 and safe.size.y > 1.0:
			return safe
	return area

func _layout() -> void:
	if not is_instance_valid(hotbar_frame):
		return
	var area := _effective_safe_rect()
	if area.size.x <= 1.0 or area.size.y <= 1.0:
		return
	survival_panel.position = area.position + Vector2(8.0, 8.0)
	survival_panel.size = Vector2(minf(252.0, area.size.x * 0.55), 40.0)
	var button_size := Vector2(42.0, 42.0)
	pause_button.position = Vector2(area.end.x - 2.0 * button_size.x - 14.0, area.position.y + 8.0)
	pause_button.size = button_size
	var hotbar_width := float(HOTBAR_SLOTS * SLOT_SIZE + (HOTBAR_SLOTS - 1) * SLOT_GAP)
	var total_width := hotbar_width + 7.0 + 2.0 + 7.0 + SLOT_SIZE
	var row_x := area.position.x + maxf(0.0, (area.size.x - total_width) * 0.5)
	var row_y := area.end.y - float(SLOT_SIZE) - 7.0
	hotbar_frame.position = Vector2(row_x, row_y)
	hotbar_frame.size = Vector2(hotbar_width, SLOT_SIZE)
	hotbar.position = Vector2.ZERO
	hotbar.size = hotbar_frame.size
	_hotbar_divider.position = Vector2(row_x + hotbar_width + 7.0, row_y + 5.0)
	_hotbar_divider.size = Vector2(2.0, SLOT_SIZE - 10.0)
	bag_toggle.position = Vector2(_hotbar_divider.position.x + 9.0, row_y)
	bag_toggle.size = Vector2(SLOT_SIZE, SLOT_SIZE)
	_layout_storage_panel()
	pause_panel.size = Vector2(280.0, 224.0 if audio_open else 126.0)
	pause_panel.position = area.position + (area.size - pause_panel.size) * 0.5
	_pause_close_button.position = Vector2(pause_panel.size.x - 35.0, 7.0)
	_pause_close_button.size = Vector2(30.0, 30.0)

func _layout_storage_panel() -> void:
	if not is_instance_valid(bag_panel):
		return
	var area := _effective_safe_rect()
	if area.size.x <= 1.0 or area.size.y <= 1.0:
		return
	var grid_width: float
	var grid_height: float
	var panel_width: float
	var panel_height: float
	if _storage_chest_mode:
		var columns := mini(5, maxi(1, floori((area.size.x - 62.0 + float(SLOT_GAP) * 2.0) / (2.0 * float(SLOT_SIZE + SLOT_GAP)))))
		var rows := ceili(float(chest_visible_slots) / float(columns))
		grid_width = float(columns * SLOT_SIZE + (columns - 1) * SLOT_GAP)
		grid_height = float(rows * SLOT_SIZE + (rows - 1) * SLOT_GAP)
		panel_width = minf(area.size.x - 18.0, grid_width * 2.0 + 62.0)
		panel_height = minf(area.size.y, grid_height + 66.0)
	else:
		var columns := mini(7, maxi(1, floori((area.size.x - 40.0 + float(SLOT_GAP)) / float(SLOT_SIZE + SLOT_GAP))))
		var rows := ceili(float(inventory_visible_slots) / float(columns))
		grid_width = float(columns * SLOT_SIZE + (columns - 1) * SLOT_GAP)
		grid_height = float(rows * SLOT_SIZE + (rows - 1) * SLOT_GAP)
		panel_width = minf(area.size.x, grid_width + 40.0)
		panel_height = minf(area.size.y, grid_height + 66.0)
	bag_panel.size = Vector2(panel_width, panel_height)
	bag_panel.position = area.position + (area.size - bag_panel.size) * 0.5
	_storage_title_plate.position = Vector2((panel_width - 122.0) * 0.5, -10.0)
	_storage_title_plate.size = Vector2(122.0, 38.0)
	_storage_title.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_storage_close_button.position = Vector2(panel_width - 35.0, 7.0)
	_storage_close_button.size = Vector2(30.0, 30.0)
	if _storage_chest_mode:
		bag_grid.position = Vector2(18.0, 50.0)
		bag_grid.size = Vector2(grid_width, minf(grid_height, panel_height - 58.0))
		chest_grid.position = Vector2(panel_width - grid_width - 18.0, 50.0)
		chest_grid.size = Vector2(grid_width, minf(grid_height, panel_height - 58.0))
		_section_title_plate.position = Vector2(18.0 + (grid_width - 82.0) * 0.5, 25.0)
		_section_title_plate.size = Vector2(82.0, 24.0)
	else:
		bag_grid.position = Vector2((panel_width - grid_width) * 0.5, 48.0)
		bag_grid.size = Vector2(grid_width, minf(grid_height, panel_height - 56.0))
		chest_grid.position = Vector2.ZERO
		chest_grid.size = Vector2.ZERO
