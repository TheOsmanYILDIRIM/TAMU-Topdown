extends RefCounted
class_name TamuInventoryBridge

const ITEM_DEFINITION_PATH := "res://data/catalog/definitions/wood_log.json"
const WOOD_LOG_STABLE_ID: StringName = &"core:wood_log"
const WOOD_LOG_PLUGIN_ID: int = 0

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


func bag_to_chest(amount: int = 1) -> int:
	return transfer(bag, chest, amount)


func chest_to_bag(amount: int = 1) -> int:
	return transfer(chest, bag, amount)
