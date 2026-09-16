extends Control
## Short room-run explore: auto-attack + 1 manual active skill. Portrait-friendly.

const KnowledgeCardScene := preload("res://scenes/knowledge/knowledge_card.tscn")

@onready var arena: Control = %Arena
@onready var hero_node: ColorRect = %Hero
@onready var enemies_layer: Node2D = %EnemiesLayer
@onready var room_label: Label = %RoomLabel
@onready var hp_label: Label = %HpLabel
@onready var status_label: Label = %StatusLabel
@onready var skill_btn: Button = %SkillBtn
@onready var next_btn: Button = %NextBtn
@onready var flee_btn: Button = %FleeBtn
@onready var lobby_btn: Button = %LobbyBtn

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
var enemies: Array = [] ## dicts
var knowledge_layer: CanvasLayer
var awaiting_knowledge: bool = false
var shield: float = 0.0
var slow_all_timer: float = 0.0
var game_done: bool = false
var room_completed: bool = false


func _ready() -> void:
	knowledge_layer = KnowledgeCardScene.instantiate()
	add_child(knowledge_layer)
	knowledge_layer.resolved.connect(_on_knowledge_resolved)
	rooms = ContentDB.rooms_cfg.get("rooms", []).duplicate(true)
	skill_btn.pressed.connect(_cast_skill)
	next_btn.pressed.connect(_advance_room)
	flee_btn.pressed.connect(_flee)
	lobby_btn.pressed.connect(_save_and_lobby)
	if not GameState.explore_checkpoint.is_empty():
		_load_checkpoint(GameState.explore_checkpoint)
	else:
		hero_id = GameState.explore_hero_id
		if hero_id not in GameState.unlocked_units and not GameState.unlocked_units.is_empty():
			hero_id = GameState.unlocked_units[0]
		_init_hero_stats()
		room_index = 0
		if GameState.morning_buff_active:
			shield = 25
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
	hero_node.color = Color(u.get("color", "#c45c26"))
	skill_btn.text = "%s" % skill.get("name", "技能")


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
	if room_index >= rooms.size():
		_victory()
		return
	var room: Dictionary = rooms[room_index]
	room_label.text = "房间 %d/%d · %s" % [room_index + 1, rooms.size(), room.get("label", room.get("type", ""))]
	var rtype := str(room.get("type", "combat"))
	next_btn.visible = false
	match rtype:
		"combat":
			if room_completed:
				status_label.text = "本房已清。可进入下一房。"
				next_btn.visible = true
				flee_btn.disabled = true
			else:
				status_label.text = "遭遇敌人。自动普攻；点按主动技。"
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
				status_label.text = "吐纳恢复 +%d HP。可进入下一房。" % int(heal)
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
				GameState.silver_bank += int(room.get("silver", 0))
				status_label.text = "补给 +%d HP，银两仓 +%d。" % [int(heal2), int(room.get("silver", 0))]
				room_completed = true
			else:
				status_label.text = "补给已领取。可进入下一房。"
			next_btn.visible = true
			flee_btn.disabled = true
			_persist()
		_:
			next_btn.visible = true
	_refresh()


func _spawn_room_enemies(ids: Array) -> void:
	var i := 0
	for eid in ids:
		var e: Dictionary = ContentDB.get_enemy(str(eid))
		var node := ColorRect.new()
		node.size = Vector2(40, 40)
		node.color = Color(e.get("color", "#a00"))
		node.position = Vector2(420 + (i % 2) * 70, 180 + i * 90)
		enemies_layer.add_child(node)
		var label := Label.new()
		label.text = str(e.get("name", "?")).substr(0, 2)
		node.add_child(label)
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
	# Nearest / first
	var target: Dictionary = enemies[0]
	target.hp -= atk
	_flash(hero_node)
	if target.hp <= 0:
		target.node.queue_free()
		enemies.erase(target)
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
		_flash(enemy.node)
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
				if enemy.hp <= 0:
					enemy.node.queue_free()
					enemies.erase(enemy)
		"heal":
			hp = minf(max_hp, hp + value)
		"shield":
			shield += value
		"slow_all":
			slow_all_timer = float(skill.get("duration", 2.0))
		_:
			for enemy in enemies.duplicate():
				enemy.hp -= value
				if enemy.hp <= 0:
					enemy.node.queue_free()
					enemies.erase(enemy)
	skill_cd = float(skill.get("cooldown", 8.0))
	_refresh_skill_btn()
	_refresh()
	if enemies.is_empty() and combat_active:
		_on_combat_cleared()


func _on_combat_cleared() -> void:
	combat_active = false
	room_completed = true
	status_label.text = "清场。可进入下一房（自动存档）。"
	next_btn.visible = true
	flee_btn.disabled = true
	GameState.add_mastery(hero_id, 1)
	GameState.add_fragments(hero_id, 1)
	_persist()


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
		hp = minf(max_hp, hp + 15)
		status_label.text = "答对，略作恢复。进入下一房。"
	else:
		status_label.text = "已记下正解。进入下一房。"
	next_btn.visible = true
	_persist()
	_refresh()


func _flee() -> void:
	if not combat_active:
		return
	status_label.text = "撤离成功，奖励减半结算。"
	GameState.silver_bank += 5
	GameState.explore_checkpoint = {}
	GameState.persist_lobby()
	game_done = true
	next_btn.text = "回大厅"
	next_btn.visible = true
	next_btn.pressed.disconnect(_advance_room)
	next_btn.pressed.connect(func(): GameState.go_lobby())


func _victory() -> void:
	game_done = true
	GameState.total_explore_clears += 1
	GameState.add_mastery(hero_id, 2)
	GameState.silver_bank += 40
	GameState.explore_checkpoint = {}
	GameState.persist_lobby()
	status_label.text = "栈道夜行通关！熟练与碎片已写入。"
	room_label.text = "通关"
	next_btn.text = "回大厅"
	next_btn.visible = true
	if next_btn.pressed.is_connected(_advance_room):
		next_btn.pressed.disconnect(_advance_room)
	next_btn.pressed.connect(func(): GameState.go_lobby())


func _defeat() -> void:
	game_done = true
	combat_active = false
	GameState.explore_checkpoint = {}
	GameState.persist_lobby()
	status_label.text = "战败撤离。知识进度保留。"
	next_btn.text = "回大厅"
	next_btn.visible = true
	if next_btn.pressed.is_connected(_advance_room):
		next_btn.pressed.disconnect(_advance_room)
	next_btn.pressed.connect(func(): GameState.go_lobby())


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
	GameState.go_lobby()


func _refresh() -> void:
	hp_label.text = "HP %d/%d%s" % [int(hp), int(max_hp), (" ·盾%d" % int(shield)) if shield > 0 else ""]
	_refresh_skill_btn()


func _refresh_skill_btn() -> void:
	if skill_cd > 0.05:
		skill_btn.text = "%s (%.1fs)" % [skill.get("name", "技能"), skill_cd]
		skill_btn.disabled = true
	else:
		skill_btn.text = str(skill.get("name", "技能"))
		skill_btn.disabled = not combat_active and enemies.is_empty()


func _flash(node: CanvasItem) -> void:
	if node == null:
		return
	var c := node.modulate
	node.modulate = Color(1.4, 1.4, 1.4, 1)
	await get_tree().create_timer(0.08).timeout
	if is_instance_valid(node):
		node.modulate = c
