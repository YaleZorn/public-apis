extends Node
## Local single-slot save with version migration. Checkpoints at wave/room/lobby.

const SAVE_PATH := "user://kongfu_save_v0.json"
const SAVE_VERSION := 1

signal save_written
signal save_loaded


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func load_save() -> Dictionary:
	if not has_save():
		return {}
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return {}
	data = _migrate(data)
	save_loaded.emit()
	return data


func write_save(payload: Dictionary) -> void:
	payload["save_version"] = SAVE_VERSION
	payload["saved_at"] = Time.get_unix_time_from_system()
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(payload, "\t"))
	save_written.emit()


func clear_save() -> void:
	if has_save():
		DirAccess.remove_absolute(SAVE_PATH)


func _migrate(data: Dictionary) -> Dictionary:
	var v := int(data.get("save_version", 0))
	if v < 1:
		data["save_version"] = 1
	# Future migrations chain here by content_pack / schema version.
	return data
