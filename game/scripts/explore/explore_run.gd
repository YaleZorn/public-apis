extends Control
## Short room-run explore: auto-attack + manual active, room strip, loot feedback.

const KnowledgeCardScene := preload("res://scenes/knowledge/knowledge_card.tscn")
const ResultOverlayScene := preload("res://scenes/ui/result_overlay.tscn")
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
@onready var flee_btn: Button = %FleeBtn
@onready var lobby_btn: Button = %LobbyBtn
@onready var room_strip: HBoxContainer = %RoomStrip
@onready var loot_label: Label = %LootLabel

var hero_id: String = "unit_feidao"
var hp: float = 120
var max_hp: float = 120
var atk: float = 28
var attack_interval: float = 0.65
var attack_cd: float = 0.0
var skill: Dictionary = {}
var skill_cd: float = 0.0
var room_index: int = 0
var rooms: Array = []
var combat_active: bool = false
var enemies: Array = []
var knowledge_layer: CanvasLayer
var result_overlay: CanvasLayer
var awaiting_knowledge: bool = false
var shield: float = 0.0
var slow_all_timer: float = 0.0
var game_done: bool = false
var room_completed: bool = false
var _hero_visual: Control


func _ready() -> void:
	knowledge_layer = KnowledgeCardScene.instantiate()
	add_child(knowledge_layer)
	knowledge_layer.resolved.connect(_on_knowledge_resolved)
	result_overlay = ResultOverlayScene.instantiate()
	add_child(result_overlay)
	rooms = ContentDB.rooms_cfg.get("rooms", []).duplicate(true)
	skill_btn.pressed.connect(_cast_skill)
	next_btn.pressed.connect(_advance_room)
	flee_btn.pressed.connect(_flee)
	lobby_btn.pressed.connect(_save_and_lobby)
	loot_label.visible = false
	if not GameState.explore_checkpoint.is_empty():
		_load_checkpoint(GameState.explore_checkpoint)
	else:
		hero_id = GameState.explore_hero_id
		if hero_id not in GameState.unlocked_units and not GameState.unlocked_units.is_empty():
			hero_id = GameState.unlocked_units[0]
		_init_hero_stats()
		room_index = 0
		shield = 25 if GameState.morning_buff_active else 0
		if "gear_bamboo_cup" in GameState.gear_equipped:
			shield += 10
		_enter_room()
	_refresh()


func _init_hero_stats() -> void:
	var u: Dictionary = ContentDB.get_unit(hero_id)
	var ex: Dictionary = u.get("explore", {})
	max_hp = float(ex.get("hp", 120))
	hp = max_hp
	atk = float(ex.get("atk", 20))
	attack_interval = float(ex.get("attack_interval", 0.7))
	skill = ex.get("active", {}).duplicate(true)
	if _hero_visual:
		_hero_visual.queue_free()
	_hero_visual = VF.unit_node(u, Vector2(64, 64))
	_hero_visual.position = hero_node.position
	hero_node.visible = false
	arena.add_child(_hero_visual)


func _process(delta: float) -> void:
	if game_done or awaiting_knowledge:
		return
	if skill_cd > 0:
		skill_cd = max(0, skill_cd - delta)
		_refresh_skill_btn()
	if slow_all_timer > 0:
		slow_all_timer = max(0, slow_all_timer - delta)
	if not combat_active:
		return
	attack_cd -= delta
	_tick_enemies(delta)
	if attack_cd <= 0 and not enemies.is_empty():
		_hero_auto_attack()
		attack_cd = attack_interval
	if enemies.is_empty() and combat_active:
		_on_combat_cleared()


func _enter_room() -> void:
	combat_active = false
	enemies.clear()
	for c in enemies_layer.get_children():
		c.queue_free()
	_rebuild_room_strip()
	if room_index >= rooms.size():
		_victory()
		return
	var room: Dictionary = rooms[room_index]
	var rtype := str(room.get("type", "combat"))
	var type_name := _room_type_name(rtype)
	room_label.text = "%d/%d · %s" % [room_index + 1, rooms.size(), room.get("label", type_name)]
	next_btn.visible = false
	loot_label.visible = false
	match rtype:
		"combat":
			if room_completed:
				status_label.text = "本房已清。可进入下一房。"
				next_btn.visible = true
				flee_btn.disabled = true
			else:
				status_label.text = "遭遇敌人 · 自动普攻，点按主动技。"
				_spawn_room_enemies(room.get("enemies", []))
				combat_active = true
				flee_btn.disabled = false
		"event":
			flee_btn.disabled = true
			if room_completed:
				status_label.text = "事件已处理。可进入下一房。"
				next_btn.visible = true
			else:
				status_label.text = "事件：功法笺。"
				awaiting_knowledge = true
				knowledge_layer.present(str(room.get("knowledge_card", "k_form")))
		"train":
			if not room_completed:
				var heal := float(room.get("heal", 20))
				hp = minf(max_hp, hp + heal)
				_show_loot("吐纳 +%d HP" % int(heal), Color(0.6, 0.85, 0.65))
				room_completed = true
			else:
				status_label.text = "吐纳已完成。可进入下一房。"
			next_btn.visible = true
			flee_btn.disabled = true
			_persist()
		"supply":
			if not room_completed:
				var heal2 := float(room.get("heal", 30))
				hp = minf(max_hp, hp + heal2)
				var sil := int(room.get("silver", 0))
				GameState.silver_bank += sil
				_show_loot("补给 +%d HP · 仓 +%d 两" % [int(heal2), sil], Color(0.75, 0.82, 0.55))
				room_completed = true
			else:
				status_label.text = "补给已领取。可进入下一房。"
			next_btn.visible = true
			flee_btn.disabled = true
			_persist()
		"loot":
			if not room_completed:
				GameState.add_fragments(hero_id, int(room.get("fragments", 1)))
				_show_loot("拾得碎片 +%d" % int(room.get("fragments", 1)), Color(0.9, 0.75, 0.45))
				room_completed = true
			next_btn.visible = true
			flee_btn.disabled = true
			_persist()
		_:
			next_btn.visible = true
	_refresh()


func _room_type_name(t: String) -> String:
	match t:
		"combat": return "战"
		"event": return "事件"
		"train": return "修炼"
		"supply": return "补给"
		"loot": return "宝箱"
		_: return t


func _rebuild_room_strip() -> void:
	for c in room_strip.get_children():
		c.queue_free()
	for i in rooms.size():
		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(28, 10)
		var room: Dictionary = rooms[i]
		var col := Color(0.35, 0.38, 0.34)
		if i < room_index:
			col = Color(0.45, 0.62, 0.48)
		elif i == room_index:
			col = Color(0.85, 0.72, 0.38)
		match str(room.get("type", "")):
			"event": col = col.lerp(Color(0.5, 0.65, 0.85), 0.35)
			"train": col = col.lerp(Color(0.55, 0.78, 0.55), 0.35)
			"supply", "loot": col = col.lerp(Color(0.85, 0.7, 0.35), 0.35)
		dot.color = col
		room_strip.add_child(dot)


func _spawn_room_enemies(ids: Array) -> void:
	var i := 0
	for eid in ids:
		var e: Dictionary = ContentDB.get_enemy(str(eid))
		var node := VF.enemy_node(e, Vector2(44, 44))
		node.position = Vector2(380 + (i % 2) * 80, 160 + i * 95)
		enemies_layer.add_child(node)
		enemies.append({
			"id": eid,
			"hp": float(e.get("hp", 50)) * 0.85,
			"atk": 8.0 + float(e.get("leak_damage", 1)) * 4.0,
			"node": node,
			"attack_cd": 1.0 + i * 0.2,
		})
		i += 1


func _hero_auto_attack() -> void:
	if enemies.is_empty():
		return
	var target: Dictionary = enemies[0]
	target.hp -= atk
	var pos: Vector2 = target.node.position + target.node.custom_minimum_size * 0.5
	Juice.float_number(pos, str(int(atk)), Color(1, 0.88, 0.5))
	Juice.play_sfx("hit")
	_pulse(_hero_visual)
	if target.hp <= 0:
		target.node.queue_free()
		enemies.erase(target)
		Juice.play_sfx("kill")
	_refresh()


func _tick_enemies(delta: float) -> void:
	var factor := 0.55 if slow_all_timer > 0 else 1.0
	for enemy in enemies.duplicate():
		enemy.attack_cd -= delta * factor
		if enemy.attack_cd > 0:
			continue
		enemy.attack_cd = 1.4
		var dmg: float = enemy.atk
		if shield > 0:
			var absorb := minf(shield, dmg)
			shield -= absorb
			dmg -= absorb
		hp -= dmg
		Juice.float_number(_hero_visual.position, "-%d" % int(dmg), Color(0.95, 0.45, 0.4))
		Juice.play_sfx("hit")
		Juice.screen_shake(arena, 5.0)
		_pulse(enemy.node)
		if hp <= 0:
			_defeat()
			return
	_refresh()


func _cast_skill() -> void:
	if skill_cd > 0 or awaiting_knowledge or game_done:
		return
	if not combat_active and enemies.is_empty():
		return
	var effect := str(skill.get("effect", ""))
	var value := float(skill.get("value", 0))
	match effect:
		"aoe_damage":
			for enemy in enemies.duplicate():
				enemy.hp -= value
				Juice.float_number(enemy.node.position, str(int(value)), Color(0.85, 0.65, 1))
				if enemy.hp <= 0:
					enemy.node.queue_free()
					enemies.erase(enemy)
		"heal":
			hp = minf(max_hp, hp + value)
			Juice.float_number(_hero_visual.position, "+%d" % int(value), Color(0.55, 0.9, 0.6))
		"shield":
			shield += value
			Juice.float_number(_hero_visual.position, "盾+%d" % int(value), Color(0.55, 0.75, 0.95))
		"slow_all":
			slow_all_timer = float(skill.get("duration", 2.0))
		_:
			for enemy in enemies.duplicate():
				enemy.hp -= value
				if enemy.hp <= 0:
					enemy.node.queue_free()
					enemies.erase(enemy)
	skill_cd = float(skill.get("cooldown", 8.0))
	Juice.play_sfx("skill")
	Juice.screen_shake(arena, 4.0)
	_refresh_skill_btn()
	_refresh()
	if enemies.is_empty() and combat_active:
		_on_combat_cleared()


func _on_combat_cleared() -> void:
	combat_active = false
	room_completed = true
	_show_loot("清场 · 熟练+1 · 碎片+1", Color(0.72, 0.88, 0.62))
	GameState.add_mastery(hero_id, 1)
	GameState.add_fragments(hero_id, 1)
	next_btn.visible = true
	flee_btn.disabled = true
	_persist()


func _show_loot(text: String, col: Color) -> void:
	status_label.text = text
	loot_label.text = text
	loot_label.add_theme_color_override("font_color", col)
	loot_label.visible = true
	Juice.play_sfx("win")
	Juice.pulse(loot_label, 1.08, 0.2)


func _advance_room() -> void:
	if awaiting_knowledge or game_done:
		return
	room_index += 1
	room_completed = false
	_persist()
	_enter_room()


func _on_knowledge_resolved(_id: String, correct: bool) -> void:
	awaiting_knowledge = false
	room_completed = true
	if correct:
		var bonus := 15
		if "gear_jade_token" in GameState.gear_equipped:
			bonus += 5
		hp = minf(max_hp, hp + bonus)
		status_label.text = "答对，恢复 +%d HP。" % bonus
	else:
		status_label.text = "已记下正解。进入下一房。"
	next_btn.visible = true
	_persist()
	_refresh()


func _flee() -> void:
	if not combat_active:
		return
	game_done = true
	combat_active = false
	GameState.silver_bank += 5
	GameState.explore_checkpoint = {}
	GameState.persist_lobby()
	result_overlay.show_result(
		"撤离成功",
		"奖励减半结算，银两仓 +5。\n知识进度已保留。",
		"回大厅",
		Color(0.65, 0.75, 0.85),
		func(): GameState.go_lobby()
	)


func _victory() -> void:
	game_done = true
	GameState.total_explore_clears += 1
	GameState.add_mastery(hero_id, 2)
	GameState.silver_bank += 40
	if GameState.total_explore_clears >= 1:
		GameState.unlock_gear("gear_linen_wrap")
	GameState.explore_checkpoint = {}
	GameState.persist_lobby()
	result_overlay.show_result(
		"栈道夜行通关",
		"探索第一章完成。\n熟练+2 · 银两仓 +40 · 解锁「麻布护腕」",
		"回大厅",
		Color(0.55, 0.82, 0.55),
		func(): GameState.go_lobby()
	)


func _defeat() -> void:
	game_done = true
	combat_active = false
	GameState.explore_checkpoint = {}
	GameState.persist_lobby()
	result_overlay.show_result(
		"力竭撤离",
		"战败但知识进度保留。\n换英雄或回大厅晨课后再试。",
		"回大厅",
		Color(0.85, 0.45, 0.4),
		func(): GameState.go_lobby()
	)


func _persist() -> void:
	GameState.persist_explore({
		"hero_id": hero_id,
		"hp": hp,
		"max_hp": max_hp,
		"shield": shield,
		"room_index": room_index,
		"skill_cd": skill_cd,
		"room_completed": room_completed,
	})


func _load_checkpoint(cp: Dictionary) -> void:
	hero_id = str(cp.get("hero_id", GameState.explore_hero_id))
	_init_hero_stats()
	hp = float(cp.get("hp", max_hp))
	max_hp = float(cp.get("max_hp", max_hp))
	shield = float(cp.get("shield", 0))
	room_index = int(cp.get("room_index", 0))
	skill_cd = float(cp.get("skill_cd", 0))
	room_completed = bool(cp.get("room_completed", false))
	status_label.text = "已从房间边界存档续关。"
	_enter_room()


func _save_and_lobby() -> void:
	if combat_active:
		status_label.text = "战斗中请先清场或撤离"
		return
	_persist()
	Juice.fade_transition(func(): GameState.go_lobby())


func _refresh() -> void:
	hp_label.text = "HP %d/%d%s" % [int(hp), int(max_hp), (" ·盾%d" % int(shield)) if shield > 0 else ""]
	hp_bar.max_value = max_hp
	hp_bar.value = hp
	_refresh_skill_btn()


func _refresh_skill_btn() -> void:
	if skill_cd > 0.05:
		skill_btn.text = "%s (%.1fs)" % [skill.get("name", "技能"), skill_cd]
		skill_btn.disabled = true
	else:
		skill_btn.text = str(skill.get("name", "技能"))
		skill_btn.disabled = not combat_active and enemies.is_empty()


func _pulse(node: CanvasItem) -> void:
	if node == null:
		return
	var c := node.modulate
	node.modulate = Color(1.35, 1.35, 1.35, 1)
	await get_tree().create_timer(0.08).timeout
	if is_instance_valid(node):
		node.modulate = c
