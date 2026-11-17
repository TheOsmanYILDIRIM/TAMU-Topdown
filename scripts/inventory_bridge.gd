extends RefCounted
class_name TamuInventoryBridge

const ITEM_DEFINITION_PATH := "res://data/catalog/definitions/wood_log.json"
const WOOD_LOG_STABLE_ID: StringName = &"core:wood_log"
const WOOD_LOG_PLUGIN_ID: int = 0
const BAG_STABLE_ID := "inventory:bag"
const CHEST_STABLE_ID := "inventory:chest"

var definition: Dictionary
var registry: ItemRegistry
var bag: InventoryManager
var chest: InventoryManager


func _init(bag_slots: int = 4, chest_slots: int = 4) -> void:
	definition = _load_definition()
	var components: Dictionary = definition.get("components", {})
	var stackable: Dictionary = components.get("core:stackable", {})
	var max_count: int = int(stackable.get("max_count", 0))

	registry = ItemRegistry.new()
	registry.add_item(
		WOOD_LOG_PLUGIN_ID,
		String(WOOD_LOG_STABLE_ID),
		"",
		null,
		max_count,
		0,
		{"stable_id": String(WOOD_LOG_STABLE_ID)}
	)

	bag = InventoryManager.new(registry)
	chest = InventoryManager.new(registry)
	bag.resize(bag_slots)
	chest.resize(chest_slots)


func _load_definition() -> Dictionary:
	var raw := FileAccess.get_file_as_string(ITEM_DEFINITION_PATH)
	assert(not raw.is_empty(), "TAMU item definition is missing: %s" % ITEM_DEFINITION_PATH)
	var parsed: Variant = JSON.parse_string(raw)
	assert(parsed is Dictionary, "TAMU item definition is not valid JSON.")
	var loaded := parsed as Dictionary
	assert(StringName(loaded.get("id", "")) == WOOD_LOG_STABLE_ID, "Unexpected TAMU item ID.")
	var components: Dictionary = loaded.get("components", {})
	var stackable: Dictionary = components.get("core:stackable", {})
	assert(int(stackable.get("max_count", 0)) == 99, "Unexpected TAMU stack capacity.")
	return loaded


func count(storage: InventoryManager) -> int:
	return storage.get_item_total(WOOD_LOG_PLUGIN_ID)


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
	return bag.get_remaining_capacity_for_item(WOOD_LOG_PLUGIN_ID)


func add_to_bag(amount: int) -> int:
	if amount <= 0:
		return 0
	var before := count(bag)
	var excess: ExcessItems = bag.add(
		WOOD_LOG_PLUGIN_ID, amount, null, -1, false
	)
	var added := count(bag) - before
	if excess != null:
		assert(excess.get_amount() == amount - added, "Inventory add result is inconsistent.")
	return added


func add_to_bag_atomic(amount: int) -> int:
	if amount <= 0 or bag_remaining_capacity() < amount:
		return 0
	var before := count(bag)
	var excess: ExcessItems = bag.add(
		WOOD_LOG_PLUGIN_ID, amount, null, -1, false
	)
	if excess != null and excess.get_amount() > 0:
		var inserted := count(bag) - before
		if inserted > 0:
			var rollback: ExcessItems = bag.remove(
				WOOD_LOG_PLUGIN_ID, inserted, null, -1, false
			)
			assert(rollback == null or rollback.get_amount() == 0, "Atomic bag rollback failed.")
		return 0
	return amount


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


func _snapshot_storage(storage: InventoryManager) -> Dictionary:
	var slots: Array[Dictionary] = []
	for slot_index: int in storage.size():
		var amount := storage.get_slot_item_amount(slot_index)
		if amount <= 0:
			continue
		var item_id := storage.get_slot_item_id(slot_index)
		assert(item_id == WOOD_LOG_PLUGIN_ID, "Unexpected inventory plugin ID in TAMU save.")
		slots.append({
			"slot": slot_index,
			"item_id": String(WOOD_LOG_STABLE_ID),
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
	var stack_capacity := registry.get_stack_capacity(WOOD_LOG_PLUGIN_ID)

	for entry_value: Variant in slots:
		if typeof(entry_value) != TYPE_DICTIONARY:
			return null
		var entry := entry_value as Dictionary
		var slot_index := _strict_int(entry.get("slot", null), 0, slot_count - 1)
		var amount := _strict_int(entry.get("amount", null), 1, stack_capacity)
		if slot_index < 0 or amount < 0:
			return null
		if StringName(entry.get("item_id", "")) != WOOD_LOG_STABLE_ID:
			return null
		if seen_slots.has(slot_index):
			return null
		seen_slots[slot_index] = true
		if candidate.add_items_to_slot(slot_index, WOOD_LOG_PLUGIN_ID, amount) != 0:
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
