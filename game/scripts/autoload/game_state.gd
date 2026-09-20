extends Node
## Shared meta + run checkpoints. Idle celebrity roster feeds TD & explore.

enum Mode { LOBBY, TD, EXPLORE, KNOWLEDGE, IDLE, ARENA, TOWER }

signal meta_changed
signal checkpoint_changed

var mode: Mode = Mode.LOBBY

# --- Meta (persistent) ---
var unlocked_units: Array = ["unit_tiebi", "unit_feidao", "unit_qinggong", "unit_yishi"]
var unit_fragments: Dictionary = {} ## id -> int
var explore_hero_id: String = "unit_feidao"
var hero_mastery: Dictionary = {} ## id -> int (TD atk weight + unlock weight)
var training_level: Dictionary = {} ## id -> int proficiency from Idle slots
var knowledge_seen: Array = [] ## ids delivered
var knowledge_review_queue: Array = [] ## ids needing review (wrong / due)
var knowledge_correct: Dictionary = {} ## id -> times correct
var knowledge_due: Dictionary = {} ## id -> unix due (spaced review)
var morning_quiz_done_day: int = -1
var morning_buff_active: bool = false
var morning_buff_day: int = -1 ## buff only valid on this day key
## Local DLC unlocks (no store billing). Core always owned via ContentDB.
var owned_content_packs: Array = ["demo_mountain"]
var total_td_clears: int = 0
var total_explore_clears: int = 0
var total_arena_runs: int = 0
var arena_best_sec: float = 0.0
var tower_floor_cleared: int = 0 ## highest floor cleared (1-based)
var silver_bank: int = 0
var xiuwei_bank: int = 0
var materials_draft: int = 0 ## aggregate draft count (Idle claim + explore deposit sum)
var materials_inv: Dictionary = {} ## material_id -> int (shared meta from 搜打撤)
var wuxue_drafts: int = 0 ## thin craft / 武学草稿 counter
var gear_unlocked: Array = [] ## gear ids earned from clears
var gear_equipped: Array = ["", "", ""] ## 3 slots: 器/衣/饰

# Idle accrual
var idle_last_unix: float = 0.0
var idle_pending_silver: float = 0.0
var idle_pending_xiuwei: float = 0.0
var idle_pending_materials: float = 0.0
## training_slots[i] = { "unit_id": String, "started_unix": float } or empty unit_id
var training_slots: Array = []

# --- Active checkpoints ---
var td_checkpoint: Dictionary = {}
var explore_checkpoint: Dictionary = {}
var arena_checkpoint: Dictionary = {}
var tower_checkpoint: Dictionary = {}


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
	arena_checkpoint = data.get("arena_checkpoint", {})
	tower_checkpoint = data.get("tower_checkpoint", {})
	_accrue_idle_offline()
	checkpoint_changed.emit()


func _init_defaults() -> void:
	for u in ContentDB.unit_list:
		unit_fragments[u["id"]] = 0
		hero_mastery[u["id"]] = 0
		training_level[u["id"]] = 0
		if u.get("unlocked", false) and u["id"] not in unlocked_units:
			unlocked_units.append(u["id"])
	_ensure_training_slots()
	idle_last_unix = Time.get_unix_time_from_system()
	silver_bank = 120
	# Seed a little pending so first visit can demonstrate claim UX after short wait.
	idle_pending_silver = 15.0
	idle_pending_xiuwei = 5.0
	idle_pending_materials = 1.0
	if owns_content_pack("demo_mountain") and ContentDB.gear.has("gear_demo_trail_charm"):
		unlock_gear("gear_demo_trail_charm")


func _ensure_training_slots() -> void:
	var n := int(ContentDB.idle_cfg.get("training_slot_count", 2))
	while training_slots.size() < n:
		training_slots.append({"unit_id": "", "started_unix": 0.0})
	if training_slots.size() > n:
		training_slots.resize(n)


func _apply_meta(meta: Dictionary) -> void:
	unlocked_units = meta.get("unlocked_units", unlocked_units)
	unit_fragments = meta.get("unit_fragments", unit_fragments)
	explore_hero_id = meta.get("explore_hero_id", explore_hero_id)
	hero_mastery = meta.get("hero_mastery", hero_mastery)
	training_level = meta.get("training_level", training_level)
	knowledge_seen = meta.get("knowledge_seen", knowledge_seen)
	knowledge_review_queue = meta.get("knowledge_review_queue", knowledge_review_queue)
	knowledge_correct = meta.get("knowledge_correct", knowledge_correct)
	knowledge_due = meta.get("knowledge_due", knowledge_due)
	if typeof(knowledge_due) != TYPE_DICTIONARY:
		knowledge_due = {}
	morning_quiz_done_day = int(meta.get("morning_quiz_done_day", -1))
	morning_buff_active = bool(meta.get("morning_buff_active", false))
	morning_buff_day = int(meta.get("morning_buff_day", -1))
	owned_content_packs = meta.get("owned_content_packs", owned_content_packs)
	if typeof(owned_content_packs) != TYPE_ARRAY:
		owned_content_packs = ["demo_mountain"]
	_refresh_morning_buff_for_today()
	total_td_clears = int(meta.get("total_td_clears", 0))
	total_explore_clears = int(meta.get("total_explore_clears", 0))
	total_arena_runs = int(meta.get("total_arena_runs", 0))
	arena_best_sec = float(meta.get("arena_best_sec", 0.0))
	tower_floor_cleared = int(meta.get("tower_floor_cleared", 0))
	silver_bank = int(meta.get("silver_bank", 0))
	xiuwei_bank = int(meta.get("xiuwei_bank", 0))
	materials_draft = int(meta.get("materials_draft", 0))
	materials_inv = meta.get("materials_inv", {})
	if typeof(materials_inv) != TYPE_DICTIONARY:
		materials_inv = {}
	wuxue_drafts = int(meta.get("wuxue_drafts", 0))
	gear_unlocked = meta.get("gear_unlocked", gear_unlocked)
	gear_equipped = meta.get("gear_equipped", gear_equipped)
	if gear_equipped.size() < 3:
		gear_equipped.resize(3)
	idle_last_unix = float(meta.get("idle_last_unix", 0.0))
	idle_pending_silver = float(meta.get("idle_pending_silver", 0.0))
	idle_pending_xiuwei = float(meta.get("idle_pending_xiuwei", 0.0))
	idle_pending_materials = float(meta.get("idle_pending_materials", 0.0))
	training_slots = meta.get("training_slots", [])
	_ensure_training_slots()
	for u in ContentDB.unit_list:
		var uid: String = u["id"]
		if not training_level.has(uid):
			training_level[uid] = 0
		if not hero_mastery.has(uid):
			hero_mastery[uid] = 0
		if not unit_fragments.has(uid):
			unit_fragments[uid] = 0
	SettingsManager.load_from_meta(meta)
	meta_changed.emit()


func export_meta() -> Dictionary:
	return {
		"unlocked_units": unlocked_units.duplicate(),
		"unit_fragments": unit_fragments.duplicate(),
		"explore_hero_id": explore_hero_id,
		"hero_mastery": hero_mastery.duplicate(),
		"training_level": training_level.duplicate(),
		"knowledge_seen": knowledge_seen.duplicate(),
		"knowledge_review_queue": knowledge_review_queue.duplicate(),
		"knowledge_correct": knowledge_correct.duplicate(),
		"knowledge_due": knowledge_due.duplicate(),
		"morning_quiz_done_day": morning_quiz_done_day,
		"morning_buff_active": morning_buff_active,
		"morning_buff_day": morning_buff_day,
		"owned_content_packs": owned_content_packs.duplicate(),
		"total_td_clears": total_td_clears,
		"total_explore_clears": total_explore_clears,
		"total_arena_runs": total_arena_runs,
		"arena_best_sec": arena_best_sec,
		"tower_floor_cleared": tower_floor_cleared,
		"silver_bank": silver_bank,
		"xiuwei_bank": xiuwei_bank,
		"materials_draft": materials_draft,
		"materials_inv": materials_inv.duplicate(),
		"wuxue_drafts": wuxue_drafts,
		"gear_unlocked": gear_unlocked.duplicate(),
		"gear_equipped": gear_equipped.duplicate(),
		"idle_last_unix": idle_last_unix,
		"idle_pending_silver": idle_pending_silver,
		"idle_pending_xiuwei": idle_pending_xiuwei,
		"idle_pending_materials": idle_pending_materials,
		"training_slots": training_slots.duplicate(true),
		"settings": SettingsManager.export_settings(),
		"content_pack": ContentDB.manifest.get("content_pack", "core"),
		"loaded_content_packs": ContentDB.loaded_pack_ids.duplicate(),
	}


func persist_lobby() -> void:
	td_checkpoint = {}
	explore_checkpoint = {}
	arena_checkpoint = {}
	tower_checkpoint = {}
	SaveManager.write_save({
		"meta": export_meta(),
		"td_checkpoint": {},
		"explore_checkpoint": {},
		"arena_checkpoint": {},
		"tower_checkpoint": {},
		"resume": "lobby",
	})
	checkpoint_changed.emit()


func persist_meta_keep_checkpoints() -> void:
	SaveManager.write_save({
		"meta": export_meta(),
		"td_checkpoint": td_checkpoint,
		"explore_checkpoint": explore_checkpoint,
		"arena_checkpoint": arena_checkpoint,
		"tower_checkpoint": tower_checkpoint,
		"resume": resume_target(),
	})
	meta_changed.emit()


func persist_td(checkpoint: Dictionary) -> void:
	td_checkpoint = checkpoint.duplicate(true)
	explore_checkpoint = {}
	arena_checkpoint = {}
	tower_checkpoint = {}
	SaveManager.write_save({
		"meta": export_meta(),
		"td_checkpoint": td_checkpoint,
		"explore_checkpoint": {},
		"arena_checkpoint": {},
		"tower_checkpoint": {},
		"resume": "td",
	})
	checkpoint_changed.emit()


func persist_explore(checkpoint: Dictionary) -> void:
	explore_checkpoint = checkpoint.duplicate(true)
	td_checkpoint = {}
	arena_checkpoint = {}
	tower_checkpoint = {}
	SaveManager.write_save({
		"meta": export_meta(),
		"td_checkpoint": {},
		"explore_checkpoint": explore_checkpoint,
		"arena_checkpoint": {},
		"tower_checkpoint": {},
		"resume": "explore",
	})
	checkpoint_changed.emit()


func persist_arena(checkpoint: Dictionary) -> void:
	arena_checkpoint = checkpoint.duplicate(true)
	td_checkpoint = {}
	explore_checkpoint = {}
	tower_checkpoint = {}
	SaveManager.write_save({
		"meta": export_meta(),
		"td_checkpoint": {},
		"explore_checkpoint": {},
		"arena_checkpoint": arena_checkpoint,
		"tower_checkpoint": {},
		"resume": "arena",
	})
	checkpoint_changed.emit()


func persist_tower(checkpoint: Dictionary) -> void:
	tower_checkpoint = checkpoint.duplicate(true)
	td_checkpoint = {}
	explore_checkpoint = {}
	arena_checkpoint = {}
	SaveManager.write_save({
		"meta": export_meta(),
		"td_checkpoint": {},
		"explore_checkpoint": {},
		"arena_checkpoint": {},
		"tower_checkpoint": tower_checkpoint,
		"resume": "tower",
	})
	checkpoint_changed.emit()


func has_resume() -> bool:
	return (
		not td_checkpoint.is_empty()
		or not explore_checkpoint.is_empty()
		or not arena_checkpoint.is_empty()
		or not tower_checkpoint.is_empty()
	)


func resume_target() -> String:
	if not td_checkpoint.is_empty():
		return "td"
	if not explore_checkpoint.is_empty():
		return "explore"
	if not arena_checkpoint.is_empty():
		return "arena"
	if not tower_checkpoint.is_empty():
		return "tower"
	return "lobby"


func mark_knowledge_delivered(kid: String, correct: bool) -> void:
	if kid == "" or not ContentDB.knowledge.has(kid):
		return
	if kid not in knowledge_seen:
		knowledge_seen.append(kid)
	var now := Time.get_unix_time_from_system()
	if correct:
		knowledge_correct[kid] = int(knowledge_correct.get(kid, 0)) + 1
		knowledge_review_queue.erase(kid)
		knowledge_due[kid] = now + _spaced_interval_sec(int(knowledge_correct[kid]))
	else:
		if kid not in knowledge_review_queue:
			knowledge_review_queue.append(kid)
		knowledge_due[kid] = now # due immediately
	meta_changed.emit()


func _spaced_interval_sec(correct_times: int) -> float:
	## Light spaced intervals: 1d → 3d → 7d (caps).
	if correct_times <= 1:
		return 86400.0
	if correct_times == 2:
		return 86400.0 * 3.0
	return 86400.0 * 7.0


func knowledge_due_ids() -> Array:
	var now := Time.get_unix_time_from_system()
	var out: Array = []
	for kid in knowledge_review_queue:
		if ContentDB.knowledge.has(kid) and kid not in out:
			out.append(kid)
	for kid in knowledge_due.keys():
		if not ContentDB.knowledge.has(kid):
			continue
		if float(knowledge_due[kid]) <= now and kid not in out:
			out.append(kid)
	return out


func knowledge_progress_tier() -> int:
	## Tiny meta buffs from real learning progress (correct unique cards).
	var n := 0
	for kid in knowledge_correct.keys():
		if int(knowledge_correct[kid]) > 0:
			n += 1
	if n >= 20:
		return 3
	if n >= 10:
		return 2
	if n >= 5:
		return 1
	return 0


func knowledge_meta_bonuses() -> Dictionary:
	## Applied lightly in TD / explore / arena / tower — subway-friendly numbers.
	var tier := knowledge_progress_tier()
	return {
		"tier": tier,
		"td_start_silver": 5 * tier,
		"td_atk_mult": 1.0 + 0.02 * float(tier),
		"explore_shield": 4 * tier,
		"explore_max_hp": 5 * tier,
		"auto_combat_atk_mult": 1.0 + 0.015 * float(tier),
	}


func owns_content_pack(pack_id: String) -> bool:
	if pack_id == "core" or pack_id == "":
		return true
	return pack_id in owned_content_packs


func unlock_content_pack(pack_id: String) -> void:
	if pack_id == "" or pack_id in owned_content_packs:
		return
	owned_content_packs.append(pack_id)
	ContentDB.reload()
	# Demo trail charm auto-unlock when demo pack owned.
	for g in ContentDB.gear_list:
		if str(g.get("content_pack", "")) == pack_id and str(g.get("unlock", "")).begins_with("pack_"):
			unlock_gear(str(g.get("id", "")))
	meta_changed.emit()
	persist_meta_keep_checkpoints()


func _refresh_morning_buff_for_today() -> void:
	## Buff expires if the calendar day rolled and quiz was not re-done.
	if morning_buff_active and morning_buff_day != today_key() and morning_quiz_done_day != today_key():
		morning_buff_active = false


func unlock_unit(uid: String) -> void:
	if uid not in unlocked_units:
		unlocked_units.append(uid)
		meta_changed.emit()


func add_fragments(uid: String, amount: int) -> void:
	unit_fragments[uid] = int(unit_fragments.get(uid, 0)) + amount
	var need := int(ContentDB.get_unit(uid).get("unlock_fragments", 3))
	if int(unit_fragments[uid]) >= need and uid not in unlocked_units:
		unlock_unit(uid)
	meta_changed.emit()


func add_mastery(uid: String, amount: int = 1) -> void:
	hero_mastery[uid] = int(hero_mastery.get(uid, 0)) + amount
	meta_changed.emit()


## Effective TD proficiency: explore mastery + Idle training levels.
func effective_mastery(uid: String) -> int:
	var base := int(hero_mastery.get(uid, 0))
	var train := int(training_level.get(uid, 0))
	var per := int(ContentDB.idle_cfg.get("mastery_per_train_level", 2))
	return base + train * per


func today_key() -> int:
	var d := Time.get_date_dict_from_system()
	return int(d.year) * 10000 + int(d.month) * 100 + int(d.day)


func can_morning_quiz() -> bool:
	return morning_quiz_done_day != today_key()


func complete_morning_quiz(score: int) -> void:
	morning_quiz_done_day = today_key()
	morning_buff_day = today_key()
	morning_buff_active = score >= 2
	meta_changed.emit()
	persist_meta_keep_checkpoints()


func is_morning_buff_live() -> bool:
	_refresh_morning_buff_for_today()
	return morning_buff_active and morning_buff_day == today_key()


func unlock_gear(gid: String) -> void:
	if gid != "" and gid not in gear_unlocked:
		gear_unlocked.append(gid)
		meta_changed.emit()


func add_material(mat_id: String, amount: int) -> void:
	if mat_id == "" or amount == 0:
		return
	materials_inv[mat_id] = maxi(0, int(materials_inv.get(mat_id, 0)) + amount)
	# Keep scalar draft in sync for lobby status line / Idle UX.
	var total := 0
	for k in materials_inv.keys():
		total += int(materials_inv[k])
	materials_draft = total
	meta_changed.emit()


func add_materials_dict(loot: Dictionary) -> void:
	for k in loot.keys():
		add_material(str(k), int(loot[k]))


func material_count(mat_id: String) -> int:
	return int(materials_inv.get(mat_id, 0))


func materials_summary() -> String:
	if materials_inv.is_empty():
		return "无"
	var parts: PackedStringArray = []
	for k in materials_inv.keys():
		var n := int(materials_inv[k])
		if n <= 0:
			continue
		var name := str(ContentDB.get_material(str(k)).get("name", k))
		parts.append("%s×%d" % [name, n])
	return " · ".join(parts) if not parts.is_empty() else "无"


## Deposit run bag into shared meta. keep_ratio < 1 = failure / mid-flee penalty.
func deposit_run_bag(bag: Dictionary, keep_ratio: float = 1.0) -> Dictionary:
	var deposited := {}
	var r := clampf(keep_ratio, 0.0, 1.0)
	for k in bag.keys():
		var raw := int(bag[k])
		var keep := int(floor(float(raw) * r)) if r < 1.0 else raw
		if keep > 0:
			add_material(str(k), keep)
			deposited[str(k)] = keep
	return deposited


func can_craft(recipe_id: String) -> bool:
	var recipe := _find_recipe(recipe_id)
	if recipe.is_empty():
		return false
	var cost: Dictionary = recipe.get("cost", {})
	for k in cost.keys():
		if material_count(str(k)) < int(cost[k]):
			return false
	var unlock := str(recipe.get("unlock_gear", ""))
	if unlock != "" and unlock in gear_unlocked:
		return false
	return true


func craft_recipe(recipe_id: String, hero_id: String = "") -> Dictionary:
	if not can_craft(recipe_id):
		return {"ok": false, "reason": "缺料或已拥有"}
	var recipe := _find_recipe(recipe_id)
	var cost: Dictionary = recipe.get("cost", {})
	for k in cost.keys():
		add_material(str(k), -int(cost[k]))
	var unlock := str(recipe.get("unlock_gear", ""))
	if unlock != "":
		unlock_gear(unlock)
	var xiu := int(recipe.get("add_xiuwei", 0))
	if xiu > 0:
		xiuwei_bank += xiu
	var mast := int(recipe.get("add_mastery_selected", 0))
	var hid := hero_id if hero_id != "" else explore_hero_id
	if mast > 0 and hid != "":
		add_mastery(hid, mast)
		wuxue_drafts += 1
	persist_meta_keep_checkpoints()
	meta_changed.emit()
	return {"ok": true, "recipe": recipe}


func _find_recipe(recipe_id: String) -> Dictionary:
	for r in ContentDB.recipes:
		if str(r.get("id", "")) == recipe_id:
			return r
	return {}


func equip_gear(slot: int, gid: String) -> void:
	if slot < 0 or slot >= 3:
		return
	if gid != "" and gid not in gear_unlocked:
		return
	gear_equipped[slot] = gid
	meta_changed.emit()
	persist_meta_keep_checkpoints()


# --- Idle accrual / claim / training ---

func idle_rates_per_hour() -> Dictionary:
	var cfg := ContentDB.idle_cfg
	var silver := float(cfg.get("base_silver_per_hour", 20))
	var xiuwei := float(cfg.get("base_xiuwei_per_hour", 6))
	var mats := float(cfg.get("base_material_per_hour", 1))
	for uid in unlocked_units:
		var idle: Dictionary = ContentDB.get_unit(uid).get("idle", {})
		var mult := 1.0 + 0.05 * int(training_level.get(uid, 0))
		silver += float(idle.get("silver_per_hour", 0)) * mult
		xiuwei += float(idle.get("xiuwei_per_hour", 0)) * mult
		mats += float(idle.get("material_per_hour", 0)) * mult
	# Occupied training slots get a small bonus (名人在练功).
	for slot in training_slots:
		var sid := str(slot.get("unit_id", ""))
		if sid != "" and sid in unlocked_units:
			silver += 6.0
			xiuwei += 4.0
	return {"silver": silver, "xiuwei": xiuwei, "materials": mats}


func _accrue_idle_offline() -> void:
	var now := Time.get_unix_time_from_system()
	if idle_last_unix <= 0.0:
		idle_last_unix = now
		return
	var cap_h := float(ContentDB.idle_cfg.get("offline_cap_hours", 8.0))
	var elapsed := mini(now - idle_last_unix, cap_h * 3600.0)
	if elapsed <= 0.0:
		return
	_resolve_finished_training(now)
	var rates := idle_rates_per_hour()
	var hours := elapsed / 3600.0
	idle_pending_silver += rates.silver * hours
	idle_pending_xiuwei += rates.xiuwei * hours
	idle_pending_materials += rates.materials * hours
	idle_last_unix = now


func refresh_idle_accrual() -> void:
	var before_s := idle_pending_silver
	var before_x := idle_pending_xiuwei
	var before_m := idle_pending_materials
	_accrue_idle_offline()
	if idle_pending_silver != before_s or idle_pending_xiuwei != before_x or idle_pending_materials != before_m:
		meta_changed.emit()


func pending_claim_totals() -> Dictionary:
	return {
		"silver": int(floor(idle_pending_silver)),
		"xiuwei": int(floor(idle_pending_xiuwei)),
		"materials": int(floor(idle_pending_materials)),
	}


func can_claim_idle() -> bool:
	var t := pending_claim_totals()
	var min_s := int(ContentDB.idle_cfg.get("claim_min_seconds", 30))
	# Allow claim if any pending, or enough wall time since last tick for UX after short absences.
	return t.silver > 0 or t.xiuwei > 0 or t.materials > 0 or min_s <= 0


func claim_idle() -> Dictionary:
	refresh_idle_accrual()
	var got := pending_claim_totals()
	silver_bank += int(got.silver)
	xiuwei_bank += int(got.xiuwei)
	# Idle forage → typed wood so explore craft / meta share one inventory.
	if int(got.materials) > 0:
		add_material("mat_wood", int(got.materials))
	idle_pending_silver -= float(got.silver)
	idle_pending_xiuwei -= float(got.xiuwei)
	idle_pending_materials -= float(got.materials)
	persist_meta_keep_checkpoints()
	meta_changed.emit()
	return got


func _resolve_finished_training(now: float) -> void:
	for i in training_slots.size():
		var slot: Dictionary = training_slots[i]
		var uid := str(slot.get("unit_id", ""))
		if uid == "":
			continue
		var started := float(slot.get("started_unix", 0.0))
		if started <= 0.0:
			continue
		var need_sec := _train_seconds_for(uid)
		if need_sec <= 0.0:
			continue
		# Catch up multiple cycles after long offline absences.
		var guard := 0
		while now - started >= need_sec and guard < 24:
			_complete_training_slot(i, started + need_sec)
			slot = training_slots[i]
			started = float(slot.get("started_unix", 0.0))
			guard += 1


func _train_seconds_for(uid: String) -> float:
	var idle: Dictionary = ContentDB.get_unit(uid).get("idle", {})
	if idle.has("train_minutes"):
		return maxf(30.0, float(idle.get("train_minutes", 5.0)) * 60.0)
	return maxf(30.0, float(idle.get("train_hours", 1.0)) * 3600.0)


func _complete_training_slot(slot_index: int, now: float) -> void:
	var slot: Dictionary = training_slots[slot_index]
	var uid := str(slot.get("unit_id", ""))
	if uid == "":
		return
	training_level[uid] = int(training_level.get(uid, 0)) + 1
	add_mastery(uid, int(ContentDB.idle_cfg.get("mastery_per_train_level", 2)))
	# Unlock weight: chance to grant fragment toward locked celebrities.
	var chance := float(ContentDB.idle_cfg.get("fragment_chance_per_train", 0.35))
	if randf() < chance:
		var locked: Array = []
		for u in ContentDB.unit_list:
			var id: String = u["id"]
			if id not in unlocked_units:
				locked.append(id)
		if not locked.is_empty():
			add_fragments(str(locked[randi() % locked.size()]), 1)
	# Keep trainee assigned; restart cycle clock.
	slot["started_unix"] = now
	training_slots[slot_index] = slot


## Debug / capture: finish current training cycles immediately.
func force_finish_training() -> void:
	var now := Time.get_unix_time_from_system()
	for i in training_slots.size():
		var uid := str(training_slots[i].get("unit_id", ""))
		if uid == "":
			continue
		_complete_training_slot(i, now)
	persist_meta_keep_checkpoints()
	meta_changed.emit()


func assign_training(slot_index: int, uid: String) -> bool:
	_ensure_training_slots()
	if slot_index < 0 or slot_index >= training_slots.size():
		return false
	if uid != "" and uid not in unlocked_units:
		return false
	# One unit per slot max across slots.
	if uid != "":
		for i in training_slots.size():
			if i != slot_index and str(training_slots[i].get("unit_id", "")) == uid:
				return false
	refresh_idle_accrual()
	var cost := 0
	if uid != "":
		cost = int(ContentDB.get_unit(uid).get("idle", {}).get("train_cost_silver", 40))
		if silver_bank < cost:
			return false
		silver_bank -= cost
	training_slots[slot_index] = {
		"unit_id": uid,
		"started_unix": Time.get_unix_time_from_system() if uid != "" else 0.0,
	}
	persist_meta_keep_checkpoints()
	meta_changed.emit()
	return true


func training_progress(slot_index: int) -> float:
	if slot_index < 0 or slot_index >= training_slots.size():
		return 0.0
	var slot: Dictionary = training_slots[slot_index]
	var uid := str(slot.get("unit_id", ""))
	if uid == "":
		return 0.0
	var started := float(slot.get("started_unix", 0.0))
	var need := _train_seconds_for(uid)
	if need <= 0.0:
		return 1.0
	var now := Time.get_unix_time_from_system()
	return clampf((now - started) / need, 0.0, 1.0)


func go_lobby() -> void:
	mode = Mode.LOBBY
	refresh_idle_accrual()
	get_tree().change_scene_to_file("res://scenes/lobby/lobby.tscn")


func go_idle() -> void:
	mode = Mode.IDLE
	refresh_idle_accrual()
	get_tree().change_scene_to_file("res://scenes/idle/idle_hub.tscn")


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


func go_arena(continue_run: bool = false) -> void:
	mode = Mode.ARENA
	if not continue_run:
		arena_checkpoint = {}
	get_tree().change_scene_to_file("res://scenes/arena/arena_run.tscn")


func go_tower(continue_run: bool = false) -> void:
	mode = Mode.TOWER
	if not continue_run:
		tower_checkpoint = {}
	get_tree().change_scene_to_file("res://scenes/tower/tower_run.tscn")


func go_knowledge() -> void:
	mode = Mode.KNOWLEDGE
	get_tree().change_scene_to_file("res://scenes/knowledge/knowledge_hub.tscn")
