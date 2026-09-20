extends Node
## Loads data-driven content packs (units/enemies/waves/rooms/knowledge/idle).

const PACK_ROOT := "res://data/content_pack_core"

var manifest: Dictionary = {}
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


func _ready() -> void:
	reload()


func reload() -> void:
	manifest = _load_json("%s/manifest.json" % PACK_ROOT)
	units.clear()
	unit_list.clear()
	var units_data: Dictionary = _load_json("%s/units.json" % PACK_ROOT)
	for u in units_data.get("units", []):
		units[u["id"]] = u
		unit_list.append(u)
	enemies.clear()
	var enemies_data: Dictionary = _load_json("%s/enemies.json" % PACK_ROOT)
	for e in enemies_data.get("enemies", []):
		enemies[e["id"]] = e
	waves_cfg = _load_json("%s/waves.json" % PACK_ROOT)
	rooms_cfg = _load_json("%s/rooms.json" % PACK_ROOT)
	knowledge.clear()
	knowledge_list.clear()
	var k_data: Dictionary = _load_json("%s/knowledge.json" % PACK_ROOT)
	knowledge_disclaimer = str(k_data.get("disclaimer", ""))
	for entry in k_data.get("entries", []):
		knowledge[entry["id"]] = entry
		knowledge_list.append(entry)
	gear.clear()
	gear_list.clear()
	var g_data: Dictionary = _load_json("%s/gear.json" % PACK_ROOT)
	for item in g_data.get("gear", []):
		gear[item["id"]] = item
		gear_list.append(item)
	idle_cfg = _load_json("%s/idle.json" % PACK_ROOT)


func get_unit(id: String) -> Dictionary:
	return units.get(id, {})


func get_enemy(id: String) -> Dictionary:
	return enemies.get(id, {})


func get_knowledge(id: String) -> Dictionary:
	return knowledge.get(id, {})


func get_gear(id: String) -> Dictionary:
	return gear.get(id, {})


func owned_pack() -> bool:
	return bool(manifest.get("owned", true))


func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("Missing content file: %s" % path)
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	var text := f.get_as_text()
	var data = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY:
		push_error("Invalid JSON object: %s" % path)
		return {}
	return data
