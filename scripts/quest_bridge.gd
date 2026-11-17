extends RefCounted
class_name TamuQuestBridge

const QUEST_DATA_PATH := "res://data/quests/gather_wood.json"
const QUEST_STABLE_ID: StringName = &"quest:prototype:gather_wood"
const OBJECTIVE_STABLE_ID: StringName = &"objective:prototype:gather_wood"
const ITEM_STABLE_ID: StringName = &"core:wood_log"

const META_STABLE_ID: StringName = &"stable_id"
const META_OBJECTIVE_ID: StringName = &"objective_id"
const META_ITEM_ID: StringName = &"item_id"
const META_PROGRESS: StringName = &"progress"
const META_TARGET: StringName = &"target"
const META_REWARD_CLAIMED: StringName = &"reward_claimed"
const META_REWARD_AMOUNT: StringName = &"reward_amount"

var definition: Dictionary
var manager: QuestManager
var quest: QuestEntry


func _init() -> void:
	definition = _load_definition()
	manager = QuestManager.new()
	manager.set_name("TAMU prototype quests")
	quest = manager.add_quest(
		String(definition.get("title", "")),
		String(definition.get("description", ""))
	)
	quest.set_active(true)
	quest.set_accepted(true)
	quest.set_metadata(META_STABLE_ID, String(QUEST_STABLE_ID))
	quest.set_metadata(META_OBJECTIVE_ID, String(OBJECTIVE_STABLE_ID))
	quest.set_metadata(META_ITEM_ID, String(ITEM_STABLE_ID))
	quest.set_metadata(META_PROGRESS, 0)
	quest.set_metadata(META_TARGET, target())
	quest.set_metadata(META_REWARD_AMOUNT, reward_amount())
	quest.set_metadata(META_REWARD_CLAIMED, false)


func _load_definition() -> Dictionary:
	var raw := FileAccess.get_file_as_string(QUEST_DATA_PATH)
	assert(not raw.is_empty(), "TAMU quest definition is missing: %s" % QUEST_DATA_PATH)
	var parsed: Variant = JSON.parse_string(raw)
	assert(parsed is Dictionary, "TAMU quest definition is not valid JSON.")
	var loaded := parsed as Dictionary
	assert(StringName(loaded.get("id", "")) == QUEST_STABLE_ID, "Unexpected TAMU quest ID.")
	var objective: Dictionary = loaded.get("objective", {})
	assert(StringName(objective.get("id", "")) == OBJECTIVE_STABLE_ID, "Unexpected TAMU objective ID.")
	assert(StringName(objective.get("item_id", "")) == ITEM_STABLE_ID, "Unexpected objective item ID.")
	assert(int(objective.get("target", 0)) > 1, "Quest target must support partial progress.")
	var reward: Dictionary = loaded.get("reward", {})
	assert(StringName(reward.get("item_id", "")) == ITEM_STABLE_ID, "Unexpected reward item ID.")
	assert(int(reward.get("amount", 0)) > 0, "Quest reward must be positive.")
	return loaded


func target() -> int:
	var objective: Dictionary = definition.get("objective", {})
	return int(objective.get("target", 0))


func reward_amount() -> int:
	var reward: Dictionary = definition.get("reward", {})
	return int(reward.get("amount", 0))


func progress() -> int:
	return int(quest.get_metadata(META_PROGRESS, 0))


func is_completed() -> bool:
	return quest.is_completed()


func is_reward_claimed() -> bool:
	return bool(quest.get_metadata(META_REWARD_CLAIMED, false))


func record_collection(item_id: StringName, amount_added: int) -> int:
	if item_id != ITEM_STABLE_ID or amount_added <= 0 or is_completed():
		return 0
	var remaining := maxi(target() - progress(), 0)
	var counted := mini(amount_added, remaining)
	if counted <= 0:
		return 0
	var next_progress := progress() + counted
	quest.set_metadata(META_PROGRESS, next_progress)
	quest.set_updated()
	if next_progress >= target():
		quest.set_completed(true)
	return counted


func claim_reward(inventory: TamuInventoryBridge) -> int:
	if not is_completed() or is_reward_claimed():
		return 0
	var amount := reward_amount()
	var added := inventory.add_to_bag_atomic(amount)
	if added != amount:
		return 0
	quest.set_metadata(META_REWARD_CLAIMED, true)
	quest.set_updated()
	return added


func default_snapshot() -> Dictionary:
	return {
		String(QUEST_STABLE_ID): {
			"objective_id": String(OBJECTIVE_STABLE_ID),
			"item_id": String(ITEM_STABLE_ID),
			"progress": 0,
			"target": target(),
			"completed": false,
			"reward_claimed": false,
		},
	}


func snapshot_all() -> Dictionary:
	return {
		String(QUEST_STABLE_ID): {
			"objective_id": String(OBJECTIVE_STABLE_ID),
			"item_id": String(ITEM_STABLE_ID),
			"progress": progress(),
			"target": target(),
			"completed": is_completed(),
			"reward_claimed": is_reward_claimed(),
		},
	}


func validate_snapshot_all(snapshot: Dictionary) -> Error:
	var quest_value: Variant = snapshot.get(String(QUEST_STABLE_ID), null)
	if typeof(quest_value) != TYPE_DICTIONARY:
		return ERR_INVALID_DATA
	var saved := quest_value as Dictionary
	if StringName(saved.get("objective_id", "")) != OBJECTIVE_STABLE_ID:
		return ERR_INVALID_DATA
	if StringName(saved.get("item_id", "")) != ITEM_STABLE_ID:
		return ERR_INVALID_DATA
	var saved_target := _strict_int(saved.get("target", null), target(), target())
	if saved_target != target():
		return ERR_INVALID_DATA
	var saved_progress := _strict_int(saved.get("progress", null), 0, target())
	if saved_progress < 0:
		return ERR_INVALID_DATA
	var completed_value: Variant = saved.get("completed", null)
	var reward_value: Variant = saved.get("reward_claimed", null)
	if typeof(completed_value) != TYPE_BOOL or typeof(reward_value) != TYPE_BOOL:
		return ERR_INVALID_DATA
	var completed := bool(completed_value)
	var reward_claimed := bool(reward_value)
	if completed != (saved_progress >= target()):
		return ERR_INVALID_DATA
	if reward_claimed and not completed:
		return ERR_INVALID_DATA
	return OK


func restore_all(snapshot: Dictionary) -> Error:
	var validation := validate_snapshot_all(snapshot)
	if validation != OK:
		return validation
	var saved := snapshot[String(QUEST_STABLE_ID)] as Dictionary
	quest.set_metadata(META_PROGRESS, int(saved.get("progress", 0)))
	quest.set_metadata(META_REWARD_CLAIMED, bool(saved.get("reward_claimed", false)))
	quest.set_completed(bool(saved.get("completed", false)))
	quest.set_updated()
	return OK


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
