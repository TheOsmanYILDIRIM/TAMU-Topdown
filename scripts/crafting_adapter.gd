extends RefCounted
class_name TamuCraftingAdapter

signal craft_finished(result: Dictionary)

const RECIPE_PATHS: Dictionary = {
	&"core:planks_from_log": "res://data/catalog/recipes/planks_from_log.json",
	&"core:bench_from_planks": "res://data/catalog/recipes/bench_from_planks.json",
}

var inventory: TamuInventoryBridge
var recipes: Dictionary = {}
var commands: Dictionary = {}
var active: Dictionary = {}


func _init(source: TamuInventoryBridge) -> void:
	inventory = source
	for id_value: Variant in RECIPE_PATHS.keys():
		var recipe_id := StringName(id_value)
		recipes[recipe_id] = _load_recipe(String(RECIPE_PATHS[recipe_id]), recipe_id)


func _load_recipe(path: String, expected_id: StringName) -> Dictionary:
	var raw := FileAccess.get_file_as_string(path)
	assert(not raw.is_empty(), "TAMU recipe is missing: %s" % path)
	var parsed: Variant = JSON.parse_string(raw)
	assert(parsed is Dictionary, "TAMU recipe is not valid JSON: %s" % path)
	var result := parsed as Dictionary
	assert(StringName(result.get("id", "")) == expected_id, "Unexpected TAMU recipe ID.")
	assert(int(result.get("duration_ticks", 0)) > 0, "Recipe duration must be positive.")
	return result


func recipe_ids() -> Array:
	var result: Array = recipes.keys()
	result.sort()
	return result


func recipe(recipe_id: StringName) -> Dictionary:
	if not recipes.has(recipe_id):
		return {}
	return (recipes[recipe_id] as Dictionary).duplicate(true)


func preview(recipe_id: StringName, station_tags: Array = []) -> Dictionary:
	var current := recipe(recipe_id)
	if current.is_empty():
		return {"ok": false, "status": "unsupported_recipe"}
	if not _stations_allowed(current, station_tags):
		return {"ok": false, "status": "station_required"}
	return inventory.preview_recipe(current.get("inputs", []), current.get("outputs", []))


func begin(command_id: String, recipe_id: StringName, station_tags: Array = []) -> Dictionary:
	if command_id.is_empty() or command_id.length() > 128:
		return {"ok": false, "status": "invalid_command"}
	if commands.has(command_id):
		return (commands[command_id] as Dictionary).duplicate(true)
	var current := recipe(recipe_id)
	if current.is_empty():
		return {"ok": false, "status": "unsupported_recipe"}
	var result: Dictionary
	if not active.is_empty():
		result = {"ok": false, "status": "busy"}
	elif not _stations_allowed(current, station_tags):
		result = {"ok": false, "status": "station_required"}
	else:
		var staged := inventory.preview_recipe(current.get("inputs", []), current.get("outputs", []))
		if not bool(staged.get("ok", false)):
			result = staged
		else:
			active = {
				"command_id": command_id,
				"recipe_id": String(recipe_id),
				"ticks": 0.0,
				"duration_ticks": int(current["duration_ticks"]),
			}
			result = {
				"ok": true,
				"status": "started",
				"recipe_id": String(recipe_id),
				"duration_ticks": int(current["duration_ticks"]),
			}
	commands[command_id] = result.duplicate(true)
	return result


func tick(delta: float, station_tags: Array = []) -> Dictionary:
	if not is_finite(delta) or delta < 0.0 or active.is_empty():
		return {}
	active["ticks"] = float(active["ticks"]) + minf(delta, 0.1) * 60.0
	if float(active["ticks"]) + 0.00000001 < float(active["duration_ticks"]):
		return {}

	var command_id := String(active["command_id"])
	var recipe_id := StringName(active["recipe_id"])
	var current := recipe(recipe_id)
	var result: Dictionary
	if not _stations_allowed(current, station_tags):
		result = {"ok": false, "status": "station_required"}
	else:
		result = inventory.apply_recipe_atomic(current.get("inputs", []), current.get("outputs", []))
	if bool(result.get("ok", false)):
		result["recipe_id"] = String(recipe_id)
		result["duration_ticks"] = int(current["duration_ticks"])
		result["outputs"] = (current.get("outputs", []) as Array).duplicate(true)
	commands[command_id] = result.duplicate(true)
	active = {}
	craft_finished.emit(result)
	return result


func progress() -> float:
	if active.is_empty():
		return 0.0
	return minf(1.0, float(active["ticks"]) / float(active["duration_ticks"]))


func is_active() -> bool:
	return not active.is_empty()


func _stations_allowed(current: Dictionary, station_tags: Array) -> bool:
	var present: Dictionary = {}
	for tag_value: Variant in station_tags:
		present[StringName(tag_value)] = true
	for required_value: Variant in current.get("station_tags", []):
		if not present.has(StringName(required_value)):
			return false
	return true
