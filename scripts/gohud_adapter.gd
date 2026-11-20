extends Control
class_name TamuGohudAdapter

signal bag_to_chest_requested
signal chest_to_bag_requested
signal context_action_requested
signal craft_book_requested

const AudioSettings = preload("res://addons/settings_menus/audio_settings.gd")
const SourceAssets = preload("res://scripts/tamu_gui_source_assets.gd")
const HOTBAR_SLOTS := 4
const DEFAULT_INVENTORY_VISIBLE_SLOTS := 21
const DEFAULT_CHEST_VISIBLE_SLOTS := 15
const HOTBAR_SLOT_SIZE := 42
const MENU_SLOT_SIZE := 40
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
var context_action_button: Button
var craft_button: Button
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
var _audio_handles: Dictionary = {}
var _audio_drag_touch_index: Dictionary = {}
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
	_build_context_action()
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

func _texture_rect(name: StringName, stretch := TextureRect.STRETCH_KEEP_ASPECT_CENTERED) -> TextureRect:
	var result := TextureRect.new()
	result.texture = SourceAssets.texture(name)
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	result.stretch_mode = stretch
	return result

func _close_button(callable: Callable) -> TextureButton:
	var button := TextureButton.new()
	button.texture_normal = SourceAssets.texture(&"square_button")
	button.texture_pressed = SourceAssets.texture(&"square_button_active")
	button.texture_hover = button.texture_normal
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_SCALE
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.z_index = 6
	var close_icon := _texture_rect(&"close_icon")
	close_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	close_icon.offset_left = 6.0
	close_icon.offset_top = 6.0
	close_icon.offset_right = -6.0
	close_icon.offset_bottom = -6.0
	button.add_child(close_icon)
	button.pressed.connect(callable)
	return button

func _square_icon_button(icon_name: StringName, tooltip: String) -> TextureButton:
	var button := TextureButton.new()
	button.texture_normal = SourceAssets.texture(&"square_button")
	button.texture_pressed = SourceAssets.texture(&"square_button_active")
	button.texture_hover = button.texture_normal
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_SCALE
	button.custom_minimum_size = Vector2(38.0, 38.0)
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.tooltip_text = tooltip
	button.accessibility_name = tooltip
	var icon := _texture_rect(icon_name)
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 7.0
	icon.offset_top = 7.0
	icon.offset_right = -7.0
	icon.offset_bottom = -7.0
	button.add_child(icon)
	return button

func _build_survival_hud() -> void:
	survival_panel = Control.new()
	survival_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(survival_panel)
	var art := SourceAssets.nine_patch(&"survival_panel")
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	survival_panel.add_child(art)
	var x := 9.0
	x = _add_survival_need(x, &"health_icon", &"bar_health", _health_segments)
	x = _add_survival_need(x, &"hunger_icon", &"bar_hunger", _hunger_segments)
	x = _add_survival_need(x, &"thirst_icon", &"bar_thirst", _thirst_segments)
	var day_icon := _texture_rect(&"day_icon")
	day_icon.position = Vector2(x + 1.0, 8.0)
	day_icon.size = Vector2(19.0, 18.0)
	day_icon.modulate = Color("#d4b266")
	survival_panel.add_child(day_icon)
	day_label = Label.new()
	day_label.text = "Day 1"
	day_label.position = Vector2(x + 22.0, 6.0)
	day_label.size = Vector2(52.0, 24.0)
	day_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	SourceAssets.apply_text(day_label, 9)
	survival_panel.add_child(day_label)

func _add_survival_need(x: float, icon_name: StringName, fill_name: StringName, row: Array[TextureRect]) -> float:
	var icon := _texture_rect(icon_name)
	icon.position = Vector2(x, 7.0)
	icon.size = Vector2(20.0, 20.0)
	survival_panel.add_child(icon)
	var sx := x + 24.0
	for index: int in range(SURVIVAL_SEGMENTS):
		var piece := _texture_rect(fill_name, TextureRect.STRETCH_SCALE)
		piece.position = Vector2(sx + float(index) * 7.2, 12.0)
		piece.size = Vector2(5.4, 10.0)
		survival_panel.add_child(piece)
		row.append(piece)
	return sx + float(SURVIVAL_SEGMENTS) * 7.2 + 7.0

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
		row[index].texture = SourceAssets.texture(fill_name)
		row[index].modulate = Color.WHITE if index < filled else Color(0.26, 0.24, 0.20, 0.68)

func _build_hotbar() -> void:
	hotbar_frame = Control.new()
	hotbar_frame.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(hotbar_frame)
	hotbar = GoSlotGrid.new()
	hotbar.slot_count = HOTBAR_SLOTS
	hotbar.cell_size = HOTBAR_SLOT_SIZE
	hotbar.slot_visual_kind = &"hotbar"
	hotbar.keyboard_focus = false
	hotbar.selected = 0
	hotbar_frame.add_child(hotbar)
	_hotbar_divider = _texture_rect(&"v_divider", TextureRect.STRETCH_SCALE)
	add_child(_hotbar_divider)
	bag_toggle = TextureButton.new()
	bag_toggle.texture_normal = SourceAssets.texture(&"square_button")
	bag_toggle.texture_pressed = SourceAssets.texture(&"square_button_active")
	bag_toggle.texture_hover = bag_toggle.texture_normal
	bag_toggle.ignore_texture_size = true
	bag_toggle.stretch_mode = TextureButton.STRETCH_SCALE
	bag_toggle.custom_minimum_size = Vector2(HOTBAR_SLOT_SIZE, HOTBAR_SLOT_SIZE)
	bag_toggle.focus_mode = Control.FOCUS_NONE
	bag_toggle.mouse_filter = Control.MOUSE_FILTER_STOP
	bag_toggle.tooltip_text = "Inventory"
	bag_toggle.accessibility_name = "Inventory"
	var bag_icon := _texture_rect(&"bag_icon")
	bag_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bag_icon.offset_left = 6.0
	bag_icon.offset_top = 5.0
	bag_icon.offset_right = -6.0
	bag_icon.offset_bottom = -5.0
	bag_toggle.add_child(bag_icon)
	bag_toggle.pressed.connect(toggle_bag)
	add_child(bag_toggle)
	craft_button = _menu_button("Üretim")
	craft_button.tooltip_text = "Üretim kitabı"
	craft_button.accessibility_name = "Üretim kitabı"
	craft_button.pressed.connect(func() -> void: craft_book_requested.emit())
	add_child(craft_button)

func _build_context_action() -> void:
	context_action_button = _menu_button("")
	context_action_button.visible = false
	context_action_button.disabled = true
	context_action_button.z_index = 5
	context_action_button.pressed.connect(func() -> void: context_action_requested.emit())
	add_child(context_action_button)


func set_context_action(label: String, enabled: bool, visible: bool = true) -> void:
	if context_action_button == null:
		return
	context_action_button.text = label
	context_action_button.disabled = not enabled
	context_action_button.visible = visible


func clear_context_action() -> void:
	set_context_action("", false, false)


func context_action_touch_point() -> Vector2:
	if context_action_button == null:
		return Vector2.ZERO
	return context_action_button.position + context_action_button.size * 0.5


func _build_storage_menu() -> void:
	_bag_overlay = ColorRect.new()
	_bag_overlay.color = Color(0.025, 0.018, 0.012, 0.61)
	_bag_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_bag_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bag_overlay.z_index = 30
	add_child(_bag_overlay)
	bag_panel = Control.new()
	bag_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	bag_panel.z_index = 31
	_bag_overlay.add_child(bag_panel)
	var art := SourceAssets.nine_patch(&"window_panel")
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bag_panel.add_child(art)
	_storage_title_plate = SourceAssets.nine_patch(&"title_plaque")
	_storage_title_plate.z_index = 4
	bag_panel.add_child(_storage_title_plate)
	_storage_title = Label.new()
	_storage_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_storage_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	SourceAssets.apply_text(_storage_title, 14)
	_storage_title_plate.add_child(_storage_title)
	_storage_close_button = _close_button(close_bag)
	bag_panel.add_child(_storage_close_button)
	_section_title_plate = SourceAssets.nine_patch(&"section_plaque")
	_section_title_plate.z_index = 3
	bag_panel.add_child(_section_title_plate)
	var section_title := Label.new()
	section_title.text = "Inventory"
	section_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	section_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	SourceAssets.apply_text(section_title, 10)
	section_title.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_section_title_plate.add_child(section_title)
	bag_grid = GoSlotGrid.new()
	bag_grid.slot_count = inventory_visible_slots
	bag_grid.cell_size = MENU_SLOT_SIZE
	bag_grid.slot_visual_kind = &"inventory"
	bag_grid.z_index = 1
	bag_grid.slot_pressed.connect(_on_bag_slot_pressed)
	bag_panel.add_child(bag_grid)
	chest_grid = GoSlotGrid.new()
	chest_grid.slot_count = chest_visible_slots
	chest_grid.cell_size = MENU_SLOT_SIZE
	chest_grid.slot_visual_kind = &"inventory"
	chest_grid.z_index = 1
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
	var bag_count := inventory.total_count(inventory.bag)
	var chest_count := inventory.total_count(inventory.chest)
	bag_total.text = str(bag_count)
	chest_total.text = str(chest_count)
	bag_to_chest_button.disabled = not chest_reachable or bag_count <= 0
	chest_to_bag_button.disabled = not chest_reachable or chest_count <= 0

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
			var plugin_id := storage.get_slot_item_id(index)
			var stable_id := inventory.stable_id_for_plugin_id(plugin_id)
			var caption := inventory.item_display_name(stable_id)
			grid.set_cell(index, {
				"caption": caption,
				"quantity": amount,
				"tooltip": "%s ×%d" % [caption, amount],
			})

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
	var visual_gap := 0 if chest_mode else SLOT_GAP
	bag_grid.cell_size = MENU_SLOT_SIZE
	chest_grid.cell_size = MENU_SLOT_SIZE
	bag_grid.add_theme_constant_override(&"h_separation", visual_gap)
	bag_grid.add_theme_constant_override(&"v_separation", visual_gap)
	chest_grid.add_theme_constant_override(&"h_separation", 0)
	chest_grid.add_theme_constant_override(&"v_separation", 0)
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
	pause_overlay.color = Color(0.025, 0.018, 0.012, 0.64)
	pause_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	pause_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_overlay.z_index = 40
	add_child(pause_overlay)
	pause_panel = Control.new()
	pause_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	pause_panel.z_index = 41
	pause_overlay.add_child(pause_panel)
	var art := SourceAssets.nine_patch(&"window_panel")
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_panel.add_child(art)
	var title_plate := SourceAssets.nine_patch(&"title_plaque")
	title_plate.position = Vector2(72.0, -8.0)
	title_plate.size = Vector2(128.0, 36.0)
	title_plate.z_index = 4
	pause_panel.add_child(title_plate)
	var title := Label.new()
	title.text = "Paused"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	SourceAssets.apply_text(title, 14)
	title.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title_plate.add_child(title)
	_pause_close_button = _close_button(resume_game)
	pause_panel.add_child(_pause_close_button)
	resume_button = _menu_button("Resume")
	resume_button.pressed.connect(resume_game)
	pause_panel.add_child(resume_button)
	audio_button = _menu_button("Audio")
	audio_button.pressed.connect(open_audio)
	pause_panel.add_child(audio_button)
	_audio_divider = _texture_rect(&"h_divider", TextureRect.STRETCH_SCALE)
	pause_panel.add_child(_audio_divider)
	audio_panel = Control.new()
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
	var button := Button.new()
	button.text = text_value
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	SourceAssets.apply_text_button(button, false, 13)
	return button

func _add_audio_slider(y: float, text_value: String, bus_key: String) -> void:
	var label := Label.new()
	label.text = text_value
	label.position = Vector2(0.0, y)
	label.size = Vector2(78.0, 27.0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	SourceAssets.apply_text(label, 9)
	audio_panel.add_child(label)
	var holder := Control.new()
	holder.position = Vector2(78.0, y + 2.0)
	holder.size = Vector2(138.0, 24.0)
	audio_panel.add_child(holder)
	var track := _texture_rect(&"slider_track", TextureRect.STRETCH_SCALE)
	track.position = Vector2(0.0, 7.0)
	track.size = Vector2(138.0, 10.0)
	holder.add_child(track)
	var handle := _texture_rect(&"slider_handle", TextureRect.STRETCH_SCALE)
	handle.size = Vector2(13.0, 22.0)
	handle.position = Vector2(0.0, 1.0)
	holder.add_child(handle)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	slider.mouse_filter = Control.MOUSE_FILTER_STOP
	slider.focus_mode = Control.FOCUS_NONE
	SourceAssets.make_invisible_slider(slider)
	slider.value_changed.connect(func(value: float) -> void:
		_sync_slider_visual(bus_key, value)
		if not _syncing_audio_controls and audio_settings != null:
			audio_settings.set_level(bus_key, value, not _audio_drag_touch_index.has(bus_key))
	)
	slider.gui_input.connect(_on_audio_slider_gui_input.bind(bus_key, slider))
	holder.add_child(slider)
	audio_sliders[bus_key] = slider
	_audio_handles[bus_key] = handle

func _sync_slider_visual(bus_key: String, value: float) -> void:
	if not _audio_handles.has(bus_key):
		return
	var handle := _audio_handles[bus_key] as TextureRect
	var holder := handle.get_parent() as Control
	var usable := maxf(0.0, holder.size.x - handle.size.x)
	handle.position.x = usable * clampf(value, 0.0, 1.0)

func _on_audio_slider_gui_input(event: InputEvent, bus_key: String, slider: HSlider) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_audio_drag_touch_index[bus_key] = touch.index
			_set_audio_slider_from_touch(bus_key, slider, touch.position)
			slider.accept_event()
		elif int(_audio_drag_touch_index.get(bus_key, -1)) == touch.index:
			_set_audio_slider_from_touch(bus_key, slider, touch.position)
			_audio_drag_touch_index.erase(bus_key)
			if audio_settings != null:
				audio_settings.set_level(bus_key, slider.value, true)
			slider.accept_event()
		return
	if event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if int(_audio_drag_touch_index.get(bus_key, -1)) != drag.index:
			return
		_set_audio_slider_from_touch(bus_key, slider, drag.position)
		slider.accept_event()


func _set_audio_slider_from_touch(bus_key: String, slider: HSlider, event_position: Vector2) -> void:
	var local_x := event_position.x
	if local_x < 0.0 or local_x > slider.size.x:
		local_x = event_position.x - slider.get_global_rect().position.x
	var width := maxf(1.0, slider.size.x)
	var ratio := clampf(local_x / width, 0.0, 1.0)
	var next_value := snappedf(ratio, slider.step)
	next_value = clampf(next_value, slider.min_value, slider.max_value)
	slider.set_value_no_signal(next_value)
	_sync_slider_visual(bus_key, next_value)
	if audio_settings != null:
		audio_settings.set_level(bus_key, next_value, false)


func open_pause() -> void:
	if pause_open:
		return
	if bag_open:
		close_bag()
	pause_open = true
	audio_open = false
	pause_overlay.visible = true
	audio_panel.visible = false
	SourceAssets.apply_text_button(audio_button, false, 13)
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
	SourceAssets.apply_text_button(audio_button, true, 13)
	_sync_audio_controls()
	_layout()

func close_audio() -> void:
	if not audio_open:
		return
	audio_open = false
	audio_panel.visible = false
	SourceAssets.apply_text_button(audio_button, false, 13)
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
		var value := audio_settings.get_level(key)
		(audio_sliders[key] as HSlider).set_value_no_signal(value)
		_sync_slider_visual(key, value)
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

func craft_touch_point() -> Vector2:
	return craft_button.position + craft_button.size * 0.5


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
	survival_panel.size = Vector2(minf(292.0, area.size.x - 16.0), 36.0)
	var button_size := Vector2(38.0, 38.0)
	pause_button.position = Vector2(area.end.x - 2.0 * button_size.x - 14.0, area.position.y + 8.0)
	pause_button.size = button_size
	var hotbar_width := float(HOTBAR_SLOTS * HOTBAR_SLOT_SIZE + (HOTBAR_SLOTS - 1) * SLOT_GAP)
	var total_width := hotbar_width + 7.0 + 2.0 + 7.0 + HOTBAR_SLOT_SIZE
	var row_x := area.position.x + maxf(0.0, (area.size.x - total_width) * 0.5)
	var row_y := area.end.y - float(HOTBAR_SLOT_SIZE) - 7.0
	hotbar_frame.position = Vector2(row_x, row_y)
	hotbar_frame.size = Vector2(hotbar_width, HOTBAR_SLOT_SIZE)
	hotbar.position = Vector2.ZERO
	hotbar.size = hotbar_frame.size
	_hotbar_divider.position = Vector2(row_x + hotbar_width + 7.0, row_y + 4.0)
	_hotbar_divider.size = Vector2(2.0, HOTBAR_SLOT_SIZE - 8.0)
	bag_toggle.position = Vector2(_hotbar_divider.position.x + 9.0, row_y)
	bag_toggle.size = Vector2(HOTBAR_SLOT_SIZE, HOTBAR_SLOT_SIZE)
	craft_button.size = Vector2(72.0, 32.0)
	var craft_x := row_x - craft_button.size.x - 8.0
	if craft_x >= area.position.x + 8.0:
		craft_button.position = Vector2(craft_x, row_y + 5.0)
	else:
		craft_button.position = Vector2(row_x, row_y - 36.0)
	context_action_button.size = Vector2(minf(112.0, area.size.x - 16.0), 34.0)
	context_action_button.position = Vector2(
		area.end.x - context_action_button.size.x - 8.0,
		maxf(area.position.y + 52.0, row_y - 42.0)
	)
	_layout_storage_panel()
	var pause_height := 212.0 if audio_open else 126.0
	pause_panel.size = Vector2(minf(272.0, area.size.x - 16.0), minf(pause_height, area.size.y - 12.0))
	pause_panel.position = area.position + (area.size - pause_panel.size) * 0.5
	_pause_close_button.position = Vector2(pause_panel.size.x - 34.0, 6.0)
	_pause_close_button.size = Vector2(28.0, 28.0)
	var button_width := minf(176.0, pause_panel.size.x - 72.0)
	var button_x := (pause_panel.size.x - button_width) * 0.5
	resume_button.position = Vector2(button_x, 36.0)
	resume_button.size = Vector2(button_width, 32.0)
	audio_button.position = Vector2(button_x, 72.0)
	audio_button.size = Vector2(button_width, 32.0)
	_audio_divider.position = Vector2(34.0, 108.0)
	_audio_divider.size = Vector2(pause_panel.size.x - 68.0, 5.0)
	audio_panel.position = Vector2(28.0, 116.0)
	audio_panel.size = Vector2(pause_panel.size.x - 56.0, 88.0)

func _layout_storage_panel() -> void:
	if not is_instance_valid(bag_panel):
		return
	var area := _effective_safe_rect()
	if area.size.x <= 1.0 or area.size.y <= 1.0:
		return
	var columns: int
	var rows: int
	var grid_width: float
	var grid_height: float
	var panel_width: float
	var panel_height: float
	var slot_size := MENU_SLOT_SIZE
	var grid_gap := 0 if _storage_chest_mode else SLOT_GAP
	if _storage_chest_mode:
		columns = mini(5, maxi(1, floori((area.size.x - 40.0) / (2.0 * float(slot_size)))))
		rows = ceili(float(chest_visible_slots) / float(columns))
		grid_width = float(columns * slot_size + (columns - 1) * grid_gap)
		grid_height = float(rows * slot_size + (rows - 1) * grid_gap)
		panel_width = minf(area.size.x - 10.0, grid_width * 2.0 + 40.0)
		panel_height = minf(area.size.y - 8.0, grid_height + 58.0)
	else:
		columns = mini(7, maxi(1, floori((area.size.x - 34.0 + float(grid_gap)) / float(slot_size + grid_gap))))
		rows = ceili(float(inventory_visible_slots) / float(columns))
		grid_width = float(columns * slot_size + (columns - 1) * grid_gap)
		grid_height = float(rows * slot_size + (rows - 1) * grid_gap)
		panel_width = minf(area.size.x - 8.0, grid_width + 34.0)
		panel_height = minf(area.size.y - 8.0, grid_height + 66.0)
	bag_panel.size = Vector2(panel_width, panel_height)
	bag_panel.position = area.position + (area.size - bag_panel.size) * 0.5
	_storage_title_plate.position = Vector2((panel_width - 132.0) * 0.5, -8.0)
	_storage_title_plate.size = Vector2(132.0, 38.0)
	_storage_title.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_storage_close_button.position = Vector2(panel_width - 34.0, 6.0)
	_storage_close_button.size = Vector2(28.0, 28.0)
	if _storage_chest_mode:
		bag_grid.position = Vector2(10.0, 45.0)
		bag_grid.size = Vector2(grid_width, grid_height)
		chest_grid.position = Vector2(panel_width - grid_width - 10.0, 45.0)
		chest_grid.size = Vector2(grid_width, grid_height)
		_section_title_plate.position = Vector2(10.0 + (grid_width - 104.0) * 0.5, 22.0)
		_section_title_plate.size = Vector2(104.0, 23.0)
	else:
		bag_grid.position = Vector2((panel_width - grid_width) * 0.5, 46.0)
		bag_grid.size = Vector2(grid_width, minf(grid_height, panel_height - 52.0))
		chest_grid.position = Vector2.ZERO
		chest_grid.size = Vector2.ZERO
