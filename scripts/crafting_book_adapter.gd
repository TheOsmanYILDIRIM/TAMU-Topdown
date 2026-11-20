extends Control
class_name TamuCraftingBookAdapter

signal craft_requested(recipe_id: StringName)
signal placement_rotate_requested
signal placement_cancel_requested

const SourceAssets = preload("res://scripts/tamu_gui_source_assets.gd")
const CATEGORIES := ["Tümü", "Araçlar", "Silahlar", "Yapılar", "Ekipman", "İşleme", "Diğer"]

var inventory: TamuInventoryBridge
var crafting: TamuCraftingAdapter
var book_root: Control
var window_panel: NinePatchRect
var title_plate: NinePatchRect
var heading: Label
var back_button: Button
var close_button: TextureButton
var page_scroll: ScrollContainer
var page_body: VBoxContainer
var search_box: LineEdit
var category_row: HBoxContainer
var card_grid: GridContainer
var schema_buttons: Dictionary = {}
var craft_action_button: Button
var feedback_label: Label
var placement_bar: NinePatchRect
var placement_status_label: Label
var placement_rotate_button: Button
var placement_cancel_button: Button
var current_page := "library"
var active_recipe: StringName = &""
var selected_category := "Tümü"
var search_text := ""
var placement_active := false


func setup(source_inventory: TamuInventoryBridge, source_crafting: TamuCraftingAdapter) -> void:
	inventory = source_inventory
	crafting = source_crafting


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 40
	_build_book()
	_build_placement_bar()
	get_viewport().size_changed.connect(_layout)
	_layout()


func _build_book() -> void:
	book_root = Control.new()
	book_root.name = "CraftBookModal"
	book_root.mouse_filter = Control.MOUSE_FILTER_STOP
	book_root.visible = false
	add_child(book_root)

	var dim := ColorRect.new()
	dim.name = "CraftDim"
	dim.color = Color(0.025, 0.018, 0.012, 0.72)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	book_root.add_child(dim)

	window_panel = SourceAssets.nine_patch(&"window_panel")
	window_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	book_root.add_child(window_panel)

	title_plate = SourceAssets.nine_patch(&"title_plaque")
	book_root.add_child(title_plate)
	heading = _label("ŞEMA KÜTÜPHANESİ", 18)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_plate.add_child(heading)

	back_button = _button("‹ Geri", 12)
	back_button.pressed.connect(go_back)
	book_root.add_child(back_button)

	close_button = TextureButton.new()
	close_button.texture_normal = SourceAssets.texture(&"square_button")
	close_button.texture_pressed = SourceAssets.texture(&"square_button_active")
	close_button.texture_hover = close_button.texture_normal
	close_button.ignore_texture_size = true
	close_button.stretch_mode = TextureButton.STRETCH_SCALE
	close_button.mouse_filter = Control.MOUSE_FILTER_STOP
	close_button.focus_mode = Control.FOCUS_NONE
	var close_icon := TextureRect.new()
	close_icon.texture = SourceAssets.texture(&"close_icon")
	close_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	close_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	close_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	close_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	close_icon.offset_left = 6.0
	close_icon.offset_top = 6.0
	close_icon.offset_right = -6.0
	close_icon.offset_bottom = -6.0
	close_button.add_child(close_icon)
	close_button.pressed.connect(close_book)
	book_root.add_child(close_button)

	page_scroll = ScrollContainer.new()
	page_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	book_root.add_child(page_scroll)
	page_body = VBoxContainer.new()
	page_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page_body.add_theme_constant_override(&"separation", 6)
	page_scroll.add_child(page_body)


func _build_placement_bar() -> void:
	placement_bar = SourceAssets.nine_patch(&"window_panel")
	placement_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	placement_bar.visible = false
	placement_bar.z_index = 60
	add_child(placement_bar)
	placement_status_label = _label("Yerleştirme", 12)
	placement_bar.add_child(placement_status_label)
	placement_rotate_button = _button("Döndür", 11)
	placement_rotate_button.pressed.connect(func() -> void: placement_rotate_requested.emit())
	placement_bar.add_child(placement_rotate_button)
	placement_cancel_button = _button("İptal", 11)
	placement_cancel_button.pressed.connect(func() -> void: placement_cancel_requested.emit())
	placement_bar.add_child(placement_cancel_button)


func _button(text_value: String, font_size: int = 13) -> Button:
	var button := Button.new()
	button.text = text_value
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	SourceAssets.apply_text_button(button, false, font_size)
	return button


func _label(text_value: String, font_size: int = 14, muted: bool = false) -> Label:
	var label := Label.new()
	label.text = text_value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	SourceAssets.apply_text(label, font_size, muted)
	return label


func open_book() -> void:
	if inventory == null or crafting == null or placement_active:
		return
	book_root.visible = true
	current_page = "library"
	_render_library()


func close_book() -> void:
	if book_root == null:
		return
	book_root.visible = false
	current_page = "library"


func is_open() -> bool:
	return book_root != null and book_root.visible


func go_back() -> void:
	if current_page == "recipe":
		_render_library()
	else:
		close_book()


func handle_back_event(event: InputEvent) -> bool:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return false
	if event.keycode != KEY_ESCAPE and event.keycode != KEY_BACK:
		return false
	if is_open():
		go_back()
		return true
	if placement_active:
		placement_cancel_requested.emit()
		return true
	return false


func _notification(what: int) -> void:
	if what != NOTIFICATION_WM_GO_BACK_REQUEST:
		return
	if is_open():
		go_back()
	elif placement_active:
		placement_cancel_requested.emit()


func _clear_page() -> void:
	schema_buttons.clear()
	craft_action_button = null
	feedback_label = null
	search_box = null
	category_row = null
	card_grid = null
	for child: Node in page_body.get_children():
		page_body.remove_child(child)
		child.queue_free()
	page_scroll.scroll_vertical = 0


func _render_library() -> void:
	current_page = "library"
	active_recipe = &""
	_clear_page()
	heading.text = "ŞEMA KÜTÜPHANESİ"
	back_button.visible = false
	page_body.add_child(_label("Keşfettiklerini bul, şema seç, malzemeleri incele.", 12, true))

	search_box = LineEdit.new()
	search_box.placeholder_text = "Şema ara..."
	search_box.text = search_text
	search_box.custom_minimum_size.y = 30.0
	search_box.add_theme_font_size_override(&"font_size", 12)
	search_box.add_theme_color_override(&"font_color", SourceAssets.TEXT_COLOR)
	search_box.add_theme_stylebox_override(&"normal", SourceAssets.style_box(&"wide_button"))
	search_box.text_changed.connect(_on_search_changed)
	page_body.add_child(search_box)

	var category_scroll := ScrollContainer.new()
	category_scroll.custom_minimum_size.y = 34.0
	category_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page_body.add_child(category_scroll)
	category_row = HBoxContainer.new()
	category_row.add_theme_constant_override(&"separation", 4)
	category_scroll.add_child(category_row)
	for category: String in CATEGORIES:
		var tab := _button(category, 10)
		tab.custom_minimum_size = Vector2(76.0, 28.0)
		if category == selected_category:
			tab.add_theme_stylebox_override(&"normal", SourceAssets.style_box(&"wide_button_active"))
		tab.pressed.connect(_set_category.bind(category))
		category_row.add_child(tab)

	page_body.add_child(_label("ŞEMALAR  /  BİLİNEN VE KEŞFEDİLEN", 11))
	card_grid = GridContainer.new()
	card_grid.columns = 2
	card_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_grid.add_theme_constant_override(&"h_separation", 6)
	card_grid.add_theme_constant_override(&"v_separation", 6)
	page_body.add_child(card_grid)
	_fill_cards()


func _fill_cards() -> void:
	if card_grid == null:
		return
	schema_buttons.clear()
	for child: Node in card_grid.get_children():
		card_grid.remove_child(child)
		child.queue_free()
	var visible_count := 0
	for id_value: Variant in crafting.recipe_ids():
		var recipe_id := StringName(id_value)
		var category := _recipe_category(recipe_id)
		var display := _recipe_name(recipe_id)
		if selected_category != "Tümü" and category != selected_category:
			continue
		if not search_text.is_empty() and display.to_lower().find(search_text.to_lower()) == -1:
			continue
		_add_recipe_card(recipe_id, display, category)
		visible_count += 1
	if (
		(selected_category == "Tümü" or selected_category == "Araçlar")
		and (search_text.is_empty() or "balta".find(search_text.to_lower()) >= 0)
	):
		_add_draft_card()
		visible_count += 1
	if visible_count == 0:
		card_grid.add_child(_label("Bu kategoride açılmış şema bulunmuyor.", 12, true))


func _add_recipe_card(recipe_id: StringName, display: String, category: String) -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(240.0, 92.0)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override(&"panel", SourceAssets.style_box(&"window_panel"))
	card_grid.add_child(panel)
	var body := VBoxContainer.new()
	body.add_theme_constant_override(&"separation", 2)
	panel.add_child(body)
	body.add_child(_label("◆ ÖĞRENİLMİŞ • " + category.to_upper(), 9, true))
	body.add_child(_label(display.to_upper(), 14))
	var action := _button("ŞEMAYI AÇ", 10)
	action.custom_minimum_size.y = 25.0
	action.pressed.connect(_open_recipe.bind(recipe_id))
	body.add_child(action)
	schema_buttons[recipe_id] = action


func _add_draft_card() -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(240.0, 92.0)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override(&"panel", SourceAssets.style_box(&"window_panel"))
	card_grid.add_child(panel)
	var body := VBoxContainer.new()
	panel.add_child(body)
	body.add_child(_label("◈ TASLAK • ARAÇLAR", 9, true))
	body.add_child(_label("BALTA", 14))
	var action := _button("ŞEMA TASLAĞI", 10)
	action.disabled = true
	action.tooltip_text = "Kaynak Godot'taki malzeme-maskesi ekranı sonraki aktarım adayıdır."
	body.add_child(action)


func _on_search_changed(value: String) -> void:
	search_text = value
	_fill_cards()


func _set_category(value: String) -> void:
	selected_category = value
	_render_library()


func _open_recipe(recipe_id: StringName) -> void:
	if crafting.recipe(recipe_id).is_empty():
		return
	current_page = "recipe"
	active_recipe = recipe_id
	_render_recipe()


func _render_recipe() -> void:
	_clear_page()
	back_button.visible = true
	heading.text = "ÜRETİM • " + _recipe_name(active_recipe).to_upper()
	var current := crafting.recipe(active_recipe)
	page_body.add_child(_label("Bu şema doğrulanmış TAMU Godot kataloğundan uyarlandı.", 11, true))
	page_body.add_child(_label("GEREKLİ MALZEMELER", 11))
	for stack_value: Variant in current.get("inputs", []):
		var stack := stack_value as Dictionary
		var stable_id := StringName(stack.get("def_id", ""))
		var need := int(stack.get("count", 0))
		var owned := inventory.count_item(inventory.bag, stable_id)
		page_body.add_child(_label("%s   %d / %d" % [inventory.item_display_name(stable_id), owned, need], 13))
	page_body.add_child(_label("SONUÇ", 11))
	for stack_value: Variant in current.get("outputs", []):
		var stack := stack_value as Dictionary
		var stable_id := StringName(stack.get("def_id", ""))
		page_body.add_child(_label("%s   ×%d" % [inventory.item_display_name(stable_id), int(stack.get("count", 0))], 13))
	var duration := float(current.get("duration_ticks", 0)) / 60.0
	page_body.add_child(_label("Süre: %.1f sn" % duration, 11, true))
	var stations: Array = current.get("station_tags", [])
	if not stations.is_empty():
		page_body.add_child(_label("Uygun üretim istasyonu gerekir.", 11, true))
	craft_action_button = _button("ÜRETİMİ BAŞLAT", 12)
	craft_action_button.custom_minimum_size.y = 34.0
	var preview := crafting.preview(active_recipe, [])
	craft_action_button.disabled = crafting.is_active() or str(preview.get("status", "")) == "insufficient_materials"
	craft_action_button.pressed.connect(func() -> void: craft_requested.emit(active_recipe))
	page_body.add_child(craft_action_button)
	feedback_label = _label("Malzemeler yalnız Rubonnek çantasından atomik olarak kullanılır.", 11, true)
	page_body.add_child(feedback_label)


func notify_craft_result(result: Dictionary) -> void:
	if feedback_label != null and is_instance_valid(feedback_label):
		feedback_label.text = "Üretim: " + str(result.get("status", "unavailable"))
	if bool(result.get("ok", false)) and str(result.get("status", "")) == "crafted" and is_open():
		_render_recipe()


func set_placement_mode(active: bool, status: String = "", rotation: int = 0) -> void:
	placement_active = active
	placement_bar.visible = active
	if active:
		close_book()
		update_placement_status(status, rotation)


func update_placement_status(status: String, rotation: int) -> void:
	if placement_status_label == null:
		return
	var readable: String = str({
		"valid": "Geçerli",
		"invalid_surface": "Geçersiz zemin",
		"out_of_range": "Menzil dışı",
		"player_overlap": "Oyuncuyla çakışıyor",
		"obstructed": "Alan dolu",
		"insufficient_materials": "Tezgâh çantada yok",
		"invalid_rotation": "Geçersiz dönüş",
	}.get(status, status))
	placement_status_label.text = "TEZGÂH • %s • %d° • Dünyaya dokun: yerleştir" % [readable, rotation * 90]


func schema_button(recipe_id: StringName) -> Button:
	return schema_buttons.get(recipe_id, null) as Button


func craft_touch_point() -> Vector2:
	return craft_action_button.position + craft_action_button.size * 0.5 if craft_action_button != null else Vector2.ZERO


func back_touch_point() -> Vector2:
	return back_button.position + back_button.size * 0.5


func placement_rotate_touch_point() -> Vector2:
	return placement_bar.position + placement_rotate_button.position + placement_rotate_button.size * 0.5


func placement_cancel_touch_point() -> Vector2:
	return placement_bar.position + placement_cancel_button.position + placement_cancel_button.size * 0.5


func _recipe_name(recipe_id: StringName) -> String:
	match recipe_id:
		&"core:planks_from_log":
			return "Tahta Üretimi"
		&"core:bench_from_planks":
			return "Tezgâh Üretimi"
		_:
			return String(recipe_id)


func _recipe_category(recipe_id: StringName) -> String:
	if recipe_id == &"core:bench_from_planks":
		return "Yapılar"
	if recipe_id == &"core:planks_from_log":
		return "İşleme"
	return "Diğer"


func _layout() -> void:
	var viewport_size := get_viewport_rect().size
	position = Vector2.ZERO
	size = viewport_size
	if book_root == null:
		return
	book_root.position = Vector2.ZERO
	book_root.size = viewport_size
	var dim := book_root.get_node("CraftDim") as ColorRect
	dim.position = Vector2.ZERO
	dim.size = viewport_size

	var panel_size := Vector2(minf(570.0, viewport_size.x - 20.0), minf(328.0, viewport_size.y - 14.0))
	window_panel.size = panel_size
	window_panel.position = (viewport_size - panel_size) * 0.5
	title_plate.size = Vector2(210.0, 42.0)
	title_plate.position = window_panel.position + Vector2((panel_size.x - title_plate.size.x) * 0.5, -3.0)
	heading.position = Vector2(8.0, 7.0)
	heading.size = title_plate.size - Vector2(16.0, 10.0)
	back_button.position = window_panel.position + Vector2(14.0, 12.0)
	back_button.size = Vector2(74.0, 28.0)
	close_button.position = window_panel.position + Vector2(panel_size.x - 46.0, 8.0)
	close_button.size = Vector2(34.0, 34.0)
	page_scroll.position = window_panel.position + Vector2(18.0, 50.0)
	page_scroll.size = Vector2(panel_size.x - 36.0, panel_size.y - 66.0)
	page_body.custom_minimum_size.x = maxf(1.0, page_scroll.size.x - 12.0)
	if card_grid != null:
		card_grid.columns = 2 if page_scroll.size.x >= 420.0 else 1

	var bar_size := Vector2(minf(430.0, viewport_size.x - 16.0), 48.0)
	placement_bar.size = bar_size
	placement_bar.position = Vector2((viewport_size.x - bar_size.x) * 0.5, 52.0)
	placement_status_label.position = Vector2(12.0, 9.0)
	placement_status_label.size = Vector2(bar_size.x - 178.0, 30.0)
	placement_rotate_button.position = Vector2(bar_size.x - 164.0, 9.0)
	placement_rotate_button.size = Vector2(72.0, 30.0)
	placement_cancel_button.position = Vector2(bar_size.x - 86.0, 9.0)
	placement_cancel_button.size = Vector2(72.0, 30.0)
