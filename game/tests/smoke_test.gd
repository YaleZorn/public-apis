extends SceneTree
## Headless smoke: load content + save roundtrip + scene paths exist.

func _init() -> void:
	var ok := true
	ok = _check_files() and ok
	ok = _check_json() and ok
	ok = _check_save() and ok
	if ok:
		print("SMOKE_OK")
		quit(0)
	else:
		print("SMOKE_FAIL")
		quit(1)


func _check_files() -> bool:
	var paths := [
		"res://project.godot",
		"res://scenes/lobby/lobby.tscn",
		"res://scenes/td/td_battle.tscn",
		"res://scenes/explore/explore_run.tscn",
		"res://scenes/knowledge/knowledge_hub.tscn",
		"res://scenes/knowledge/knowledge_card.tscn",
		"res://data/content_pack_core/units.json",
		"res://data/content_pack_core/enemies.json",
		"res://data/content_pack_core/waves.json",
		"res://data/content_pack_core/rooms.json",
		"res://data/content_pack_core/knowledge.json",
		"res://data/content_pack_core/gear.json",
		"res://scenes/shell/title_screen.tscn",
		"res://resources/kongfu_theme.tres",
		"res://THIRD_PARTY.md",
		"res://scripts/td/wave_director.gd",
		"res://third_party/ape1121-godot-4-tower-defense-template/LICENSE",
	]
	for p in paths:
		if not ResourceLoader.exists(p) and not FileAccess.file_exists(p):
			push_error("Missing: %s" % p)
			return false
	print("files_ok")
	return true


func _check_json() -> bool:
	var units = JSON.parse_string(FileAccess.get_file_as_string("res://data/content_pack_core/units.json"))
	var enemies = JSON.parse_string(FileAccess.get_file_as_string("res://data/content_pack_core/enemies.json"))
	var waves = JSON.parse_string(FileAccess.get_file_as_string("res://data/content_pack_core/waves.json"))
	var rooms = JSON.parse_string(FileAccess.get_file_as_string("res://data/content_pack_core/rooms.json"))
	var knowledge = JSON.parse_string(FileAccess.get_file_as_string("res://data/content_pack_core/knowledge.json"))
	if units["units"].size() < 6:
		push_error("Need 6 units")
		return false
	if enemies["enemies"].size() < 3:
		push_error("Need 3 enemies")
		return false
	if waves["waves"].size() < 8:
		push_error("Need >=8 waves")
		return false
	if not bool(waves.get("infinite", false)):
		push_error("M1 requires infinite waves flag")
		return false
	var has_flank := false
	for w in waves["waves"]:
		for s in w.get("spawns", []):
			if str(s.get("lane", "")) == "flank":
				has_flank = true
				break
		if has_flank:
			break
	if not has_flank:
		push_error("Need at least one flank spawn in seed waves")
		return false
	if rooms["rooms"].size() < 6:
		push_error("Need >=6 rooms")
		return false
	if knowledge["entries"].size() < 15:
		push_error("Need 15 knowledge entries")
		return false
	print("json_ok units=%d enemies=%d waves=%d rooms=%d knowledge=%d infinite=%s flank=%s" % [
		units["units"].size(), enemies["enemies"].size(), waves["waves"].size(),
		rooms["rooms"].size(), knowledge["entries"].size(),
		str(waves.get("infinite", false)), str(has_flank)
	])
	return true


func _check_save() -> bool:
	var path := "user://kongfu_smoke_test.json"
	var payload := {"save_version": 1, "meta": {"unlocked_units": ["unit_feidao"]}, "resume": "lobby"}
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(payload))
	f = FileAccess.open(path, FileAccess.READ)
	var data = JSON.parse_string(f.get_as_text())
	DirAccess.remove_absolute(path)
	if str(data.get("resume", "")) != "lobby":
		push_error("Save roundtrip failed")
		return false
	print("save_ok")
	return true
