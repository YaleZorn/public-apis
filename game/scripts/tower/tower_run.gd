extends Control
## M5 爬塔：纵向层表 · 复用自动战环 · 层间存档 · 专属装备掉落钩子。

const ResultOverlayScene := preload("res://scenes/ui/result_overlay.tscn")
const AutoCombatRing := preload("res://scripts/combat/auto_combat_ring.gd")
const Atmo := preload("res://scripts/util/atmosphere.gd")
const AP := preload("res://scripts/util/art_palette.gd")
const VF := preload("res://scripts/util/visual_factory.gd")

@onready var arena: Control = %Arena
@onready var hero_node: Control = %Hero
@onready var enemies_layer: Node2D = %EnemiesLayer
@onready var room_label: Label = %RoomLabel
@onready var hp_label: Label = %HpLabel
@onready var hp_bar: ProgressBar = %HpBar
@onready var status_label: Label = %StatusLabel
@onready var skill_btn: Button = %SkillBtn
@onready var next_btn: Button = %NextBtn
@onready var lobby_btn: Button = %LobbyBtn
@onready var floor_strip: HBoxContainer = %FloorStrip
@onready var loot_label: Label = %LootLabel
@onready var portrait_slot: Control = %PortraitSlot

var ring: RefCounted ## AutoCombatRing
var cfg: Dictionary = {}
var floor_index: int = 1 ## 1-based floor number
var between_floors: bool = false
var game_done: bool = false
var last_loot_note: String = ""
var exclusive_got: String = ""
var result_overlay: CanvasLayer
var _portrait: Control


func _ready() -> void:
	cfg = ContentDB.tower_cfg
	ring = AutoCombatRing.new()
	ring.bind(self, arena, enemies_layer, hero_node)
	ring.hero_defeated.connect(_on_defeated)
	ring.enemies_cleared.connect(_on_floor_cleared)
	Atmo.attach_full_bg(self, "night")
	var old_bg := get_node_or_null("Bg")
	if old_bg:
		old_bg.visible = false
	Atmo.apply_explore_room(arena, "combat")
	AP.apply_label(room_label, 22, AP.LANTERN_GOLD)
	AP.apply_label(hp_label, 15, AP.PAPER_DIM)
	AP.apply_label(status_label, 14, AP.PAPER_DIM)
	AP.apply_label(loot_label, 15, AP.LANTERN_GOLD)
	Juice.start_explore_music()
	result_overlay = ResultOverlayScene.instantiate()
	add_child(result_overlay)
	skill_btn.pressed.connect(func():
		if ring.cast_skill():
			_refresh()
	)
	next_btn.pressed.connect(_on_next_floor)
	lobby_btn.pressed.connect(_save_and_lobby)
	loot_label.visible = false
	next_btn.visible = false
	var hero := GameState.explore_hero_id
	if hero not in GameState.unlocked_units and not GameState.unlocked_units.is_empty():
		hero = GameState.unlocked_units[0]
	if not GameState.tower_checkpoint.is_empty():
		_load_checkpoint(GameState.tower_checkpoint)
	else:
		floor_index = int(cfg.get("start_floor", 1))
		var shield := 0.0
		if GameState.morning_buff_active:
			shield += float(cfg.get("morning_shield", 15))
		if "gear_bamboo_cup" in GameState.gear_equipped:
			shield += float(cfg.get("bamboo_shield", 10))
		ring.init_hero(hero, shield)
		_build_portrait(hero)
		_enter_floor(false)
	_refresh()


func _build_portrait(uid: String) -> void:
	if _portrait and is_instance_valid(_portrait):
		_portrait.queue_free()
	var u: Dictionary = ContentDB.get_unit(uid)
	_portrait = VF.portrait_card(u, Vector2(100, 132), true)
	_portrait.position = Vector2(4, 4)
	portrait_slot.add_child(_portrait)


func _process(delta: float) -> void:
	if game_done or between_floors:
		return
	ring.tick(delta)
	_refresh()


func _floor_cfg(n: int) -> Dictionary:
	for f in cfg.get("floors", []):
		if int(f.get("floor", 0)) == n:
			return f
	return {}


func _enter_floor(from_resume_cleared: bool) -> void:
	between_floors = false
	next_btn.visible = false
	ring.clear_enemies()
	var f: Dictionary = _floor_cfg(floor_index)
	if f.is_empty():
		_finish_tower("登顶", "层表已尽 · 可回大厅。")
		return
	room_label.text = "%s · %s" % [cfg.get("display_name", "爬塔"), f.get("label", "第%d层" % floor_index)]
	_rebuild_floor_strip()
	VF.room_wipe(self, Color(0.04, 0.10, 0.09, 0.7))
	Juice.play_sfx("room")
	if from_resume_cleared:
		between_floors = true
		status_label.text = "本层已清 · 可进下一层或存档回大厅。"
		next_btn.visible = true
		next_btn.text = "下一层"
		_persist()
		_refresh()
		return
	status_label.text = "清场后进层 · 层间可存。"
	ring.spawn_enemies(
		f.get("enemies", []),
		float(f.get("hp_scale", 1.0)),
		float(f.get("atk_scale", 1.0))
	)
	_persist()
	_refresh()


func _on_floor_cleared() -> void:
	if game_done or between_floors:
		return
	between_floors = true
	var f: Dictionary = _floor_cfg(floor_index)
	var note_parts: PackedStringArray = []
	var mats: Dictionary = f.get("materials", {})
	if not mats.is_empty():
		GameState.add_materials_dict(mats)
		note_parts.append(_mats_text(mats))
	var frags := int(f.get("fragments", 0))
	if frags > 0:
		GameState.add_fragments(ring.hero_id, frags)
		note_parts.append("碎片+%d" % frags)
	var drafts := int(f.get("wuxue_drafts", 0))
	if drafts > 0:
		GameState.wuxue_drafts += drafts
		note_parts.append("武学草稿+%d" % drafts)
	GameState.add_mastery(ring.hero_id, 1)
	note_parts.append("熟练+1")
	# Exclusive gear hook — separate from explore loot pools.
	var roll = f.get("exclusive_roll", null)
	if typeof(roll) == TYPE_DICTIONARY:
		var gid := str(roll.get("gear_id", ""))
		var chance := float(roll.get("chance", 0.0))
		if gid != "" and gid not in GameState.gear_unlocked and randf() <= chance:
			GameState.unlock_gear(gid)
			exclusive_got = gid
			note_parts.append("专属·%s" % ContentDB.get_gear(gid).get("name", gid))
	GameState.tower_floor_cleared = maxi(GameState.tower_floor_cleared, floor_index)
	last_loot_note = " · ".join(note_parts) if not note_parts.is_empty() else "无掉落"
	loot_label.text = "层奖 · " + last_loot_note
	loot_label.visible = true
	Juice.play_sfx("win")
	Juice.pulse(loot_label, 1.08, 0.2)
	status_label.text = "第%d层已清。进下一层或存档回大厅。" % floor_index
	next_btn.visible = true
	var next_f := _floor_cfg(floor_index + 1)
	next_btn.text = "下一层" if not next_f.is_empty() else "登顶结算"
	_persist()
	_refresh()


func _on_next_floor() -> void:
	if game_done or not between_floors:
		return
	Juice.play_sfx("tap")
	var next_f := _floor_cfg(floor_index + 1)
	if next_f.is_empty():
		_finish_tower("登顶结算", "已通最高配置层 · 专属掉落钩子已播种。\n最高层 %d" % GameState.tower_floor_cleared)
		return
	Juice.fade_transition(func():
		floor_index += 1
		# Light heal between floors for short sessions.
		ring.hp = minf(ring.max_hp, ring.hp + ring.max_hp * 0.15)
		loot_label.visible = false
		_enter_floor(false)
	, Color(0.03, 0.09, 0.08, 1.0), 0.28)


func _on_defeated() -> void:
	game_done = true
	ring.combat_active = false
	GameState.tower_checkpoint = {}
	GameState.persist_lobby()
	result_overlay.show_result(
		"力竭退塔",
		"本层未清 · 已清最高层 %d 保留。\n材料/专属已入库者仍有效。" % GameState.tower_floor_cleared,
		"回大厅",
		Color(0.85, 0.45, 0.4),
		func(): GameState.go_lobby()
	)


func _finish_tower(title: String, body: String) -> void:
	game_done = true
	ring.combat_active = false
	GameState.tower_checkpoint = {}
	GameState.persist_lobby()
	var extra := ""
	if exclusive_got != "":
		extra = "\n专属已获：%s" % ContentDB.get_gear(exclusive_got).get("name", exclusive_got)
	result_overlay.show_result(
		title,
		body + extra + "\n仓材料：%s" % GameState.materials_summary(),
		"回大厅",
		Color(0.7, 0.78, 0.55),
		func(): GameState.go_lobby()
	)


func _save_and_lobby() -> void:
	if game_done:
		return
	if ring.combat_active and not between_floors:
		status_label.text = "战斗中请先清层，或等力竭退塔。"
		return
	_persist()
	Juice.fade_transition(func(): GameState.go_lobby())


func _persist() -> void:
	GameState.persist_tower({
		"hero_id": ring.hero_id,
		"hp": ring.hp,
		"max_hp": ring.max_hp,
		"shield": ring.shield,
		"skill_cd": ring.skill_cd,
		"floor_index": floor_index,
		"between_floors": between_floors,
		"last_loot_note": last_loot_note,
		"exclusive_got": exclusive_got,
	})


func _load_checkpoint(cp: Dictionary) -> void:
	var hero := str(cp.get("hero_id", GameState.explore_hero_id))
	ring.init_hero(hero, float(cp.get("shield", 0)))
	ring.hp = float(cp.get("hp", ring.max_hp))
	ring.max_hp = float(cp.get("max_hp", ring.max_hp))
	ring.skill_cd = float(cp.get("skill_cd", 0))
	floor_index = int(cp.get("floor_index", cfg.get("start_floor", 1)))
	between_floors = bool(cp.get("between_floors", false))
	last_loot_note = str(cp.get("last_loot_note", ""))
	exclusive_got = str(cp.get("exclusive_got", ""))
	_build_portrait(hero)
	status_label.text = "爬塔续关 · 第%d层" % floor_index
	if last_loot_note != "":
		loot_label.text = "层奖 · " + last_loot_note
		loot_label.visible = true
	_enter_floor(between_floors)


func _rebuild_floor_strip() -> void:
	for c in floor_strip.get_children():
		c.queue_free()
	for f in cfg.get("floors", []):
		var n := int(f.get("floor", 0))
		var wrap := ColorRect.new()
		wrap.custom_minimum_size = Vector2(18, 10)
		if n == floor_index:
			wrap.color = AP.LANTERN_GOLD
		elif n <= GameState.tower_floor_cleared:
			wrap.color = Color(0.35, 0.62, 0.5)
		else:
			wrap.color = Color(0.25, 0.3, 0.28)
		floor_strip.add_child(wrap)


func _mats_text(mats: Dictionary) -> String:
	var parts: PackedStringArray = []
	for k in mats.keys():
		parts.append("%s×%d" % [ContentDB.get_material(str(k)).get("name", k), int(mats[k])])
	return " · ".join(parts)


func _refresh() -> void:
	hp_label.text = ring.hp_label_text()
	hp_bar.max_value = ring.max_hp
	hp_bar.value = ring.hp
	skill_btn.text = ring.skill_button_text()
	skill_btn.disabled = ring.skill_disabled() or between_floors
	lobby_btn.disabled = ring.combat_active and not between_floors
