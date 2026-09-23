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
		"res://scenes/idle/idle_hub.tscn",
		"res://scenes/td/td_battle.tscn",
		"res://scenes/explore/explore_run.tscn",
		"res://scenes/arena/arena_run.tscn",
		"res://scenes/tower/tower_run.tscn",
		"res://scenes/knowledge/knowledge_hub.tscn",
		"res://scenes/knowledge/knowledge_card.tscn",
		"res://data/content_pack_core/units.json",
		"res://data/content_pack_core/idle.json",
		"res://data/content_pack_core/enemies.json",
		"res://data/content_pack_core/waves.json",
		"res://data/content_pack_core/rooms.json",
		"res://data/content_pack_core/materials.json",
		"res://data/content_pack_core/arena.json",
		"res://data/content_pack_core/tower.json",
		"res://data/content_pack_core/knowledge.json",
		"res://data/content_pack_core/gear.json",
		"res://data/content_pack_demo_mountain/manifest.json",
		"res://data/content_pack_demo_mountain/units.json",
		"res://data/content_pack_demo_mountain/knowledge.json",
		"res://data/content_pack_demo_mountain/gear.json",
		"res://data/CONTENT_PACKS.md",
		"res://scenes/shell/title_screen.tscn",
		"res://resources/kongfu_theme.tres",
		"res://THIRD_PARTY.md",
		"res://scripts/td/wave_director.gd",
		"res://scripts/idle/idle_hub.gd",
		"res://scripts/explore/run_bag.gd",
		"res://scripts/combat/auto_combat_ring.gd",
		"res://scripts/util/state_vfx.gd",
		"res://scripts/arena/arena_run.gd",
		"res://scripts/tower/tower_run.gd",
		"res://assets/textures/figures/unit_qinggong_reveal.png",
		"res://assets/textures/figures/unit_mulan_reveal.png",
		"res://assets/textures/vfx/aura_ring_soft.png",
		"res://assets/textures/vfx/aura_ink_wash.png",
		"res://assets/textures/vfx/aura_ink_wisp.png",
		"res://assets/textures/vfx/slash_trail_long.png",
		"res://assets/textures/figures/unit_qinggong_reveal_mid.png",
		"res://assets/textures/vfx/slash_trail.png",
		"res://assets/textures/vfx/burst_flash.png",
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
	# M2: named celebrities (not anonymous blobs) + idle rates.
	var named := 0
	for u in units["units"]:
		var n := str(u.get("name", ""))
		if n == "" or "护卫" in n or "弟子" in n or "学徒" in n:
			# Allow only if historical_tag present — but prefer real names.
			pass
		if str(u.get("historical_tag", "")) != "" and u.has("idle"):
			named += 1
		if not u.has("idle"):
			push_error("Unit missing idle block: %s" % u.get("id", "?"))
			return false
		if not u.has("vfx") or typeof(u.get("vfx")) != TYPE_DICTIONARY:
			push_error("Unit missing vfx hooks: %s" % u.get("id", "?"))
			return false
		var vfx: Dictionary = u.get("vfx", {})
		if str(vfx.get("reveal", "")) == "" or not vfx.has("reveal_on"):
			push_error("Unit vfx incomplete: %s" % u.get("id", "?"))
			return false
	if named < 6:
		push_error("Need >=6 named celebrities with historical_tag+idle, got %d" % named)
		return false
	var idle = JSON.parse_string(FileAccess.get_file_as_string("res://data/content_pack_core/idle.json"))
	if typeof(idle) != TYPE_DICTIONARY or float(idle.get("offline_cap_hours", 0)) <= 0:
		push_error("idle.json missing or invalid cap")
		return false
	if int(idle.get("training_slot_count", 0)) < 1:
		push_error("Need training slots")
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
	if rooms.get("nodes", rooms.get("rooms", [])).size() < 6:
		push_error("Need >=6 explore nodes")
		return false
	var node_types := {}
	for n in rooms.get("nodes", []):
		node_types[str(n.get("type", ""))] = true
	for need_t in ["settle", "gather", "combat"]:
		if not node_types.has(need_t):
			push_error("Need node type %s for 搜打撤" % need_t)
			return false
	var mats = JSON.parse_string(FileAccess.get_file_as_string("res://data/content_pack_core/materials.json"))
	if typeof(mats) != TYPE_DICTIONARY or mats.get("materials", []).size() < 3:
		push_error("Need materials.json with >=3 materials")
		return false
	if mats.get("recipes", []).size() < 1:
		push_error("Need at least one craft recipe")
		return false
	var arena = JSON.parse_string(FileAccess.get_file_as_string("res://data/content_pack_core/arena.json"))
	if typeof(arena) != TYPE_DICTIONARY or not arena.has("enemy_pool"):
		push_error("arena.json missing enemy_pool")
		return false
	var tower = JSON.parse_string(FileAccess.get_file_as_string("res://data/content_pack_core/tower.json"))
	if typeof(tower) != TYPE_DICTIONARY or tower.get("floors", []).size() < 5:
		push_error("tower.json need >=5 floors")
		return false
	var has_exclusive_floor := false
	for f in tower.get("floors", []):
		var roll = f.get("exclusive_roll", null)
		if typeof(roll) == TYPE_DICTIONARY and str(roll.get("gear_id", "")) != "":
			has_exclusive_floor = true
			break
	if not has_exclusive_floor:
		push_error("tower needs an exclusive_roll floor")
		return false
	var gear = JSON.parse_string(FileAccess.get_file_as_string("res://data/content_pack_core/gear.json"))
	var exclusive_gear := 0
	for item in gear.get("gear", []):
		if bool(item.get("exclusive", false)) or str(item.get("pool", "")) == "tower_exclusive":
			exclusive_gear += 1
	if exclusive_gear < 1:
		push_error("Need >=1 tower exclusive gear")
		return false
	if knowledge["entries"].size() < 30:
		push_error("Need >=30 knowledge entries in core, got %d" % knowledge["entries"].size())
		return false
	var demo_man = JSON.parse_string(FileAccess.get_file_as_string("res://data/content_pack_demo_mountain/manifest.json"))
	if typeof(demo_man) != TYPE_DICTIONARY or str(demo_man.get("content_pack", "")) != "demo_mountain":
		push_error("demo mountain pack manifest missing")
		return false
	if not bool(demo_man.get("owned", false)):
		push_error("demo pack should be owned locally (no IAP)")
		return false
	var demo_k = JSON.parse_string(FileAccess.get_file_as_string("res://data/content_pack_demo_mountain/knowledge.json"))
	var demo_u = JSON.parse_string(FileAccess.get_file_as_string("res://data/content_pack_demo_mountain/units.json"))
	var demo_g = JSON.parse_string(FileAccess.get_file_as_string("res://data/content_pack_demo_mountain/gear.json"))
	if demo_k.get("entries", []).size() < 3:
		push_error("demo pack need >=3 knowledge")
		return false
	if demo_u.get("units", []).size() < 1:
		push_error("demo pack need >=1 unit")
		return false
	if demo_g.get("gear", []).size() < 1:
		push_error("demo pack need >=1 gear")
		return false
	print("json_ok units=%d named_idle=%d enemies=%d waves=%d nodes=%d mats=%d knowledge=%d demo_k=%d arena_pool=%d tower_floors=%d exclusive_gear=%d infinite=%s flank=%s" % [
		units["units"].size(), named, enemies["enemies"].size(), waves["waves"].size(),
		rooms.get("nodes", []).size(), mats["materials"].size(), knowledge["entries"].size(),
		demo_k["entries"].size(),
		arena.get("enemy_pool", []).size(), tower.get("floors", []).size(), exclusive_gear,
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
