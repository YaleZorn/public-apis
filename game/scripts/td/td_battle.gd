extends Control
## Jiange TD: place/recall up to 4 roster units, wave defense, inter-wave save + knowledge.

const SLOT_COUNT := 6
const MAX_DEPLOYED := 4
const KnowledgeCardScene := preload("res://scenes/knowledge/knowledge_card.tscn")

@onready var field: Control = %Field
@onready var path_line: Line2D = %PathLine
@onready var units_layer: Node2D = %UnitsLayer
@onready var enemies_layer: Node2D = %EnemiesLayer
@onready var slots_layer: Control = %SlotsLayer
@onready var hud_silver: Label = %SilverLabel
@onready var hud_lives: Label = %LivesLabel
@onready var hud_wave: Label = %WaveLabel
@onready var status_label: Label = %StatusLabel
@onready var roster_bar: HBoxContainer = %RosterBar
@onready var start_wave_btn: Button = %StartWaveBtn
@onready var recall_btn: Button = %RecallBtn
@onready var lobby_btn: Button = %LobbyBtn
@onready var speed_btn: Button = %SpeedBtn

var silver: int = 200
var lives: int = 12
var wave_index: int = 0 ## 0-based next wave to fight
var selected_unit_id: String = ""
var selected_slot: int = -1
var deployed: Dictionary = {} ## slot -> {unit_id, hp, node}
var path_points: PackedVector2Array = PackedVector2Array()
var wave_running: bool = false
var enemies_alive: int = 0
var spawn_queue: Array = []
var spawn_timer: float = 0.0
var knowledge_layer: CanvasLayer
var awaiting_knowledge: bool = false
var game_over: bool = false
var time_scale_local: float = 1.0


func _ready() -> void:
	knowledge_layer = KnowledgeCardScene.instantiate()
	add_child(knowledge_layer)
	knowledge_layer.resolved.connect(_on_knowledge_resolved)
	start_wave_btn.pressed.connect(_on_start_wave)
	recall_btn.pressed.connect(_on_recall)
	lobby_btn.pressed.connect(_save_and_lobby)
	speed_btn.pressed.connect(_toggle_speed)
	await get_tree().process_frame
	_build_path()
	_build_slots()
	_build_roster_bar()
	if not GameState.td_checkpoint.is_empty():
		_load_checkpoint(GameState.td_checkpoint)
	else:
		silver = int(ContentDB.waves_cfg.get("starting_silver", 200))
		if GameState.morning_buff_active:
			silver += 20
		lives = int(ContentDB.waves_cfg.get("starting_lives", 12))
		wave_index = 0
		_persist_prep()
	_refresh_hud()
	status_label.text = "点选底栏角色 → 点槽位放置。波间自动存档。"


func _process(delta: float) -> void:
	if game_over or awaiting_knowledge or not wave_running:
		return
	var d := delta * time_scale_local
	_tick_spawns(d)
	_tick_combat(d)
	_tick_movement(d)
	if enemies_alive <= 0 and spawn_queue.is_empty():
		_on_wave_cleared()


func _build_path() -> void:
	# Portrait path: enter top-right, snake down to gate bottom-center.
	var w := field.size.x
	var h := field.size.y
	if w < 10:
		w = 648
		h = 720
	path_points = PackedVector2Array([
		Vector2(w * 0.85, 20),
		Vector2(w * 0.85, h * 0.22),
		Vector2(w * 0.2, h * 0.22),
		Vector2(w * 0.2, h * 0.45),
		Vector2(w * 0.8, h * 0.45),
		Vector2(w * 0.8, h * 0.68),
		Vector2(w * 0.35, h * 0.68),
		Vector2(w * 0.35, h * 0.92),
		Vector2(w * 0.5, h * 0.98),
	])
	path_line.points = path_points
	path_line.width = 28
	path_line.default_color = Color(0.35, 0.32, 0.22, 0.85)


func _build_slots() -> void:
	for c in slots_layer.get_children():
		c.queue_free()
	var anchors := [
		Vector2(0.68, 0.18), Vector2(0.32, 0.18),
		Vector2(0.32, 0.40), Vector2(0.68, 0.40),
		Vector2(0.68, 0.62), Vector2(0.42, 0.62),
	]
	for i in SLOT_COUNT:
		var btn := Button.new()
		btn.text = "槽%d" % (i + 1)
		btn.custom_minimum_size = Vector2(88, 88)
		btn.position = Vector2(field.size.x * anchors[i].x - 44, field.size.y * anchors[i].y - 44) if field.size.x > 10 \
			else Vector2(648 * anchors[i].x - 44, 720 * anchors[i].y - 44)
		btn.pressed.connect(_on_slot_pressed.bind(i))
		slots_layer.add_child(btn)


func _build_roster_bar() -> void:
	for c in roster_bar.get_children():
		c.queue_free()
	var roster: Array = GameState.unlocked_units.duplicate()
	# Cap selectable pool display; deployment still max 4.
	for uid in roster:
		var u: Dictionary = ContentDB.get_unit(uid)
		var b := Button.new()
		b.text = "%s\n%d两" % [u.get("name", uid), int(u.get("cost", 50))]
		b.custom_minimum_size = Vector2(110, 70)
		b.pressed.connect(func():
			selected_unit_id = uid
			status_label.text = "已选 %s — 点空槽放置" % u.get("name", uid)
		)
		roster_bar.add_child(b)


func _on_slot_pressed(slot: int) -> void:
	if wave_running or awaiting_knowledge or game_over:
		return
	selected_slot = slot
	if deployed.has(slot):
		status_label.text = "槽 %d 已有 %s（可回收）" % [slot + 1, ContentDB.get_unit(deployed[slot].unit_id).get("name", "")]
		return
	if selected_unit_id == "":
		status_label.text = "先选底栏角色"
		return
	if deployed.size() >= MAX_DEPLOYED:
		status_label.text = "最多同时放置 %d 人" % MAX_DEPLOYED
		return
	# One instance per unit id in v0.
	for s in deployed.keys():
		if deployed[s].unit_id == selected_unit_id:
			status_label.text = "该角色已在场上"
			return
	var u: Dictionary = ContentDB.get_unit(selected_unit_id)
	var cost := int(u.get("cost", 50))
	if silver < cost:
		status_label.text = "银两不足"
		return
	silver -= cost
	_spawn_unit_visual(slot, selected_unit_id)
	_refresh_hud()
	_persist_prep()


func _spawn_unit_visual(slot: int, unit_id: String) -> void:
	var u: Dictionary = ContentDB.get_unit(unit_id)
	var node := ColorRect.new()
	node.size = Vector2(56, 56)
	node.color = Color(u.get("color", "#888888"))
	var slot_btn: Button = slots_layer.get_child(slot)
	node.position = slot_btn.position + Vector2(16, 16)
	var label := Label.new()
	label.text = str(u.get("name", "?")).substr(0, 2)
	label.add_theme_font_size_override("font_size", 14)
	node.add_child(label)
	units_layer.add_child(node)
	deployed[slot] = {
		"unit_id": unit_id,
		"hp": float(u.get("td", {}).get("hp", 100)),
		"max_hp": float(u.get("td", {}).get("hp", 100)),
		"cooldown": 0.0,
		"node": node,
		"pos": node.position + Vector2(28, 28),
	}


func _on_recall() -> void:
	if wave_running or selected_slot < 0 or not deployed.has(selected_slot):
		status_label.text = "选中有单位的槽再回收"
		return
	var info: Dictionary = deployed[selected_slot]
	var u: Dictionary = ContentDB.get_unit(info.unit_id)
	var refund := int(int(u.get("cost", 50)) * float(u.get("recall_refund", 0.5)))
	if GameState.morning_buff_active:
		refund = int(refund * 1.1)
	silver += refund
	info.node.queue_free()
	deployed.erase(selected_slot)
	status_label.text = "回收 +%d 银两" % refund
	_refresh_hud()
	_persist_prep()


func _on_start_wave() -> void:
	if wave_running or awaiting_knowledge or game_over:
		return
	var waves: Array = ContentDB.waves_cfg.get("waves", [])
	if wave_index >= waves.size():
		_victory()
		return
	var wave: Dictionary = waves[wave_index]
	spawn_queue.clear()
	for spawn in wave.get("spawns", []):
		for _i in int(spawn.get("count", 1)):
			spawn_queue.append({
				"enemy": spawn.get("enemy", "enemy_bandit"),
				"interval": float(spawn.get("interval", 0.8)),
			})
	spawn_timer = 0.2
	enemies_alive = 0
	wave_running = true
	start_wave_btn.disabled = true
	status_label.text = "第 %d 波来袭！" % (wave_index + 1)
	_refresh_hud()


func _tick_spawns(delta: float) -> void:
	if spawn_queue.is_empty():
		return
	spawn_timer -= delta
	if spawn_timer > 0:
		return
	var job: Dictionary = spawn_queue.pop_front()
	_spawn_enemy(str(job.enemy))
	if not spawn_queue.is_empty():
		spawn_timer = float(spawn_queue[0].interval)


func _spawn_enemy(eid: String) -> void:
	var e: Dictionary = ContentDB.get_enemy(eid)
	var node := ColorRect.new()
	node.size = Vector2(28, 28)
	node.color = Color(e.get("color", "#aa4444"))
	node.position = path_points[0] - Vector2(14, 14)
	enemies_layer.add_child(node)
	node.set_meta("eid", eid)
	node.set_meta("hp", float(e.get("hp", 50)))
	node.set_meta("max_hp", float(e.get("hp", 50)))
	node.set_meta("speed", float(e.get("speed", 50)))
	node.set_meta("armor", float(e.get("armor", 0)))
	node.set_meta("reward", int(e.get("reward", 10)))
	node.set_meta("leak", int(e.get("leak_damage", 1)))
	node.set_meta("path_i", 0)
	node.set_meta("progress", 0.0)
	enemies_alive += 1


func _tick_movement(delta: float) -> void:
	for node in enemies_layer.get_children():
		var path_i: int = int(node.get_meta("path_i"))
		if path_i >= path_points.size() - 1:
			_leak(node)
			continue
		var a: Vector2 = path_points[path_i]
		var b: Vector2 = path_points[path_i + 1]
		var dist := a.distance_to(b)
		var prog: float = float(node.get_meta("progress"))
		prog += float(node.get_meta("speed")) * delta
		while prog >= dist and path_i < path_points.size() - 1:
			prog -= dist
			path_i += 1
			node.set_meta("path_i", path_i)
			if path_i >= path_points.size() - 1:
				break
			a = path_points[path_i]
			b = path_points[path_i + 1]
			dist = a.distance_to(b)
		node.set_meta("progress", prog)
		if path_i >= path_points.size() - 1:
			_leak(node)
			continue
		var t := 0.0 if dist <= 0.001 else prog / dist
		node.position = a.lerp(b, t) - Vector2(14, 14)


func _tick_combat(delta: float) -> void:
	for slot in deployed.keys():
		var info: Dictionary = deployed[slot]
		info.cooldown = float(info.cooldown) - delta
		var u: Dictionary = ContentDB.get_unit(info.unit_id)
		var td: Dictionary = u.get("td", {})
		# Aura effects
		_apply_aura(info, td.get("aura", {}))
		if info.cooldown > 0:
			deployed[slot] = info
			continue
		var target = _find_target(info.pos, float(td.get("range", 100)))
		if target == null:
			deployed[slot] = info
			continue
		var atk := float(td.get("atk", 10))
		# Mastery / morning tiny hooks
		atk *= 1.0 + 0.02 * int(GameState.hero_mastery.get(info.unit_id, 0))
		var armor: float = float(target.get_meta("armor"))
		var dmg := maxf(1.0, atk - armor * 0.5)
		target.set_meta("hp", float(target.get_meta("hp")) - dmg)
		info.cooldown = float(td.get("attack_interval", 1.0))
		deployed[slot] = info
		if float(target.get_meta("hp")) <= 0:
			_kill_enemy(target)


func _apply_aura(info: Dictionary, aura: Dictionary) -> void:
	var t := str(aura.get("type", "none"))
	if t == "none":
		return
	var radius := float(aura.get("radius", 100))
	var value := float(aura.get("value", 0))
	for node in enemies_layer.get_children():
		var pos: Vector2 = node.position + Vector2(14, 14)
		if info.pos.distance_to(pos) > radius:
			continue
		if t == "slow":
			# Soft slow via meta flag each frame — applied as speed factor.
			node.set_meta("speed_factor", 1.0 - value)
		elif t == "armor_share":
			pass # visual/tank fantasy; HP soak simplified in v0


func _find_target(from: Vector2, rng: float):
	var best = null
	var best_hp := INF
	for node in enemies_layer.get_children():
		var factor := float(node.get_meta("speed_factor", 1.0))
		# Apply slow to effective speed continuously.
		var base_speed := float(ContentDB.get_enemy(str(node.get_meta("eid"))).get("speed", 50))
		node.set_meta("speed", base_speed * factor)
		node.set_meta("speed_factor", 1.0) # reset; auras re-apply
		var pos: Vector2 = node.position + Vector2(14, 14)
		if from.distance_to(pos) <= rng:
			var hp := float(node.get_meta("hp"))
			if hp < best_hp:
				best_hp = hp
				best = node
	return best


func _kill_enemy(node: Node) -> void:
	silver += int(node.get_meta("reward"))
	enemies_alive = max(0, enemies_alive - 1)
	node.queue_free()
	_refresh_hud()


func _leak(node: Node) -> void:
	lives -= int(node.get_meta("leak"))
	enemies_alive = max(0, enemies_alive - 1)
	node.queue_free()
	_refresh_hud()
	if lives <= 0:
		_defeat()


func _on_wave_cleared() -> void:
	wave_running = false
	start_wave_btn.disabled = false
	var waves: Array = ContentDB.waves_cfg.get("waves", [])
	var wave: Dictionary = waves[wave_index]
	silver += int(wave.get("silver_bonus", 30))
	wave_index += 1
	_refresh_hud()
	status_label.text = "波次肃清。可调整阵容。"
	# Tiny fragment drip
	if not GameState.unlocked_units.is_empty():
		var uid: String = GameState.unlocked_units[wave_index % GameState.unlocked_units.size()]
		GameState.add_fragments(uid, 1)
	# Unlock hooks after wave 5
	if wave_index >= 5:
		GameState.unlock_unit("unit_zhaoyun")
	if wave_index >= 8:
		GameState.unlock_unit("unit_mingwang")
	if wave_index >= waves.size():
		_victory()
		return
	var kid = wave.get("knowledge_card", null)
	_persist_prep()
	if kid != null and str(kid) != "":
		awaiting_knowledge = true
		knowledge_layer.present(str(kid))
	else:
		_persist_prep()


func _on_knowledge_resolved(_id: String, _correct: bool) -> void:
	awaiting_knowledge = false
	_persist_prep()
	status_label.text = "知识已记入。准备下一波。"


func _victory() -> void:
	game_over = true
	GameState.total_td_clears += 1
	GameState.silver_bank += silver / 5
	GameState.td_checkpoint = {}
	GameState.persist_lobby()
	status_label.text = "剑阁无恙！碎片与知识已结算。"
	start_wave_btn.text = "回大厅"
	start_wave_btn.disabled = false
	start_wave_btn.pressed.disconnect(_on_start_wave)
	start_wave_btn.pressed.connect(func(): GameState.go_lobby())


func _defeat() -> void:
	game_over = true
	wave_running = false
	GameState.silver_bank += max(0, silver / 10)
	GameState.td_checkpoint = {}
	GameState.persist_lobby()
	status_label.text = "据点失守。已结算碎片，回大厅重整。"
	start_wave_btn.text = "回大厅"
	start_wave_btn.disabled = false
	if start_wave_btn.pressed.is_connected(_on_start_wave):
		start_wave_btn.pressed.disconnect(_on_start_wave)
	start_wave_btn.pressed.connect(func(): GameState.go_lobby())


func _persist_prep() -> void:
	var dep: Array = []
	for slot in deployed.keys():
		dep.append({"slot": slot, "unit_id": deployed[slot].unit_id, "hp": deployed[slot].hp})
	GameState.persist_td({
		"silver": silver,
		"lives": lives,
		"wave_index": wave_index,
		"deployed": dep,
	})


func _load_checkpoint(cp: Dictionary) -> void:
	silver = int(cp.get("silver", 200))
	lives = int(cp.get("lives", 12))
	wave_index = int(cp.get("wave_index", 0))
	for item in cp.get("deployed", []):
		_spawn_unit_visual(int(item.slot), str(item.unit_id))
		if deployed.has(int(item.slot)):
			deployed[int(item.slot)].hp = float(item.get("hp", deployed[int(item.slot)].hp))
	status_label.text = "已从波次前存档续关。"


func _save_and_lobby() -> void:
	if wave_running:
		status_label.text = "战斗中不可退出，请等本波结束"
		return
	_persist_prep()
	GameState.go_lobby()


func _toggle_speed() -> void:
	time_scale_local = 2.0 if time_scale_local < 1.5 else 1.0
	speed_btn.text = "速度 x%d" % int(time_scale_local)


func _refresh_hud() -> void:
	hud_silver.text = "银两 %d" % silver
	hud_lives.text = "据点 %d" % lives
	var total: int = ContentDB.waves_cfg.get("waves", []).size()
	hud_wave.text = "波次 %d/%d" % [mini(wave_index + 1, total), total]
	start_wave_btn.text = "开始第 %d 波" % (wave_index + 1) if wave_index < total else "已通关"
