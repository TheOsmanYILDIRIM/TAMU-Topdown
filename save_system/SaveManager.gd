# Derived from CodingQuests Godot Save System v1.0.0.
# Upstream: https://github.com/CodingQuests/godot-save-system/tree/417e8baab42d44496208e40ee0bc1d9c78985419
# MIT license: res://save_system/LICENSE
#
# TAMU keeps only the slot JSON core. Persistent game IDs and live-state
# validation belong to the TAMU adapter; scene paths are never save keys.
extends Node

signal before_save(slot_id: int, state: Dictionary)
signal after_save(slot_id: int)
signal before_load(slot_id: int)
signal after_load(slot_id: int, state: Dictionary)
signal save_failed(slot_id: int, error: Error)
signal load_failed(slot_id: int, error: Error)

const SAVE_VERSION: int = 1
const SAVES_DIR: String = "user://saves"


func save_slot(slot_id: int, state: Dictionary, summary: String = "") -> Error:
	if slot_id < 0:
		return ERR_INVALID_PARAMETER

	_ensure_dir(SAVES_DIR)
	_ensure_dir(_slot_dir(slot_id))
	before_save.emit(slot_id, state)

	var saved_unix := Time.get_unix_time_from_system()
	var wrapper := {
		"version": SAVE_VERSION,
		"saved_unix": saved_unix,
		"data": state,
	}

	var err := _write_json_transactional(state_path_for_slot(slot_id), wrapper)
	if err != OK:
		save_failed.emit(slot_id, err)
		return err

	var meta := get_slot_info(slot_id)
	if meta.is_empty():
		meta["created_unix"] = saved_unix
	meta["updated_unix"] = saved_unix
	meta["slot_id"] = slot_id
	meta["version"] = SAVE_VERSION
	meta["summary"] = summary

	err = _write_json_transactional(_slot_meta_path(slot_id), meta)
	if err != OK:
		save_failed.emit(slot_id, err)
		return err

	after_save.emit(slot_id)
	return OK


func load_slot(slot_id: int) -> Dictionary:
	before_load.emit(slot_id)

	var state_path := state_path_for_slot(slot_id)
	if FileAccess.file_exists(state_path):
		var primary := _read_state_wrapper(state_path)
		if not bool(primary.get("ok", false)):
			var primary_err := int(primary.get("err", ERR_PARSE_ERROR)) as Error
			load_failed.emit(slot_id, primary_err)
			return _load_result(false, primary_err, {}, false)
		var primary_state: Dictionary = primary.get("state", {})
		after_load.emit(slot_id, primary_state)
		return _load_result(true, OK, primary_state, false)

	var backup_path := backup_path_for_slot(slot_id)
	if FileAccess.file_exists(backup_path):
		var backup := _read_state_wrapper(backup_path)
		if bool(backup.get("ok", false)):
			var backup_state: Dictionary = backup.get("state", {})
			after_load.emit(slot_id, backup_state)
			return _load_result(true, OK, backup_state, true)
		var backup_err := int(backup.get("err", ERR_PARSE_ERROR)) as Error
		load_failed.emit(slot_id, backup_err)
		return _load_result(false, backup_err, {}, false)

	load_failed.emit(slot_id, ERR_FILE_NOT_FOUND)
	return _load_result(false, ERR_FILE_NOT_FOUND, {}, false)


func get_slot_info(slot_id: int) -> Dictionary:
	var result := _read_json_dictionary(_slot_meta_path(slot_id))
	if not bool(result.get("ok", false)):
		return {}
	return result.get("value", {})


func has_save(slot_id: int) -> bool:
	return FileAccess.file_exists(state_path_for_slot(slot_id)) or FileAccess.file_exists(backup_path_for_slot(slot_id))


func delete_slot(slot_id: int) -> Error:
	var state_path := state_path_for_slot(slot_id)
	var meta_path := _slot_meta_path(slot_id)
	for path in [
		state_path,
		state_path + ".bak",
		state_path + ".tmp",
		meta_path,
		meta_path + ".bak",
		meta_path + ".tmp",
	]:
		if FileAccess.file_exists(path):
			var err := DirAccess.remove_absolute(path)
			if err != OK:
				return err
	if DirAccess.dir_exists_absolute(_slot_dir(slot_id)):
		return DirAccess.remove_absolute(_slot_dir(slot_id))
	return OK


func list_slots() -> Array[Dictionary]:
	_ensure_dir(SAVES_DIR)
	var out: Array[Dictionary] = []
	var dir := DirAccess.open(SAVES_DIR)
	if dir == null:
		return out

	dir.list_dir_begin()
	while true:
		var name := dir.get_next()
		if name == "":
			break
		if dir.current_is_dir() and name.begins_with("slot_"):
			var slot_id := int(name.trim_prefix("slot_"))
			var meta := get_slot_info(slot_id)
			if not meta.is_empty():
				out.append(meta)
	dir.list_dir_end()

	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("updated_unix", 0.0)) > float(b.get("updated_unix", 0.0))
	)
	return out


func state_path_for_slot(slot_id: int) -> String:
	return _slot_dir(slot_id) + "/state.json"


func backup_path_for_slot(slot_id: int) -> String:
	return state_path_for_slot(slot_id) + ".bak"


func temp_path_for_slot(slot_id: int) -> String:
	return state_path_for_slot(slot_id) + ".tmp"


func _slot_dir(slot_id: int) -> String:
	return "%s/slot_%04d" % [SAVES_DIR, slot_id]


func _slot_meta_path(slot_id: int) -> String:
	return _slot_dir(slot_id) + "/meta.json"


func _ensure_dir(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		DirAccess.make_dir_recursive_absolute(path)


func _load_result(ok: bool, err: Error, state: Dictionary, recovered: bool) -> Dictionary:
	return {
		"ok": ok,
		"err": err,
		"state": state,
		"recovered": recovered,
	}


func _read_state_wrapper(path: String) -> Dictionary:
	var result := _read_json_dictionary(path)
	if not bool(result.get("ok", false)):
		return {"ok": false, "err": result.get("err", ERR_PARSE_ERROR), "state": {}}

	var wrapper: Dictionary = result.get("value", {})
	var version_value: Variant = wrapper.get("version", null)
	if not _is_exact_int(version_value, SAVE_VERSION):
		return {"ok": false, "err": ERR_FILE_UNRECOGNIZED, "state": {}}

	var state_value: Variant = wrapper.get("data", null)
	if typeof(state_value) != TYPE_DICTIONARY:
		return {"ok": false, "err": ERR_INVALID_DATA, "state": {}}

	return {"ok": true, "err": OK, "state": state_value}


func _is_exact_int(value: Variant, expected: int) -> bool:
	var kind := typeof(value)
	if kind != TYPE_INT and kind != TYPE_FLOAT:
		return false
	return float(value) == float(expected)


func _read_json_dictionary(path: String) -> Dictionary:
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


func _write_json_transactional(path: String, data: Dictionary) -> Error:
	var tmp_path := path + ".tmp"
	var backup_path := path + ".bak"

	if FileAccess.file_exists(tmp_path):
		var tmp_cleanup := DirAccess.remove_absolute(tmp_path)
		if tmp_cleanup != OK:
			return tmp_cleanup

	var file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(data, "	"))
	file.flush()
	file.close()

	var tmp_check := _read_json_dictionary(tmp_path)
	if not bool(tmp_check.get("ok", false)):
		return int(tmp_check.get("err", ERR_PARSE_ERROR)) as Error

	var had_primary := FileAccess.file_exists(path)
	if had_primary:
		if FileAccess.file_exists(backup_path):
			var old_backup_cleanup := DirAccess.remove_absolute(backup_path)
			if old_backup_cleanup != OK:
				return old_backup_cleanup
		var rotate_err := DirAccess.rename_absolute(path, backup_path)
		if rotate_err != OK:
			return rotate_err

	var install_err := DirAccess.rename_absolute(tmp_path, path)
	if install_err != OK:
		if had_primary and FileAccess.file_exists(backup_path) and not FileAccess.file_exists(path):
			DirAccess.rename_absolute(backup_path, path)
		return install_err

	var installed_check := _read_json_dictionary(path)
	if not bool(installed_check.get("ok", false)):
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
		if had_primary and FileAccess.file_exists(backup_path):
			DirAccess.rename_absolute(backup_path, path)
		return int(installed_check.get("err", ERR_PARSE_ERROR)) as Error

	return OK
