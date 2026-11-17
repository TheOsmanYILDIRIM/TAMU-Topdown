class_name TamuAudioSettings
extends RefCounted

# Narrow audio-persistence core adapted from Settings + Menus.
# Upstream: https://github.com/seloc0des/godot-settings-menus/tree/ae448556b154a71ee63661fbca4141546db356d4
# MIT license: res://addons/settings_menus/LICENSE
#
# TAMU deliberately keeps this outside SaveManager and user://saves so audio
# preferences survive slot changes without becoming part of gameplay state.

const SOURCE_COMMIT := "ae448556b154a71ee63661fbca4141546db356d4"
const SETTINGS_VERSION: int = 1
const DEFAULT_SAVE_FILE := "user://tamu_audio_settings.json"
const DEFAULT_LEVELS: Dictionary = {
	"master": 1.0,
	"music": 1.0,
	"sfx": 1.0,
}
const BUS_NAMES: Dictionary = {
	"master": "Master",
	"music": "Music",
	"sfx": "SFX",
}

var save_file: String = DEFAULT_SAVE_FILE
var _levels: Dictionary = DEFAULT_LEVELS.duplicate(true)


func _init(path: String = DEFAULT_SAVE_FILE) -> void:
	save_file = path


func get_level(bus_key: String) -> float:
	return float(_levels.get(bus_key.to_lower(), 1.0))


func levels_snapshot() -> Dictionary:
	return _levels.duplicate(true)


func set_level(bus_key: String, value: float, persist: bool = true) -> Error:
	var key := bus_key.to_lower()
	if not DEFAULT_LEVELS.has(key):
		return ERR_INVALID_PARAMETER
	_levels[key] = clampf(value, 0.0, 1.0)
	_apply_one(key)
	if persist:
		return save_settings()
	return OK


func reset_to_defaults(persist: bool = false) -> Error:
	_levels = DEFAULT_LEVELS.duplicate(true)
	apply_all()
	if persist:
		return save_settings()
	return OK


func load_and_apply() -> Error:
	_levels = DEFAULT_LEVELS.duplicate(true)
	if not FileAccess.file_exists(save_file):
		apply_all()
		return OK

	var parsed := _read_dictionary(save_file)
	if not bool(parsed.get("ok", false)):
		apply_all()
		return int(parsed.get("err", ERR_PARSE_ERROR)) as Error

	var wrapper: Dictionary = parsed.get("value", {})
	var version_value: Variant = wrapper.get("version", null)
	if not _is_exact_int(version_value, SETTINGS_VERSION):
		apply_all()
		return ERR_FILE_UNRECOGNIZED

	var audio_value: Variant = wrapper.get("audio", null)
	if typeof(audio_value) != TYPE_DICTIONARY:
		apply_all()
		return ERR_INVALID_DATA

	var audio := audio_value as Dictionary
	for key_value: Variant in DEFAULT_LEVELS.keys():
		var key := String(key_value)
		var raw: Variant = audio.get(key, DEFAULT_LEVELS[key])
		if typeof(raw) == TYPE_FLOAT or typeof(raw) == TYPE_INT:
			_levels[key] = clampf(float(raw), 0.0, 1.0)
		else:
			_levels[key] = float(DEFAULT_LEVELS[key])
	apply_all()
	return OK


func save_settings() -> Error:
	var tmp_path := save_file + ".tmp"
	var backup_path := save_file + ".bak"
	_remove_if_exists(tmp_path)

	var file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	var wrapper := {
		"version": SETTINGS_VERSION,
		"audio": _levels.duplicate(true),
	}
	file.store_string(JSON.stringify(wrapper, "  "))
	file.flush()
	file.close()

	var verify := _read_dictionary(tmp_path)
	if not bool(verify.get("ok", false)):
		_remove_if_exists(tmp_path)
		return int(verify.get("err", ERR_PARSE_ERROR)) as Error

	_remove_if_exists(backup_path)
	var had_primary := FileAccess.file_exists(save_file)
	if had_primary:
		var rotate_err := DirAccess.rename_absolute(_absolute(save_file), _absolute(backup_path))
		if rotate_err != OK:
			_remove_if_exists(tmp_path)
			return rotate_err

	var install_err := DirAccess.rename_absolute(_absolute(tmp_path), _absolute(save_file))
	if install_err != OK:
		if had_primary and FileAccess.file_exists(backup_path) and not FileAccess.file_exists(save_file):
			DirAccess.rename_absolute(_absolute(backup_path), _absolute(save_file))
		return install_err

	var installed := _read_dictionary(save_file)
	if not bool(installed.get("ok", false)):
		_remove_if_exists(save_file)
		if had_primary and FileAccess.file_exists(backup_path):
			DirAccess.rename_absolute(_absolute(backup_path), _absolute(save_file))
		return int(installed.get("err", ERR_PARSE_ERROR)) as Error

	_remove_if_exists(backup_path)
	return OK


func apply_all() -> void:
	for key_value: Variant in DEFAULT_LEVELS.keys():
		_apply_one(String(key_value))


func _apply_one(bus_key: String) -> void:
	var index := _ensure_bus(bus_key)
	if index < 0:
		return
	var value := get_level(bus_key)
	if value <= 0.0001:
		AudioServer.set_bus_mute(index, true)
		return
	AudioServer.set_bus_mute(index, false)
	AudioServer.set_bus_volume_db(index, linear_to_db(value))


func _ensure_bus(bus_key: String) -> int:
	var index := _bus_index(bus_key)
	if index >= 0:
		return index
	if bus_key == "master":
		return -1
	index = AudioServer.bus_count
	AudioServer.add_bus(index)
	AudioServer.set_bus_name(index, String(BUS_NAMES[bus_key]))
	AudioServer.set_bus_send(index, &"Master")
	return index


func _bus_index(bus_key: String) -> int:
	for index: int in range(AudioServer.bus_count):
		if AudioServer.get_bus_name(index).to_lower() == bus_key.to_lower():
			return index
	return -1


func _read_dictionary(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false, "err": FileAccess.get_open_error(), "value": {}}
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	var parse_err := json.parse(text)
	if parse_err != OK:
		return {"ok": false, "err": ERR_PARSE_ERROR, "value": {}}
	if typeof(json.data) != TYPE_DICTIONARY:
		return {"ok": false, "err": ERR_INVALID_DATA, "value": {}}
	return {"ok": true, "err": OK, "value": json.data}


func _is_exact_int(value: Variant, expected: int) -> bool:
	var kind := typeof(value)
	if kind != TYPE_INT and kind != TYPE_FLOAT:
		return false
	return float(value) == float(expected)


func _remove_if_exists(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(_absolute(path))


func _absolute(path: String) -> String:
	return ProjectSettings.globalize_path(path)
