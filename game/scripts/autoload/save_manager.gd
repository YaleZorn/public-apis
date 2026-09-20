extends Node
## Local single-slot save with version migration. Checkpoints at wave/room/lobby.

const SAVE_PATH := "user://kongfu_save_v0.json"
const SAVE_VERSION := 4

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
		v = 1
	if v < 2:
		# M2 Idle: ensure meta keys exist; accrual starts from saved_at or now.
		var meta: Dictionary = data.get("meta", {})
		if not meta.has("xiuwei_bank"):
			meta["xiuwei_bank"] = 0
		if not meta.has("materials_draft"):
			meta["materials_draft"] = 0
		if not meta.has("training_level"):
			meta["training_level"] = {}
		if not meta.has("training_slots"):
			meta["training_slots"] = []
		if not meta.has("idle_last_unix"):
			meta["idle_last_unix"] = float(data.get("saved_at", Time.get_unix_time_from_system()))
		if not meta.has("idle_pending_silver"):
			meta["idle_pending_silver"] = 0.0
		if not meta.has("idle_pending_xiuwei"):
			meta["idle_pending_xiuwei"] = 0.0
		if not meta.has("idle_pending_materials"):
			meta["idle_pending_materials"] = 0.0
		data["meta"] = meta
		data["save_version"] = 2
		v = 2
	if v < 3:
		# M3 explore: typed materials inventory + craft flags.
		var meta3: Dictionary = data.get("meta", {})
		if not meta3.has("materials_inv"):
			meta3["materials_inv"] = {}
		if not meta3.has("wuxue_drafts"):
			meta3["wuxue_drafts"] = 0
		data["meta"] = meta3
		data["save_version"] = 3
		v = 3
	if v < 4:
		# M4/M5: arena + tower meta / checkpoints.
		var meta4: Dictionary = data.get("meta", {})
		if not meta4.has("total_arena_runs"):
			meta4["total_arena_runs"] = 0
		if not meta4.has("arena_best_sec"):
			meta4["arena_best_sec"] = 0.0
		if not meta4.has("tower_floor_cleared"):
			meta4["tower_floor_cleared"] = 0
		data["meta"] = meta4
		if not data.has("arena_checkpoint"):
			data["arena_checkpoint"] = {}
		if not data.has("tower_checkpoint"):
			data["tower_checkpoint"] = {}
		data["save_version"] = 4
	return data
