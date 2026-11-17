extends RefCounted
class_name TamuSaveAdapter

const PLAYER_STABLE_ID := "player:main"
const WORLD_PICKUP_STABLE_ID := "world:prototype:wood_log_pickup"
const WORLD_PICKUP_TWO_STABLE_ID := "world:prototype:wood_log_pickup_two"


static func capture(
	player_position: Vector2,
	inventory: TamuInventoryBridge,
	pickup_taken: bool,
	pickup_two_taken: bool,
	quests: TamuQuestBridge
) -> Dictionary:
	return {
		"player": {
			"id": PLAYER_STABLE_ID,
			"position": SaveUtils.vec2_to_dict(player_position),
		},
		"inventories": inventory.snapshot_all(),
		"world": {
			WORLD_PICKUP_STABLE_ID: {"taken": pickup_taken},
			WORLD_PICKUP_TWO_STABLE_ID: {"taken": pickup_two_taken},
		},
		"quests": quests.snapshot_all(),
	}


static func decode(
	state: Dictionary,
	inventory: TamuInventoryBridge,
	quests: TamuQuestBridge,
	player_bounds: Rect2
) -> Dictionary:
	var player_value: Variant = state.get("player", null)
	if typeof(player_value) != TYPE_DICTIONARY:
		return _failure(ERR_INVALID_DATA)
	var player_data := player_value as Dictionary
	if String(player_data.get("id", "")) != PLAYER_STABLE_ID:
		return _failure(ERR_INVALID_DATA)

	var position_value: Variant = player_data.get("position", null)
	if typeof(position_value) != TYPE_DICTIONARY:
		return _failure(ERR_INVALID_DATA)
	var position_data := position_value as Dictionary
	if not _is_number(position_data.get("x", null)) or not _is_number(position_data.get("y", null)):
		return _failure(ERR_INVALID_DATA)
	var player_position := SaveUtils.dict_to_vec2(position_data)
	if not player_bounds.has_point(player_position):
		return _failure(ERR_INVALID_DATA)

	var inventories_value: Variant = state.get("inventories", null)
	if typeof(inventories_value) != TYPE_DICTIONARY:
		return _failure(ERR_INVALID_DATA)
	var inventories := inventories_value as Dictionary
	var inventory_err := inventory.validate_snapshot_all(inventories)
	if inventory_err != OK:
		return _failure(inventory_err)

	var world_value: Variant = state.get("world", null)
	if typeof(world_value) != TYPE_DICTIONARY:
		return _failure(ERR_INVALID_DATA)
	var world := world_value as Dictionary
	var pickup_value: Variant = world.get(WORLD_PICKUP_STABLE_ID, null)
	if typeof(pickup_value) != TYPE_DICTIONARY:
		return _failure(ERR_INVALID_DATA)
	var pickup := pickup_value as Dictionary
	var taken_value: Variant = pickup.get("taken", null)
	if typeof(taken_value) != TYPE_BOOL:
		return _failure(ERR_INVALID_DATA)

	var pickup_two_taken := false
	if world.has(WORLD_PICKUP_TWO_STABLE_ID):
		var pickup_two_value: Variant = world.get(WORLD_PICKUP_TWO_STABLE_ID)
		if typeof(pickup_two_value) != TYPE_DICTIONARY:
			return _failure(ERR_INVALID_DATA)
		var pickup_two := pickup_two_value as Dictionary
		var pickup_two_taken_value: Variant = pickup_two.get("taken", null)
		if typeof(pickup_two_taken_value) != TYPE_BOOL:
			return _failure(ERR_INVALID_DATA)
		pickup_two_taken = bool(pickup_two_taken_value)

	var quest_snapshot: Dictionary
	if state.has("quests"):
		var quests_value: Variant = state.get("quests", null)
		if typeof(quests_value) != TYPE_DICTIONARY:
			return _failure(ERR_INVALID_DATA)
		quest_snapshot = (quests_value as Dictionary).duplicate(true)
		var quest_err := quests.validate_snapshot_all(quest_snapshot)
		if quest_err != OK:
			return _failure(quest_err)
	else:
		quest_snapshot = quests.default_snapshot()

	return {
		"ok": true,
		"err": OK,
		"player_position": player_position,
		"inventories": inventories.duplicate(true),
		"pickup_taken": bool(taken_value),
		"pickup_two_taken": pickup_two_taken,
		"quests": quest_snapshot,
	}


static func _is_number(value: Variant) -> bool:
	var kind := typeof(value)
	return kind == TYPE_INT or kind == TYPE_FLOAT


static func _failure(err: Error) -> Dictionary:
	return {"ok": false, "err": err}
