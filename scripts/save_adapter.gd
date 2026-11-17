extends RefCounted
class_name TamuSaveAdapter

const PLAYER_STABLE_ID := "player:main"
const WORLD_PICKUP_STABLE_ID := "world:prototype:wood_log_pickup"


static func capture(
	player_position: Vector2,
	inventory: TamuInventoryBridge,
	pickup_taken: bool
) -> Dictionary:
	return {
		"player": {
			"id": PLAYER_STABLE_ID,
			"position": SaveUtils.vec2_to_dict(player_position),
		},
		"inventories": inventory.snapshot_all(),
		"world": {
			WORLD_PICKUP_STABLE_ID: {
				"taken": pickup_taken,
			},
		},
	}


static func decode(
	state: Dictionary,
	inventory: TamuInventoryBridge,
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

	return {
		"ok": true,
		"err": OK,
		"player_position": player_position,
		"inventories": inventories.duplicate(true),
		"pickup_taken": bool(taken_value),
	}


static func _is_number(value: Variant) -> bool:
	var kind := typeof(value)
	return kind == TYPE_INT or kind == TYPE_FLOAT


static func _failure(err: Error) -> Dictionary:
	return {
		"ok": false,
		"err": err,
	}
