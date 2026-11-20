extends RefCounted
class_name TamuInventoryBridge

const WOOD_LOG_STABLE_ID: StringName = &"core:wood_log"
const WOOD_PLANK_STABLE_ID: StringName = &"core:wood_plank"
const WORKBENCH_STABLE_ID: StringName = &"core:workbench"
const WOOD_LOG_PLUGIN_ID: int = 0
const WOOD_PLANK_PLUGIN_ID: int = 1
const WORKBENCH_PLUGIN_ID: int = 2
const BAG_STABLE_ID := "inventory:bag"
const CHEST_STABLE_ID := "inventory:chest"
const ITEM_PATHS: Dictionary = {
	WOOD_LOG_STABLE_ID: "res://data/catalog/definitions/wood_log.json",
	WOOD_PLANK_STABLE_ID: "res://data/catalog/definitions/wood_plank.json",
	WORKBENCH_STABLE_ID: "res://data/catalog/definitions/workbench.json",
}
const PLUGIN_IDS: Dictionary = {
	WOOD_LOG_STABLE_ID: WOOD_LOG_PLUGIN_ID,
	WOOD_PLANK_STABLE_ID: WOOD_PLANK_PLUGIN_ID,
	WORKBENCH_STABLE_ID: WORKBENCH_PLUGIN_ID,
}
const PLUGIN_STABLE_IDS: Dictionary = {
	WOOD_LOG_PLUGIN_ID: WOOD_LOG_STABLE_ID,
	WOOD_PLANK_PLUGIN_ID: WOOD_PLANK_STABLE_ID,
	WORKBENCH_PLUGIN_ID: WORKBENCH_STABLE_ID,
}

var definition: Dictionary
var definitions: Dictionary = {}
var registry: ItemRegistry
var bag: InventoryManager
var chest: InventoryManager


func _init(bag_slots: int = 4, chest_slots: int = 4) -> void:
	registry = ItemRegistry.new()
	for stable_value: Variant in ITEM_PATHS.keys():
		var stable_id := StringName(stable_value)
		var loaded := _load_definition(String(ITEM_PATHS[stable_id]), stable_id)
		definitions[stable_id] = loaded
		var components: Dictionary = loaded.get("components", {})
		var stackable: Dictionary = components.get("core:stackable", {})
		var max_count := int(stackable.get("max_count", 1))
		var plugin_id := int(PLUGIN_IDS[stable_id])
		registry.add_item(
			plugin_id,
			String(stable_id),
			"",
			null,
			max_count,
			0,
			{"stable_id": String(stable_id)}
		)
	definition = definitions[WOOD_LOG_STABLE_ID] as Dictionary

	bag = InventoryManager.new(registry)
	chest = InventoryManager.new(registry)
	bag.resize(bag_slots)
	chest.resize(chest_slots)


func _load_definition(path: String, expected_id: StringName) -> Dictionary:
	var raw := FileAccess.get_file_as_string(path)
	assert(not raw.is_empty(), "TAMU item definition is missing: %s" % path)
	var parsed: Variant = JSON.parse_string(raw)
	assert(parsed is Dictionary, "TAMU item definition is not valid JSON: %s" % path)
	var loaded := parsed as Dictionary
	assert(StringName(loaded.get("id", "")) == expected_id, "Unexpected TAMU item ID in %s." % path)
	var components: Dictionary = loaded.get("components", {})
	var stackable: Dictionary = components.get("core:stackable", {})
	if expected_id == WOOD_LOG_STABLE_ID or expected_id == WOOD_PLANK_STABLE_ID:
		assert(int(stackable.get("max_count", 0)) == 99, "Unexpected TAMU stack capacity.")
	return loaded


func plugin_id_for_stable_id(stable_id: StringName) -> int:
	return int(PLUGIN_IDS.get(stable_id, -1))


func stable_id_for_plugin_id(plugin_id: int) -> StringName:
	return StringName(PLUGIN_STABLE_IDS.get(plugin_id, &""))


func item_display_name(stable_id: StringName) -> String:
	match stable_id:
		WOOD_LOG_STABLE_ID:
			return "Odun"
		WOOD_PLANK_STABLE_ID:
			return "Tahta"
		WORKBENCH_STABLE_ID:
			return "Tezgâh"
		_:
			return String(stable_id)


func count(storage: InventoryManager) -> int:
	return count_item(storage, WOOD_LOG_STABLE_ID)


func count_item(storage: InventoryManager, stable_id: StringName) -> int:
	var plugin_id := plugin_id_for_stable_id(stable_id)
	if plugin_id < 0:
		return 0
	return storage.get_item_total(plugin_id)


func total_count(storage: InventoryManager) -> int:
	var total := 0
	for slot_index: int in storage.size():
		total += storage.get_slot_item_amount(slot_index)
	return total


func transfer(source: InventoryManager, target: InventoryManager, amount: int) -> int:
	if amount <= 0:
		return 0
	var move_amount := mini(amount, count(source))
	move_amount = mini(move_amount, target.get_remaining_capacity_for_item(WOOD_LOG_PLUGIN_ID))
	if move_amount <= 0:
		return 0
	var remove_excess: ExcessItems = source.remove(
		WOOD_LOG_PLUGIN_ID, move_amount, null, -1, false
	)
	if remove_excess != null and remove_excess.get_amount() > 0:
		return 0
	var add_excess: ExcessItems = target.add(
		WOOD_LOG_PLUGIN_ID, move_amount, null, -1, false
	)
	if add_excess != null and add_excess.get_amount() > 0:
		var rollback: ExcessItems = source.add(
			WOOD_LOG_PLUGIN_ID, move_amount, null, -1, false
		)
		assert(rollback == null or rollback.get_amount() == 0, "Inventory rollback failed.")
		return 0
	return move_amount


func bag_remaining_capacity() -> int:
	return bag_remaining_capacity_for(WOOD_LOG_STABLE_ID)


func bag_remaining_capacity_for(stable_id: StringName) -> int:
	var plugin_id := plugin_id_for_stable_id(stable_id)
	if plugin_id < 0:
		return 0
	return bag.get_remaining_capacity_for_item(plugin_id)


func add_to_bag(amount: int) -> int:
	return add_item_to_bag(WOOD_LOG_STABLE_ID, amount)


func add_item_to_bag(stable_id: StringName, amount: int) -> int:
	if amount <= 0:
		return 0
	var plugin_id := plugin_id_for_stable_id(stable_id)
	if plugin_id < 0:
		return 0
	var before := count_item(bag, stable_id)
	var excess: ExcessItems = bag.add(plugin_id, amount, null, -1, false)
	var added := count_item(bag, stable_id) - before
	if excess != null:
		assert(excess.get_amount() == amount - added, "Inventory add result is inconsistent.")
	return added


func add_to_bag_atomic(amount: int) -> int:
	return add_item_to_bag_atomic(WOOD_LOG_STABLE_ID, amount)


func add_item_to_bag_atomic(stable_id: StringName, amount: int) -> int:
	if amount <= 0 or bag_remaining_capacity_for(stable_id) < amount:
		return 0
	var plugin_id := plugin_id_for_stable_id(stable_id)
	var before := count_item(bag, stable_id)
	var excess: ExcessItems = bag.add(plugin_id, amount, null, -1, false)
	if excess != null and excess.get_amount() > 0:
		var inserted := count_item(bag, stable_id) - before
		if inserted > 0:
			var rollback: ExcessItems = bag.remove(plugin_id, inserted, null, -1, false)
			assert(rollback == null or rollback.get_amount() == 0, "Atomic bag rollback failed.")
		return 0
	return amount


func remove_item_from_bag_atomic(stable_id: StringName, amount: int) -> int:
	if amount <= 0 or count_item(bag, stable_id) < amount:
		return 0
	var candidate := _clone_storage(bag)
	if candidate == null:
		return 0
	var plugin_id := plugin_id_for_stable_id(stable_id)
	var excess: ExcessItems = candidate.remove(plugin_id, amount, null, -1, false)
	if excess != null and excess.get_amount() > 0:
		return 0
	bag = candidate
	return amount


func preview_recipe(inputs: Array, outputs: Array) -> Dictionary:
	var candidate := _clone_storage(bag)
	if candidate == null:
		return {"ok": false, "status": "invalid_preview"}
	var status := _apply_recipe_to_storage(candidate, inputs, outputs)
	return {"ok": status == "crafted", "status": status}


func apply_recipe_atomic(inputs: Array, outputs: Array) -> Dictionary:
	var candidate := _clone_storage(bag)
	if candidate == null:
		return {"ok": false, "status": "invalid_preview"}
	var status := _apply_recipe_to_storage(candidate, inputs, outputs)
	if status != "crafted":
		return {"ok": false, "status": status}
	bag = candidate
	return {"ok": true, "status": "crafted"}


func _apply_recipe_to_storage(storage: InventoryManager, inputs: Array, outputs: Array) -> String:
	for stack_value: Variant in inputs:
		if not stack_value is Dictionary:
			return "invalid_preview"
		var stack := stack_value as Dictionary
		var stable_id := StringName(stack.get("def_id", ""))
		var count_value := int(stack.get("count", 0))
		var plugin_id := plugin_id_for_stable_id(stable_id)
		if plugin_id < 0 or count_value <= 0 or storage.get_item_total(plugin_id) < count_value:
			return "insufficient_materials"
		var remove_excess: ExcessItems = storage.remove(plugin_id, count_value, null, -1, false)
		if remove_excess != null and remove_excess.get_amount() > 0:
			return "invalid_preview"
	for stack_value: Variant in outputs:
		if not stack_value is Dictionary:
			return "invalid_preview"
		var stack := stack_value as Dictionary
		var stable_id := StringName(stack.get("def_id", ""))
		var count_value := int(stack.get("count", 0))
		var plugin_id := plugin_id_for_stable_id(stable_id)
		if plugin_id < 0 or count_value <= 0:
			return "invalid_preview"
		var add_excess: ExcessItems = storage.add(plugin_id, count_value, null, -1, false)
		if add_excess != null and add_excess.get_amount() > 0:
			return "inventory_full"
	return "crafted"


func bag_to_chest(amount: int = 1) -> int:
	return transfer(bag, chest, amount)


func chest_to_bag(amount: int = 1) -> int:
	return transfer(chest, bag, amount)


func snapshot_all() -> Dictionary:
	return {
		BAG_STABLE_ID: _snapshot_storage(bag),
		CHEST_STABLE_ID: _snapshot_storage(chest),
	}


func validate_snapshot_all(snapshot: Dictionary) -> Error:
	var bag_value: Variant = snapshot.get(BAG_STABLE_ID, null)
	var chest_value: Variant = snapshot.get(CHEST_STABLE_ID, null)
	if _build_storage(bag_value, bag.size()) == null:
		return ERR_INVALID_DATA
	if _build_storage(chest_value, chest.size()) == null:
		return ERR_INVALID_DATA
	return OK


func restore_all(snapshot: Dictionary) -> Error:
	var bag_candidate := _build_storage(snapshot.get(BAG_STABLE_ID, null), bag.size())
	if bag_candidate == null:
		return ERR_INVALID_DATA
	var chest_candidate := _build_storage(snapshot.get(CHEST_STABLE_ID, null), chest.size())
	if chest_candidate == null:
		return ERR_INVALID_DATA
	bag = bag_candidate
	chest = chest_candidate
	return OK


func _clone_storage(storage: InventoryManager) -> InventoryManager:
	return _build_storage(_snapshot_storage(storage), storage.size())


func _snapshot_storage(storage: InventoryManager) -> Dictionary:
	var slots: Array[Dictionary] = []
	for slot_index: int in storage.size():
		var amount := storage.get_slot_item_amount(slot_index)
		if amount <= 0:
			continue
		var plugin_id := storage.get_slot_item_id(slot_index)
		var stable_id := stable_id_for_plugin_id(plugin_id)
		assert(stable_id != &"", "Unexpected inventory plugin ID in TAMU save.")
		slots.append({
			"slot": slot_index,
			"item_id": String(stable_id),
			"amount": amount,
		})
	return {
		"slot_count": storage.size(),
		"slots": slots,
	}


func _build_storage(snapshot_value: Variant, expected_slots: int) -> InventoryManager:
	if typeof(snapshot_value) != TYPE_DICTIONARY:
		return null
	var snapshot := snapshot_value as Dictionary
	var slot_count := _strict_int(snapshot.get("slot_count", null), 1, 128)
	if slot_count != expected_slots:
		return null
	var slots_value: Variant = snapshot.get("slots", null)
	if typeof(slots_value) != TYPE_ARRAY:
		return null
	var slots := slots_value as Array
	var candidate := InventoryManager.new(registry)
	candidate.resize(slot_count)
	var seen_slots: Dictionary = {}
	for entry_value: Variant in slots:
		if typeof(entry_value) != TYPE_DICTIONARY:
			return null
		var entry := entry_value as Dictionary
		var slot_index := _strict_int(entry.get("slot", null), 0, slot_count - 1)
		var stable_id := StringName(entry.get("item_id", ""))
		var plugin_id := plugin_id_for_stable_id(stable_id)
		if plugin_id < 0:
			return null
		var stack_capacity := registry.get_stack_capacity(plugin_id)
		var amount := _strict_int(entry.get("amount", null), 1, stack_capacity)
		if slot_index < 0 or amount < 0:
			return null
		if seen_slots.has(slot_index):
			return null
		seen_slots[slot_index] = true
		if candidate.add_items_to_slot(slot_index, plugin_id, amount) != 0:
			return null
	return candidate


func _strict_int(value: Variant, minimum: int, maximum: int) -> int:
	var kind := typeof(value)
	if kind != TYPE_INT and kind != TYPE_FLOAT:
		return -1
	var parsed := int(value)
	if float(parsed) != float(value):
		return -1
	if parsed < minimum or parsed > maximum:
		return -1
	return parsed
