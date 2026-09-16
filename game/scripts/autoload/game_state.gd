extends Node
## Shared meta + run checkpoints. Tiny roster/hero hooks connecting TD & explore.

enum Mode { LOBBY, TD, EXPLORE, KNOWLEDGE }

signal meta_changed
signal checkpoint_changed

var mode: Mode = Mode.LOBBY

# --- Meta (persistent) ---
var unlocked_units: Array = ["unit_tiebi", "unit_feidao", "unit_qinggong", "unit_yishi"]
var unit_fragments: Dictionary = {} ## id -> int
var explore_hero_id: String = "unit_feidao"
var hero_mastery: Dictionary = {} ## id -> int
var knowledge_seen: Array = [] ## ids delivered
var knowledge_review_queue: Array = [] ## ids for spaced review
var knowledge_correct: Dictionary = {} ## id -> times correct
var morning_quiz_done_day: int = -1
var morning_buff_active: bool = false
var total_td_clears: int = 0
var total_explore_clears: int = 0
var silver_bank: int = 0
var gear_unlocked: Array = [] ## gear ids earned from clears
var gear_equipped: Array = ["", "", ""] ## 3 slots: 器/衣/饰

# --- Active checkpoints ---
var td_checkpoint: Dictionary = {}
var explore_checkpoint: Dictionary = {}


func _ready() -> void:
	_bootstrap_from_disk()


func _bootstrap_from_disk() -> void:
	var data := SaveManager.load_save()
	if data.is_empty():
		_init_defaults()
		persist_lobby()
		return
	_apply_meta(data.get("meta", {}))
	SettingsManager.load_from_meta(data.get("meta", {}))
	td_checkpoint = data.get("td_checkpoint", {})
	explore_checkpoint = data.get("explore_checkpoint", {})
	checkpoint_changed.emit()


func _init_defaults() -> void:
	for u in ContentDB.unit_list:
		unit_fragments[u["id"]] = 0
		hero_mastery[u["id"]] = 0
		if u.get("unlocked", false) and u["id"] not in unlocked_units:
			unlocked_units.append(u["id"])


func _apply_meta(meta: Dictionary) -> void:
	unlocked_units = meta.get("unlocked_units", unlocked_units)
	unit_fragments = meta.get("unit_fragments", unit_fragments)
	explore_hero_id = meta.get("explore_hero_id", explore_hero_id)
	hero_mastery = meta.get("hero_mastery", hero_mastery)
	knowledge_seen = meta.get("knowledge_seen", knowledge_seen)
	knowledge_review_queue = meta.get("knowledge_review_queue", knowledge_review_queue)
	knowledge_correct = meta.get("knowledge_correct", knowledge_correct)
	morning_quiz_done_day = int(meta.get("morning_quiz_done_day", -1))
	morning_buff_active = bool(meta.get("morning_buff_active", false))
	total_td_clears = int(meta.get("total_td_clears", 0))
	total_explore_clears = int(meta.get("total_explore_clears", 0))
	silver_bank = int(meta.get("silver_bank", 0))
	gear_unlocked = meta.get("gear_unlocked", gear_unlocked)
	gear_equipped = meta.get("gear_equipped", gear_equipped)
	if gear_equipped.size() < 3:
		gear_equipped.resize(3)
	SettingsManager.load_from_meta(meta)
	meta_changed.emit()


func export_meta() -> Dictionary:
	return {
		"unlocked_units": unlocked_units.duplicate(),
		"unit_fragments": unit_fragments.duplicate(),
		"explore_hero_id": explore_hero_id,
		"hero_mastery": hero_mastery.duplicate(),
		"knowledge_seen": knowledge_seen.duplicate(),
		"knowledge_review_queue": knowledge_review_queue.duplicate(),
		"knowledge_correct": knowledge_correct.duplicate(),
		"morning_quiz_done_day": morning_quiz_done_day,
		"morning_buff_active": morning_buff_active,
		"total_td_clears": total_td_clears,
		"total_explore_clears": total_explore_clears,
		"silver_bank": silver_bank,
		"gear_unlocked": gear_unlocked.duplicate(),
		"gear_equipped": gear_equipped.duplicate(),
		"settings": SettingsManager.export_settings(),
		"content_pack": ContentDB.manifest.get("content_pack", "core"),
	}


func persist_lobby() -> void:
	td_checkpoint = {}
	explore_checkpoint = {}
	SaveManager.write_save({
		"meta": export_meta(),
		"td_checkpoint": {},
		"explore_checkpoint": {},
		"resume": "lobby",
	})
	checkpoint_changed.emit()


func persist_meta_keep_checkpoints() -> void:
	SaveManager.write_save({
		"meta": export_meta(),
		"td_checkpoint": td_checkpoint,
		"explore_checkpoint": explore_checkpoint,
		"resume": resume_target(),
	})
	meta_changed.emit()


func persist_td(checkpoint: Dictionary) -> void:
	td_checkpoint = checkpoint.duplicate(true)
	explore_checkpoint = {}
	SaveManager.write_save({
		"meta": export_meta(),
		"td_checkpoint": td_checkpoint,
		"explore_checkpoint": {},
		"resume": "td",
	})
	checkpoint_changed.emit()


func persist_explore(checkpoint: Dictionary) -> void:
	explore_checkpoint = checkpoint.duplicate(true)
	td_checkpoint = {}
	SaveManager.write_save({
		"meta": export_meta(),
		"td_checkpoint": {},
		"explore_checkpoint": explore_checkpoint,
		"resume": "explore",
	})
	checkpoint_changed.emit()


func has_resume() -> bool:
	return not td_checkpoint.is_empty() or not explore_checkpoint.is_empty()


func resume_target() -> String:
	if not td_checkpoint.is_empty():
		return "td"
	if not explore_checkpoint.is_empty():
		return "explore"
	return "lobby"


func mark_knowledge_delivered(kid: String, correct: bool) -> void:
	if kid == "" or not ContentDB.knowledge.has(kid):
		return
	if kid not in knowledge_seen:
		knowledge_seen.append(kid)
	if correct:
		knowledge_correct[kid] = int(knowledge_correct.get(kid, 0)) + 1
		knowledge_review_queue.erase(kid)
	else:
		if kid not in knowledge_review_queue:
			knowledge_review_queue.append(kid)
	meta_changed.emit()


func unlock_unit(uid: String) -> void:
	if uid not in unlocked_units:
		unlocked_units.append(uid)
		meta_changed.emit()


func add_fragments(uid: String, amount: int) -> void:
	unit_fragments[uid] = int(unit_fragments.get(uid, 0)) + amount
	# Tiny unlock hook: 3 fragments unlock locked roster cards.
	if int(unit_fragments[uid]) >= 3 and uid not in unlocked_units:
		unlock_unit(uid)
	meta_changed.emit()


func add_mastery(uid: String, amount: int = 1) -> void:
	hero_mastery[uid] = int(hero_mastery.get(uid, 0)) + amount
	meta_changed.emit()


func today_key() -> int:
	var d := Time.get_date_dict_from_system()
	return int(d.year) * 10000 + int(d.month) * 100 + int(d.day)


func can_morning_quiz() -> bool:
	return morning_quiz_done_day != today_key()


func complete_morning_quiz(score: int) -> void:
	morning_quiz_done_day = today_key()
	morning_buff_active = score >= 2
	meta_changed.emit()
	persist_meta_keep_checkpoints()


func unlock_gear(gid: String) -> void:
	if gid != "" and gid not in gear_unlocked:
		gear_unlocked.append(gid)
		meta_changed.emit()


func equip_gear(slot: int, gid: String) -> void:
	if slot < 0 or slot >= 3:
		return
	if gid != "" and gid not in gear_unlocked:
		return
	gear_equipped[slot] = gid
	meta_changed.emit()
	persist_meta_keep_checkpoints()


func go_lobby() -> void:
	mode = Mode.LOBBY
	get_tree().change_scene_to_file("res://scenes/lobby/lobby.tscn")


func go_td(continue_run: bool = false) -> void:
	mode = Mode.TD
	if not continue_run:
		td_checkpoint = {}
	get_tree().change_scene_to_file("res://scenes/td/td_battle.tscn")


func go_explore(continue_run: bool = false) -> void:
	mode = Mode.EXPLORE
	if not continue_run:
		explore_checkpoint = {}
	get_tree().change_scene_to_file("res://scenes/explore/explore_run.tscn")


func go_knowledge() -> void:
	mode = Mode.KNOWLEDGE
	get_tree().change_scene_to_file("res://scenes/knowledge/knowledge_hub.tscn")
