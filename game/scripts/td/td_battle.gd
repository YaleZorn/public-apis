extends Control
## Jiange TD chapter: place/recall roster, wave defense, inter-wave knowledge + juice.

const SLOT_COUNT := 6
const MAX_DEPLOYED := 4
const KnowledgeCardScene := preload("res://scenes/knowledge/knowledge_card.tscn")
const ResultOverlayScene := preload("res://scenes/ui/result_overlay.tscn")
const VF := preload("res://scripts/util/visual_factory.gd")

@onready var field: Control = %Field
@onready var path_line: Line2D = %PathLine
@onready var path_outline: Line2D = %PathOutline
@onready var units_layer: Node2D = %UnitsLayer
@onready var enemies_layer: Node2D = %EnemiesLayer
@onready var decor_layer: Node2D = %DecorLayer
@onready var slots_layer: Control = %SlotsLayer
@onready var hud_silver: Label = %SilverLabel
@onready var hud_lives: Label = %LivesLabel
@onready var hud_wave: Label = %WaveLabel
@onready var chapter_label: Label = %ChapterLabel
@onready var wave_banner: Label = %WaveBanner
@onready var status_label: Label = %StatusLabel
@onready var roster_bar: HBoxContainer = %RosterBar
@onready var start_wave_btn: Button = %StartWaveBtn
@onready var recall_btn: Button = %RecallBtn
@onready var lobby_btn: Button = %LobbyBtn
@onready var speed_btn: Button = %SpeedBtn

var silver: int = 200
var lives: int = 12
var wave_index: int = 0
var selected_unit_id: String = ""
var selected_slot: int = -1
var deployed: Dictionary = {}
var path_points: PackedVector2Array = PackedVector2Array()
var wave_running: bool = false
var enemies_alive: int = 0
var spawn_queue: Array = []
var spawn_timer: float = 0.0
var knowledge_layer: CanvasLayer
var result_overlay: CanvasLayer
var awaiting_knowledge: bool = false
var game_over: bool = false
var time_scale_local: float = 1.0
var _slot_buttons: Array[Button] = []


func _ready() -> void:
	knowledge_layer = KnowledgeCardScene.instantiate()
	add_child(knowledge_layer)
	knowledge_layer.resolved.connect(_on_knowledge_resolved)
	result_overlay = ResultOverlayScene.instantiate()
	add_child(result_overlay)
	start_wave_btn.pressed.connect(_on_start_wave)
	recall_btn.pressed.connect(_on_recall)
	lobby_btn.pressed.connect(_save_and_lobby)
	speed_btn.pressed.connect(_toggle_speed)
	chapter_label.text = str(ContentDB.waves_cfg.get("chapter_title", ContentDB.waves_cfg.get("map_name", "剑阁栈道")))
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
	_update_wave_preview()
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
	path_outline.points = path_points
	path_outline.width = 36
	path_outline.default_color = Color(0.22, 0.2, 0.14, 0.55)
	path_line.points = path_points
	path_line.width = 24
	path_line.default_color = Color(0.48, 0.42, 0.28, 0.92)
	_build_decor(w, h)


func _build_decor(w: float, h: float) -> void:
	for c in decor_layer.get_children():
		c.queue_free()
	var patches := [
		[Vector2(w * 0.12, h * 0.08), Vector2(120, 80), Color(0.18, 0.26, 0.19, 0.5)],
		[Vector2(w * 0.55, h * 0.52), Vector2(140, 90), Color(0.14, 0.2, 0.16, 0.45)],
		[Vector2(w * 0.05, h * 0.72), Vector2(100, 70), Color(0.16, 0.22, 0.18, 0.4)],
	]
	for p in patches:
		var patch := VF.terrain_patch(p[2], p[1])
		patch.position = p[0]
		decor_layer.add_child(patch)
	var gate := VF.gate_marker()
	gate.position = path_points[path_points.size() - 1] - Vector2(42, 50)
	decor_layer.add_child(gate)
	var spawn := ColorRect.new()
	spawn.size = Vector2(36, 36)
	spawn.position = path_points[0] - Vector2(18, 18)
	spawn.color = Color(0.75, 0.35, 0.25, 0.9)
	decor_layer.add_child(spawn)
	var spawn_lbl := Label.new()
	spawn_lbl.text = "敌"
	spawn_lbl.add_theme_font_size_override("font_size", 12)
	spawn_lbl.position = spawn.position + Vector2(6, 8)
	decor_layer.add_child(spawn_lbl)


func _build_slots() -> void:
	for c in slots_layer.get_children():
		c.queue_free()
	_slot_buttons.clear()
	var anchors := [
		Vector2(0.68, 0.18), Vector2(0.32, 0.18),
		Vector2(0.32, 0.40), Vector2(0.68, 0.40),
		Vector2(0.68, 0.62), Vector2(0.42, 0.62),
	]
	for i in SLOT_COUNT:
		var btn := Button.new()
		btn.text = "槽%d" % (i + 1)
		btn.focus_mode = Control.FOCUS_NONE
		btn.custom_minimum_size = Vector2(88, 88)
		btn.set_anchors_preset(Control.PRESET_TOP_LEFT)
		btn.anchor_left = anchors[i].x
		btn.anchor_right = anchors[i].x
		btn.anchor_top = anchors[i].y
		btn.anchor_bottom = anchors[i].y
		btn.offset_left = -44
		btn.offset_right = 44
		btn.offset_top = -44
		btn.offset_bottom = 44
		btn.modulate = Color(0.85, 0.9, 0.8, 0.85)
		btn.pressed.connect(_on_slot_pressed.bind(i))
		slots_layer.add_child(btn)
		_slot_buttons.append(btn)


func _slot_center(slot: int) -> Vector2:
	return _slot_buttons[slot].get_rect().get_center()


func _build_roster_bar() -> void:
	for c in roster_bar.get_children():
		c.queue_free()
	for uid in GameState.unlocked_units:
		var u: Dictionary = ContentDB.get_unit(uid)
		var b := Button.new()
		var role_tag := _role_short(str(u.get("role", "")))
		b.text = "%s\n%d两 %s" % [u.get("name", uid), int(u.get("cost", 50)), role_tag]
		b.custom_minimum_size = Vector2(112, 74)
		b.pressed.connect(func():
			selected_unit_id = uid
			status_label.text = "已选 %s — 点空槽放置" % u.get("name", uid)
			Juice.play_sfx("tap")
		)
		roster_bar.add_child(b)


func _role_short(role: String) -> String:
	match role:
		"tank": return "盾"
		"dps": return "攻"
		"control": return "控"
		"support": return "辅"
		"summon": return "阵"
		_: return ""


func _on_slot_pressed(slot: int) -> void:
	if wave_running or awaiting_knowledge or game_over:
		return
	selected_slot = slot
	_highlight_slot(slot)
	if deployed.has(slot):
		status_label.text = "槽 %d 已有 %s（可回收）" % [slot + 1, ContentDB.get_unit(deployed[slot].unit_id).get("name", "")]
		return
	if selected_unit_id == "":
		status_label.text = "先选底栏角色"
		return
	if deployed.size() >= MAX_DEPLOYED:
		status_label.text = "最多同时放置 %d 人" % MAX_DEPLOYED
		return
	for s in deployed.keys():
		if deployed[s].unit_id == selected_unit_id:
			status_label.text = "该角色已在场上"
			return
	var u: Dictionary = ContentDB.get_unit(selected_unit_id)
	var cost := int(u.get("cost", 50))
	if silver < cost:
		status_label.text = "银两不足（需要 %d）" % cost
		Juice.screen_shake(field, 4.0)
		return
	silver -= cost
	_spawn_unit_visual(slot, selected_unit_id)
	Juice.play_sfx("place")
	Juice.pulse(_slot_buttons[slot])
	_refresh_hud()
	_persist_prep()


func _highlight_slot(slot: int) -> void:
	for i in _slot_buttons.size():
		var b := _slot_buttons[i]
		b.modulate = Color(1.2, 1.15, 0.85) if i == slot else Color.WHITE


func _spawn_unit_visual(slot: int, unit_id: String) -> void:
	var u: Dictionary = ContentDB.get_unit(unit_id)
	var node := VF.unit_node(u)
	var center := _slot_center(slot)
	node.position = center - node.custom_minimum_size * 0.5
	units_layer.add_child(node)
	deployed[slot] = {
		"unit_id": unit_id,
		"hp": float(u.get("td", {}).get("hp", 100)),
		"max_hp": float(u.get("td", {}).get("hp", 100)),
		"cooldown": 0.0,
		"node": node,
		"pos": center,
	}
	_slot_buttons[slot].modulate = Color(1, 1, 1, 0.15)
	_slot_buttons[slot].text = ""


func _on_recall() -> void:
	if wave_running or selected_slot < 0 or not deployed.has(selected_slot):
		status_label.text = "选中有单位的槽再回收"
		return
	var info: Dictionary = deployed[selected_slot]
	var u: Dictionary = ContentDB.get_unit(info.unit_id)
	var refund := int(int(u.get("cost", 50)) * float(u.get("recall_refund", 0.5)))
	if GameState.morning_buff_active:
		refund = int(refund * 1.1)
	if "gear_linen_wrap" in GameState.gear_equipped:
		refund = int(refund * 1.05)
	silver += refund
	info.node.queue_free()
	deployed.erase(selected_slot)
	_slot_buttons[selected_slot].modulate = Color(0.85, 0.9, 0.8, 0.85)
	_slot_buttons[selected_slot].text = "槽%d" % (selected_slot + 1)
	status_label.text = "回收 +%d 银两" % refund
	Juice.play_sfx("recall")
	Juice.float_number(_slot_center(selected_slot), "+%d" % refund, Color(0.75, 0.9, 0.65))
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
		var delay := float(spawn.get("delay", 0.0))
		for i in int(spawn.get("count", 1)):
			spawn_queue.append({
				"enemy": spawn.get("enemy", "enemy_bandit"),
				"interval": float(spawn.get("interval", 0.8)),
				"delay": delay if i == 0 else 0.0,
			})
	spawn_timer = 0.35
	enemies_alive = 0
	wave_running = true
	start_wave_btn.disabled = true
	var label := str(wave.get("label", "第 %d 波" % (wave_index + 1)))
	wave_banner.text = "— %s —" % label
	wave_banner.visible = true
	status_label.text = str(wave.get("hint", "敌军来袭！"))
	Juice.play_sfx("wave")
	Juice.screen_shake(field, 5.0)
	_refresh_hud()
	get_tree().create_timer(2.2).timeout.connect(func(): wave_banner.visible = false)


func _tick_spawns(delta: float) -> void:
	if spawn_queue.is_empty():
		return
	spawn_timer -= delta
	if spawn_timer > 0:
		return
	var job: Dictionary = spawn_queue.pop_front()
	_spawn_enemy(str(job.enemy))
	if not spawn_queue.is_empty():
		spawn_timer = float(spawn_queue[0].get("delay", 0.0)) + float(spawn_queue[0].interval)


func _spawn_enemy(eid: String) -> void:
	var e: Dictionary = ContentDB.get_enemy(eid)
	var node := VF.enemy_node(e)
	node.position = path_points[0] - node.custom_minimum_size * 0.5
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
		node.position = a.lerp(b, t) - node.custom_minimum_size * 0.5


func _tick_combat(delta: float) -> void:
	_apply_team_auras(delta)
	for slot in deployed.keys():
		var info: Dictionary = deployed[slot]
		info.cooldown = float(info.cooldown) - delta
		var u: Dictionary = ContentDB.get_unit(info.unit_id)
		var td: Dictionary = u.get("td", {})
		if info.cooldown > 0:
			deployed[slot] = info
			continue
		var target = _find_target(info.pos, float(td.get("range", 100)))
		if target == null:
			deployed[slot] = info
			continue
		var atk := float(td.get("atk", 10))
		atk *= 1.0 + 0.02 * int(GameState.hero_mastery.get(info.unit_id, 0))
		atk *= _atk_buff_multiplier(info.pos)
		var armor: float = float(target.get_meta("armor"))
		var dmg := maxf(1.0, atk - armor * 0.5)
		target.set_meta("hp", float(target.get_meta("hp")) - dmg)
		info.cooldown = float(td.get("attack_interval", 1.0))
		deployed[slot] = info
		var hit_pos: Vector2 = target.position + target.custom_minimum_size * 0.5
		Juice.float_number(hit_pos, str(int(dmg)), Color(1, 0.85, 0.45))
		Juice.play_sfx("hit")
		if float(target.get_meta("hp")) <= 0:
			_kill_enemy(target)


func _apply_team_auras(delta: float) -> void:
	for slot in deployed.keys():
		var info: Dictionary = deployed[slot]
		var u: Dictionary = ContentDB.get_unit(info.unit_id)
		var aura: Dictionary = u.get("td", {}).get("aura", {})
		var t := str(aura.get("type", "none"))
		if t == "none":
			continue
		var radius := float(aura.get("radius", 100))
		var value := float(aura.get("value", 0))
		if t == "slow":
			for node in enemies_layer.get_children():
				var pos: Vector2 = node.position + node.custom_minimum_size * 0.5
				if info.pos.distance_to(pos) <= radius:
					node.set_meta("speed_factor", 1.0 - value)
		elif t == "regen":
			for other_slot in deployed.keys():
				var other: Dictionary = deployed[other_slot]
				if info.pos.distance_to(other.pos) <= radius:
					other.hp = minf(other.max_hp, other.hp + value * delta)
					deployed[other_slot] = other


func _atk_buff_multiplier(from_pos: Vector2) -> float:
	var mult := 1.0
	for slot in deployed.keys():
		var info: Dictionary = deployed[slot]
		var u: Dictionary = ContentDB.get_unit(info.unit_id)
		var aura: Dictionary = u.get("td", {}).get("aura", {})
		if str(aura.get("type", "")) != "atk_buff":
			continue
		var radius := float(aura.get("radius", 100))
		if from_pos.distance_to(info.pos) <= radius:
			mult += float(aura.get("value", 0))
	return mult


func _find_target(from: Vector2, rng: float):
	var best = null
	var best_hp := INF
	for node in enemies_layer.get_children():
		var factor := float(node.get_meta("speed_factor", 1.0))
		var base_speed := float(ContentDB.get_enemy(str(node.get_meta("eid"))).get("speed", 50))
		node.set_meta("speed", base_speed * factor)
		node.set_meta("speed_factor", 1.0)
		var pos: Vector2 = node.position + node.custom_minimum_size * 0.5
		if from.distance_to(pos) <= rng:
			var hp := float(node.get_meta("hp"))
			if hp < best_hp:
				best_hp = hp
				best = node
	return best


func _kill_enemy(node: Node) -> void:
	var reward := int(node.get_meta("reward"))
	silver += reward
	enemies_alive = max(0, enemies_alive - 1)
	Juice.float_number(node.position, "+%d" % reward, Color(0.7, 0.95, 0.65))
	Juice.play_sfx("kill")
	node.queue_free()
	_refresh_hud()


func _leak(node: Node) -> void:
	lives -= int(node.get_meta("leak"))
	enemies_alive = max(0, enemies_alive - 1)
	Juice.screen_shake(field, 8.0)
	Juice.play_sfx("lose")
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
	_update_wave_preview()
	status_label.text = "波次肃清。可调整阵容后下一波。"
	if not GameState.unlocked_units.is_empty():
		var uid: String = GameState.unlocked_units[wave_index % GameState.unlocked_units.size()]
		GameState.add_fragments(uid, 1)
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


func _on_knowledge_resolved(_id: String, _correct: bool) -> void:
	awaiting_knowledge = false
	_persist_prep()
	status_label.text = "知识已记入。准备下一波。"


func _victory() -> void:
	game_over = true
	GameState.total_td_clears += 1
	GameState.silver_bank += silver / 5
	if GameState.total_td_clears >= 1:
		GameState.unlock_gear("gear_bamboo_cup")
	GameState.td_checkpoint = {}
	GameState.persist_lobby()
	result_overlay.show_result(
		"剑阁无恙",
		"第一章「栈道夜雨」通关。\n银两仓 +%d · 碎片已写入 · 解锁装备「竹节水壶」。" % (silver / 5),
		"回大厅",
		Color(0.55, 0.82, 0.55),
		func(): GameState.go_lobby()
	)


func _defeat() -> void:
	game_over = true
	wave_running = false
	GameState.silver_bank += max(0, silver / 10)
	GameState.td_checkpoint = {}
	GameState.persist_lobby()
	result_overlay.show_result(
		"据点失守",
		"已保留知识进度与 %d 银两仓。\n回大厅重整阵容再战。" % (silver / 10),
		"回大厅",
		Color(0.85, 0.45, 0.4),
		func(): GameState.go_lobby()
	)


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
	_update_wave_preview()
	_refresh_hud()
	# Fix silver display after load — already set above.


func _save_and_lobby() -> void:
	if wave_running:
		status_label.text = "战斗中不可退出，请等本波结束"
		return
	_persist_prep()
	Juice.fade_transition(func(): GameState.go_lobby())


func _toggle_speed() -> void:
	time_scale_local = 2.0 if time_scale_local < 1.5 else 1.0
	speed_btn.text = "速度 x%d" % int(time_scale_local)


func _update_wave_preview() -> void:
	var waves: Array = ContentDB.waves_cfg.get("waves", [])
	if wave_index >= waves.size():
		return
	var wave: Dictionary = waves[wave_index]
	var label := str(wave.get("label", "第 %d 波" % (wave_index + 1)))
	status_label.text = "待命：%s — %s" % [label, str(wave.get("hint", ""))]


func _refresh_hud() -> void:
	hud_silver.text = "银两 %d" % silver
	hud_lives.text = "据点 %d" % lives
	var total: int = ContentDB.waves_cfg.get("waves", []).size()
	hud_wave.text = "波次 %d/%d" % [mini(wave_index + 1, total), total]
	start_wave_btn.text = "开始第 %d 波" % (wave_index + 1) if wave_index < total else "已通关"
