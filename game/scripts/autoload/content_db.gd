extends Node
## Multi content_pack loader: core + optional packs under res://data/content_pack_*.
## Offline, no IAP — ownership is local manifest.owned (or GameState.owned_content_packs).

const DATA_ROOT := "res://data"
const CORE_PACK_ID := "core"

## Primary / merged views (owned packs only)
var manifest: Dictionary = {} ## core-or-primary manifest (compat)
var packs: Array = [] ## all discovered pack manifests (owned + unowned)
var pack_by_id: Dictionary = {} ## id -> manifest
var loaded_pack_ids: Array = [] ## owned packs that contributed data

var units: Dictionary = {} ## id -> unit dict
var unit_list: Array = []
var enemies: Dictionary = {}
var waves_cfg: Dictionary = {}
var rooms_cfg: Dictionary = {}
var knowledge: Dictionary = {} ## id -> entry
var knowledge_list: Array = []
var knowledge_disclaimer: String = ""
var gear: Dictionary = {} ## id -> gear dict
var gear_list: Array = []
var idle_cfg: Dictionary = {}
var materials: Dictionary = {} ## id -> material dict
var material_list: Array = []
var recipes: Array = [] ## craft recipe dicts
var arena_cfg: Dictionary = {}
var tower_cfg: Dictionary = {}


func _ready() -> void:
	reload()


func reload() -> void:
	_clear_indexes()
	packs.clear()
	pack_by_id.clear()
	loaded_pack_ids.clear()
	var dirs := _discover_pack_dirs()
	# Core first, then others alphabetically.
	dirs.sort_custom(func(a, b):
		var aid := _pack_id_from_dir(a)
		var bid := _pack_id_from_dir(b)
		if aid == CORE_PACK_ID:
			return true
		if bid == CORE_PACK_ID:
			return false
		return aid < bid
	)
	for dir_path in dirs:
		var man: Dictionary = _load_json("%s/manifest.json" % dir_path)
		if man.is_empty():
			continue
		var pid := str(man.get("content_pack", _pack_id_from_dir(dir_path)))
		man["content_pack"] = pid
		man["_path"] = dir_path
		packs.append(man)
		pack_by_id[pid] = man
	# Merge owned packs
	for man in packs:
		var pid := str(man.get("content_pack", ""))
		if not is_pack_owned(pid):
			continue
		_merge_pack(str(man.get("_path", "")), man)
		loaded_pack_ids.append(pid)
	# Compat: expose core (or first loaded) as manifest
	if pack_by_id.has(CORE_PACK_ID):
		manifest = pack_by_id[CORE_PACK_ID].duplicate()
	elif not packs.is_empty():
		manifest = packs[0].duplicate()
	else:
		manifest = {}
	manifest["loaded_packs"] = loaded_pack_ids.duplicate()


func _clear_indexes() -> void:
	units.clear()
	unit_list.clear()
	enemies.clear()
	waves_cfg = {}
	rooms_cfg = {}
	knowledge.clear()
	knowledge_list.clear()
	knowledge_disclaimer = ""
	gear.clear()
	gear_list.clear()
	idle_cfg = {}
	materials.clear()
	material_list.clear()
	recipes.clear()
	arena_cfg = {}
	tower_cfg = {}


func _discover_pack_dirs() -> Array:
	var out: Array = []
	var da := DirAccess.open(DATA_ROOT)
	if da == null:
		push_error("Missing data root: %s" % DATA_ROOT)
		return out
	da.list_dir_begin()
	var name := da.get_next()
	while name != "":
		if da.current_is_dir() and name.begins_with("content_pack_"):
			out.append("%s/%s" % [DATA_ROOT, name])
		name = da.get_next()
	da.list_dir_end()
	# Fallback if DirAccess misses packed res:// listing
	if out.is_empty():
		for fallback in ["content_pack_core", "content_pack_demo_mountain"]:
			var p := "%s/%s" % [DATA_ROOT, fallback]
			if FileAccess.file_exists("%s/manifest.json" % p):
				out.append(p)
	return out


func _pack_id_from_dir(dir_path: String) -> String:
	var base := dir_path.get_file()
	if base.begins_with("content_pack_"):
		return base.substr("content_pack_".length())
	return base


func is_pack_owned(pack_id: String) -> bool:
	if pack_id == CORE_PACK_ID or pack_id == "":
		return true
	var man: Dictionary = pack_by_id.get(pack_id, {})
	if bool(man.get("owned", false)):
		return true
	# Optional runtime unlock list (no store billing — local only).
	if typeof(GameState) != TYPE_NIL and GameState.has_method("owns_content_pack"):
		return GameState.owns_content_pack(pack_id)
	return false


func owned_pack() -> bool:
	## Compat: true if core (or primary) owned.
	return is_pack_owned(str(manifest.get("content_pack", CORE_PACK_ID)))


func list_packs() -> Array:
	return packs.duplicate(true)


func get_pack_manifest(pack_id: String) -> Dictionary:
	return pack_by_id.get(pack_id, {})


func _merge_pack(dir_path: String, man: Dictionary) -> void:
	var modules: Array = man.get("modules", [])
	var pid := str(man.get("content_pack", ""))
	if modules.is_empty() or "units" in modules:
		_merge_units("%s/units.json" % dir_path, pid)
	if modules.is_empty() or "enemies" in modules:
		_merge_enemies("%s/enemies.json" % dir_path)
	if modules.is_empty() or "waves" in modules:
		var w: Dictionary = _load_json("%s/waves.json" % dir_path)
		if not w.is_empty():
			waves_cfg = w # last-write / core typically first then overlays replace table
	if modules.is_empty() or "rooms" in modules:
		var r: Dictionary = _load_json("%s/rooms.json" % dir_path)
		if not r.is_empty():
			rooms_cfg = r
	if modules.is_empty() or "knowledge" in modules:
		_merge_knowledge("%s/knowledge.json" % dir_path, pid)
	if modules.is_empty() or "gear" in modules:
		_merge_gear("%s/gear.json" % dir_path, pid)
	if modules.is_empty() or "idle" in modules:
		var idle: Dictionary = _load_json("%s/idle.json" % dir_path)
		if not idle.is_empty():
			idle_cfg = idle
	if modules.is_empty() or "materials" in modules:
		_merge_materials("%s/materials.json" % dir_path)
	if modules.is_empty() or "arena" in modules:
		var a: Dictionary = _load_json("%s/arena.json" % dir_path)
		if not a.is_empty():
			arena_cfg = a
	if modules.is_empty() or "tower" in modules:
		var t: Dictionary = _load_json("%s/tower.json" % dir_path)
		if not t.is_empty():
			tower_cfg = t


func _merge_units(path: String, pack_id: String) -> void:
	var data: Dictionary = _load_json(path)
	for u in data.get("units", []):
		var uid := str(u.get("id", ""))
		if uid == "":
			continue
		u["content_pack"] = str(u.get("content_pack", pack_id))
		units[uid] = u
		# Replace in list if redefining
		var replaced := false
		for i in unit_list.size():
			if str(unit_list[i].get("id", "")) == uid:
				unit_list[i] = u
				replaced = true
				break
		if not replaced:
			unit_list.append(u)


func _merge_enemies(path: String) -> void:
	var data: Dictionary = _load_json(path)
	for e in data.get("enemies", []):
		enemies[e["id"]] = e


func _merge_knowledge(path: String, pack_id: String) -> void:
	var k_data: Dictionary = _load_json(path)
	if k_data.is_empty():
		return
	var disc := str(k_data.get("disclaimer", ""))
	if disc != "" and knowledge_disclaimer == "":
		knowledge_disclaimer = disc
	elif disc != "" and disc not in knowledge_disclaimer:
		knowledge_disclaimer = knowledge_disclaimer + " " + disc
	for entry in k_data.get("entries", []):
		var kid := str(entry.get("id", ""))
		if kid == "":
			continue
		entry["content_pack"] = str(entry.get("content_pack", pack_id))
		_normalize_knowledge_entry(entry)
		knowledge[kid] = entry
		var replaced := false
		for i in knowledge_list.size():
			if str(knowledge_list[i].get("id", "")) == kid:
				knowledge_list[i] = entry
				replaced = true
				break
		if not replaced:
			knowledge_list.append(entry)


func _normalize_knowledge_entry(entry: Dictionary) -> void:
	## Ensure td_hook / explore_hook / mode_hooks stay in sync.
	var hooks: Array = entry.get("mode_hooks", [])
	if hooks.is_empty():
		hooks = []
		if str(entry.get("td_hook", "")) != "":
			hooks.append({"mode": "td", "hook": entry["td_hook"]})
		if str(entry.get("explore_hook", "")) != "":
			hooks.append({"mode": "explore", "hook": entry["explore_hook"]})
		if str(entry.get("tower_hook", "")) != "":
			hooks.append({"mode": "tower", "hook": entry["tower_hook"]})
		if str(entry.get("arena_hook", "")) != "":
			hooks.append({"mode": "arena", "hook": entry["arena_hook"]})
		entry["mode_hooks"] = hooks
	else:
		for h in hooks:
			var mode := str(h.get("mode", ""))
			var hook := str(h.get("hook", ""))
			if mode == "td" and str(entry.get("td_hook", "")) == "":
				entry["td_hook"] = hook
			elif mode == "explore" and str(entry.get("explore_hook", "")) == "":
				entry["explore_hook"] = hook
			elif mode == "tower" and str(entry.get("tower_hook", "")) == "":
				entry["tower_hook"] = hook
			elif mode == "arena" and str(entry.get("arena_hook", "")) == "":
				entry["arena_hook"] = hook


func _merge_gear(path: String, pack_id: String) -> void:
	var g_data: Dictionary = _load_json(path)
	for item in g_data.get("gear", []):
		var gid := str(item.get("id", ""))
		if gid == "":
			continue
		item["content_pack"] = str(item.get("content_pack", pack_id))
		gear[gid] = item
		var replaced := false
		for i in gear_list.size():
			if str(gear_list[i].get("id", "")) == gid:
				gear_list[i] = item
				replaced = true
				break
		if not replaced:
			gear_list.append(item)


func _merge_materials(path: String) -> void:
	var m_data: Dictionary = _load_json(path)
	for item in m_data.get("materials", []):
		var mid := str(item.get("id", ""))
		if mid == "":
			continue
		materials[mid] = item
		var replaced := false
		for i in material_list.size():
			if str(material_list[i].get("id", "")) == mid:
				material_list[i] = item
				replaced = true
				break
		if not replaced:
			material_list.append(item)
	for r in m_data.get("recipes", []):
		recipes.append(r)


func get_unit(id: String) -> Dictionary:
	return units.get(id, {})


func get_enemy(id: String) -> Dictionary:
	return enemies.get(id, {})


func get_knowledge(id: String) -> Dictionary:
	return knowledge.get(id, {})


func get_gear(id: String) -> Dictionary:
	return gear.get(id, {})


func get_material(id: String) -> Dictionary:
	return materials.get(id, {})


func get_node_cfg(node_id: String) -> Dictionary:
	for n in rooms_cfg.get("nodes", []):
		if str(n.get("id", "")) == node_id:
			return n
	return {}


func get_tower_floor(floor_n: int) -> Dictionary:
	for f in tower_cfg.get("floors", []):
		if int(f.get("floor", 0)) == floor_n:
			return f
	return {}


func exclusive_gear_ids() -> Array:
	var out: Array = []
	for g in gear_list:
		if bool(g.get("exclusive", false)) or str(g.get("pool", "")) == "tower_exclusive":
			out.append(str(g.get("id", "")))
	return out


func knowledge_hook(entry_id: String, mode: String) -> String:
	var entry: Dictionary = get_knowledge(entry_id)
	if entry.is_empty():
		return ""
	match mode:
		"td":
			return str(entry.get("td_hook", ""))
		"explore":
			return str(entry.get("explore_hook", ""))
		"tower":
			return str(entry.get("tower_hook", ""))
		"arena":
			return str(entry.get("arena_hook", ""))
	for h in entry.get("mode_hooks", []):
		if str(h.get("mode", "")) == mode:
			return str(h.get("hook", ""))
	return ""


func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	var text := f.get_as_text()
	var data = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY:
		push_error("Invalid JSON object: %s" % path)
		return {}
	return data
