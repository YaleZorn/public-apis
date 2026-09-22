extends Control
## Jiange TD: place/recall roster cards, infinite escalating waves (ape1121-style),
## top→down main lane + flank ambush. Shell/title/lobby/art preserved.

const SLOT_COUNT := 6
const MAX_DEPLOYED := 4
const KnowledgeCardScene := preload("res://scenes/knowledge/knowledge_card.tscn")
const ResultOverlayScene := preload("res://scenes/ui/result_overlay.tscn")
const WaveDirectorScript := preload("res://scripts/td/wave_director.gd")
const VF := preload("res://scripts/util/visual_factory.gd")
const Atmo := preload("res://scripts/util/atmosphere.gd")
const AP := preload("res://scripts/util/art_palette.gd")

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
var flank_path_points: PackedVector2Array = PackedVector2Array()
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
var wave_director = null
var flank_path_line: Line2D
var _threat_armed: bool = false
var _gate_node_ref: Control = null
var _ambush_lbl: Label = null
var _lives_low_warned: bool = false
var milestone_cleared: bool = false


func _ready() -> void:
	# Full-bleed painted 栈道 (correct AR) so path UV matches the illustration.
	Atmo.attach_full_bg(self, "td")
	var old_bg := get_node_or_null("Bg")
	if old_bg:
		old_bg.visible = false
	var field_bg := get_node_or_null("Field/FieldBg")
	if field_bg:
		Atmo.attach_field_art(field_bg)
	AP.apply_label(chapter_label, 16, AP.LANTERN_GOLD)
	AP.apply_label(wave_banner, 26, AP.LANTERN_GOLD)
	AP.apply_label(hud_silver, 15, AP.PAPER_INK)
	AP.apply_label(hud_lives, 15, AP.PAPER_INK)
	AP.apply_label(hud_wave, 15, AP.MIST_TEAL.lightened(0.2))
	AP.apply_label(status_label, 13, AP.PAPER_DIM)
	wave_director = WaveDirectorScript.new()
	wave_director.configure_from(ContentDB.waves_cfg)
	Juice.start_battle_music()
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
		if GameState.is_morning_buff_live():
			silver += 20
		silver += int(GameState.knowledge_meta_bonuses().get("td_start_silver", 0))
		# Tiny mastery from correctly learned knowledge (td_hook wave_prep).
		if _has_learned_hook("wave_prep_silver_bonus"):
			silver += 8
		lives = int(ContentDB.waves_cfg.get("starting_lives", 12))
		if _has_learned_hook("lives_temp_bonus"):
			lives += 1
		wave_index = 0
		_persist_prep()
	_refresh_hud()
	_update_wave_preview()
	status_label.text = "点选底栏角色卡 → 点槽放置。点「下一波」开战；波间自动存档。"


func _process(delta: float) -> void:
	if game_over or awaiting_knowledge or not wave_running:
		return
	var d := delta * time_scale_local
	_tick_spawns(d)
	_tick_combat(d)
	_tick_movement(d)
	_tick_stronghold_threat()
	if enemies_alive <= 0 and spawn_queue.is_empty():
		_on_wave_cleared()


func _tick_stronghold_threat() -> void:
	## Pulse gate + HUD when enemies near stronghold or lives critically low.
	if path_points.is_empty():
		return
	var gate_pt: Vector2 = path_points[path_points.size() - 1]
	var near := false
	for node in enemies_layer.get_children():
		if not node.has_meta("eid"):
			continue
		var pos: Vector2 = node.position + node.custom_minimum_size * 0.5
		if pos.distance_to(gate_pt) < 120.0:
			near = true
			break
	if near and not _threat_armed:
		_threat_armed = true
		Juice.play_sfx("threat")
		Juice.threaten(hud_lives, 2)
		if _gate_node_ref:
			Juice.threaten(_gate_node_ref, 2)
	elif not near:
		_threat_armed = false
	if lives <= 3 and not _lives_low_warned:
		_lives_low_warned = true
		Juice.play_sfx("threat")
		Juice.threaten(hud_lives, 3)


func _build_path() -> void:
	var w := field.size.x
	var h := field.size.y
	if w < 10:
		w = 688
		h = 916
	# Main lane: top → down toward stronghold (Kingdom Defense feel).
	var path_uv := [
		Vector2(0.492, 0.090),
		Vector2(0.500, 0.145),
		Vector2(0.557, 0.200),
		Vector2(0.539, 0.245),
		Vector2(0.436, 0.300),
		Vector2(0.411, 0.340),
		Vector2(0.451, 0.380),
		Vector2(0.565, 0.430),
		Vector2(0.553, 0.490),
		Vector2(0.436, 0.545),
		Vector2(0.419, 0.570),
		Vector2(0.494, 0.585),
		Vector2(0.545, 0.595),
		Vector2(0.505, 0.600),
	]
	path_points = PackedVector2Array()
	for uv in path_uv:
		var local := Atmo.viewport_uv_to_field(field, uv)
		local.x = clampf(local.x, 12.0, w - 12.0)
		local.y = clampf(local.y, 8.0, h - 8.0)
		path_points.append(local)
	# Flank / ambush: side entry merges into main approach (not single-lane only).
	var flank_uv := [
		Vector2(0.02, 0.38),
		Vector2(0.12, 0.40),
		Vector2(0.22, 0.44),
		Vector2(0.32, 0.50),
		Vector2(0.40, 0.55),
		Vector2(0.46, 0.58),
		Vector2(0.505, 0.600),
	]
	flank_path_points = PackedVector2Array()
	for uv in flank_uv:
		var local2 := Atmo.viewport_uv_to_field(field, uv)
		local2.x = clampf(local2.x, 8.0, w - 8.0)
		local2.y = clampf(local2.y, 8.0, h - 8.0)
		flank_path_points.append(local2)
	path_outline.points = path_points
	path_outline.width = 28
	path_outline.default_color = Color(AP.PATH_RIM.r, AP.PATH_RIM.g, AP.PATH_RIM.b, 0.38)
	path_line.points = path_points
	path_line.width = 14
	path_line.default_color = Color(AP.LANTERN_GOLD.r, AP.LANTERN_GOLD.g, AP.LANTERN_GOLD.b, 0.22)
	if flank_path_line == null:
		flank_path_line = Line2D.new()
		flank_path_line.name = "FlankPathLine"
		flank_path_line.width = 10
		flank_path_line.default_color = Color(0.85, 0.35, 0.28, 0.38)
		flank_path_line.z_index = 1
		field.add_child(flank_path_line)
		# Keep under units: move just above outline if possible
		field.move_child(flank_path_line, path_line.get_index() + 1)
	flank_path_line.points = flank_path_points
	_build_decor(w, h)


func _build_decor(w: float, h: float) -> void:
	# Gate + spawn markers — landmark kept clear of bottom HUD
	for c in decor_layer.get_children():
		c.queue_free()
	if path_points.size() > 0:
		var gate := Atmo._gate_node()
		var gate_pos: Vector2 = path_points[path_points.size() - 1] - Vector2(40, 46)
		# Keep full gatehouse clear of compact bottom HUD (safe band ≥140px)
		gate_pos.y = minf(gate_pos.y, h - 140.0)
		gate_pos.y = maxf(gate_pos.y, 24.0)
		gate.position = gate_pos
		decor_layer.add_child(gate)
		_gate_node_ref = gate
		var spawn := Atmo._spawn_marker()
		spawn.position = path_points[0] - Vector2(14, 14)
		decor_layer.add_child(spawn)
	if flank_path_points.size() > 0:
		var flank_mark := Atmo._spawn_marker()
		flank_mark.modulate = Color(1.15, 0.55, 0.45, 1.0)
		flank_mark.position = flank_path_points[0] - Vector2(14, 14)
		decor_layer.add_child(flank_mark)
		var ambush_lbl := Label.new()
		ambush_lbl.text = "伏击"
		ambush_lbl.position = flank_path_points[0] + Vector2(8, -6)
		AP.apply_label(ambush_lbl, 12, Color(0.95, 0.55, 0.42))
		ambush_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		decor_layer.add_child(ambush_lbl)
		_ambush_lbl = ambush_lbl
	var mist := ColorRect.new()
	mist.size = Vector2(w, 48)
	mist.position = Vector2(0, h * 0.4)
	mist.color = Color(0.66, 0.77, 0.72, 0.07)
	mist.mouse_filter = Control.MOUSE_FILTER_IGNORE
	decor_layer.add_child(mist)
	# Soft ink veil over field floor so painted gatehouse never peeks under HUD
	var floor_veil := ColorRect.new()
	floor_veil.size = Vector2(w, 110)
	floor_veil.position = Vector2(0, h - 110)
	floor_veil.color = Color(0.02, 0.06, 0.05, 0.78)
	floor_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	decor_layer.add_child(floor_veil)
	var floor_fade := ColorRect.new()
	floor_fade.size = Vector2(w, 56)
	floor_fade.position = Vector2(0, h - 166)
	floor_fade.color = Color(0.02, 0.06, 0.05, 0.42)
	floor_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	decor_layer.add_child(floor_fade)
	var floor_top := ColorRect.new()
	floor_top.size = Vector2(w, 32)
	floor_top.position = Vector2(0, h - 198)
	floor_top.color = Color(0.02, 0.06, 0.05, 0.2)
	floor_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	decor_layer.add_child(floor_top)


func _build_slots() -> void:
	for c in slots_layer.get_children():
		c.queue_free()
	_slot_buttons.clear()
	# Off-path clearings beside the painted S-curve (viewport UV → field anchors).
	var slot_uv := [
		Vector2(0.72, 0.18), Vector2(0.28, 0.22),
		Vector2(0.26, 0.42), Vector2(0.74, 0.44),
		Vector2(0.28, 0.64), Vector2(0.72, 0.66),
	]
	var w := maxf(field.size.x, 1.0)
	var h := maxf(field.size.y, 1.0)
	for i in SLOT_COUNT:
		var local := Atmo.viewport_uv_to_field(field, slot_uv[i])
		var ax := clampf(local.x / w, 0.08, 0.92)
		var ay := clampf(local.y / h, 0.08, 0.92)
		var btn := Button.new()
		btn.text = "槽%d" % (i + 1)
		btn.focus_mode = Control.FOCUS_NONE
		btn.custom_minimum_size = Vector2(84, 84)
		btn.set_anchors_preset(Control.PRESET_TOP_LEFT)
		btn.anchor_left = ax
		btn.anchor_right = ax
		btn.anchor_top = ay
		btn.anchor_bottom = ay
		btn.offset_left = -42
		btn.offset_right = 42
		btn.offset_top = -42
		btn.offset_bottom = 42
		btn.modulate = Color(0.82, 0.92, 0.84, 0.78)
		btn.add_theme_font_size_override("font_size", 13)
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
		var wrap := Button.new()
		wrap.custom_minimum_size = Vector2(68, 88)
		wrap.focus_mode = Control.FOCUS_NONE
		wrap.clip_contents = true
		wrap.text = ""
		var card := VF.portrait_card(u, Vector2(64, 84), false)
		card.position = Vector2(2, 2)
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		wrap.add_child(card)
		var cost := Label.new()
		cost.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cost.text = "%d两" % int(u.get("cost", 50))
		AP.apply_label(cost, 10, AP.LANTERN_GOLD)
		cost.position = Vector2(4, 68)
		wrap.add_child(cost)
		wrap.pressed.connect(func():
			selected_unit_id = uid
			status_label.text = "已选 %s — 点空槽放置" % u.get("name", uid)
			Juice.play_sfx("tap")
			_refresh_roster_selection()
		)
		wrap.set_meta("unit_id", uid)
		roster_bar.add_child(wrap)


func _refresh_roster_selection() -> void:
	for b in roster_bar.get_children():
		if b is Button:
			var uid := str(b.get_meta("unit_id", ""))
			b.modulate = Color(1.15, 1.1, 0.9) if uid == selected_unit_id else Color.WHITE


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
	var center := _slot_center(slot)
	VF.placement_burst(units_layer, center, Color(AP.LANTERN_GOLD.r, AP.LANTERN_GOLD.g, AP.LANTERN_GOLD.b, 0.9))
	Juice.float_number(center + Vector2(0, -28), "-%d" % cost, Color(0.95, 0.78, 0.45))
	Juice.play_sfx("place")
	Juice.pulse(_slot_buttons[slot])
	if deployed.has(slot) and deployed[slot].node:
		Juice.pulse(deployed[slot].node, 1.18, 0.18)
		Juice.flash_modulate(deployed[slot].node, Color(1.35, 1.2, 0.9, 1.0), 0.2)
	_refresh_hud()
	_persist_prep()


func _highlight_slot(slot: int) -> void:
	for i in _slot_buttons.size():
		var b := _slot_buttons[i]
		b.modulate = Color(1.2, 1.15, 0.85) if i == slot else Color.WHITE


func _spawn_unit_visual(slot: int, unit_id: String) -> void:
	var u: Dictionary = ContentDB.get_unit(unit_id)
	# Larger frameless figure so it reads as a mini-character, not a card in the slot chrome.
	var node := VF.unit_node(u, Vector2(78, 100))
	var center := _slot_center(slot)
	# Feet near pad center — figure hangs upward from ground point.
	node.position = center - Vector2(node.custom_minimum_size.x * 0.5, node.custom_minimum_size.y * 0.82)
	units_layer.add_child(node)
	deployed[slot] = {
		"unit_id": unit_id,
		"hp": float(u.get("td", {}).get("hp", 100)),
		"max_hp": float(u.get("td", {}).get("hp", 100)),
		"cooldown": 0.0,
		"node": node,
		"pos": center,
	}
	# Strip ornate themed slot chrome so the figure stands free (keep hit target for select/recall).
	_flatten_slot_chrome(slot)
	VF.idle_bob(node, 2.5, 2.2 + randf() * 0.6)


func _flatten_slot_chrome(slot: int) -> void:
	var btn := _slot_buttons[slot]
	btn.text = ""
	btn.modulate = Color(1, 1, 1, 1)
	var empty := StyleBoxEmpty.new()
	btn.add_theme_stylebox_override("normal", empty)
	btn.add_theme_stylebox_override("hover", empty)
	btn.add_theme_stylebox_override("pressed", empty)
	btn.add_theme_stylebox_override("focus", empty)
	btn.add_theme_stylebox_override("disabled", empty)


func _restore_slot_chrome(slot: int) -> void:
	var btn := _slot_buttons[slot]
	btn.visible = true
	btn.remove_theme_stylebox_override("normal")
	btn.remove_theme_stylebox_override("hover")
	btn.remove_theme_stylebox_override("pressed")
	btn.remove_theme_stylebox_override("focus")
	btn.remove_theme_stylebox_override("disabled")
	btn.modulate = Color(0.85, 0.9, 0.8, 0.85)
	btn.text = "槽%d" % (slot + 1)


func _on_recall() -> void:
	if wave_running or selected_slot < 0 or not deployed.has(selected_slot):
		status_label.text = "选中有单位的槽再回收"
		return
	var info: Dictionary = deployed[selected_slot]
	var u: Dictionary = ContentDB.get_unit(info.unit_id)
	var refund := int(int(u.get("cost", 50)) * float(u.get("recall_refund", 0.5)))
	if GameState.is_morning_buff_live():
		refund = int(refund * 1.1)
	if _has_learned_hook("recall_refund_bonus"):
		refund = int(refund * 1.05)
	if "gear_linen_wrap" in GameState.gear_equipped:
		refund = int(refund * 1.05)
	silver += refund
	info.node.queue_free()
	deployed.erase(selected_slot)
	_restore_slot_chrome(selected_slot)
	status_label.text = "回收 +%d 银两" % refund
	Juice.play_sfx("recall")
	Juice.float_number(_slot_center(selected_slot), "+%d" % refund, Color(0.75, 0.9, 0.65))
	_refresh_hud()
	_persist_prep()


func _on_start_wave() -> void:
	if wave_running or awaiting_knowledge or game_over:
		return
	if wave_director == null or not wave_director.has_more(wave_index):
		status_label.text = "已达波次上限，可回大厅结算。"
		return
	var wave: Dictionary = wave_director.build_wave(wave_index)
	spawn_queue.clear()
	for spawn in wave.get("spawns", []):
		var delay := float(spawn.get("delay", 0.0))
		var lane := str(spawn.get("lane", "main"))
		for i in int(spawn.get("count", 1)):
			spawn_queue.append({
				"enemy": spawn.get("enemy", "enemy_bandit"),
				"interval": float(spawn.get("interval", 0.8)),
				"delay": delay if i == 0 else 0.0,
				"lane": lane,
			})
	spawn_timer = 0.35
	enemies_alive = 0
	wave_running = true
	_threat_armed = false
	start_wave_btn.disabled = true
	var label := str(wave.get("label", "第 %d 波" % (wave_index + 1)))
	wave_banner.text = "— %s —" % label
	status_label.text = str(wave.get("hint", "敌军来袭！"))
	VF.room_wipe(self, Color(0.05, 0.12, 0.10, 0.55))
	Juice.play_sfx("wave")
	Juice.screen_shake(field, 5.0)
	Juice.banner_pop(wave_banner, 1.8)
	Juice.pulse(start_wave_btn, 1.08, 0.18)
	# Main-lane wave telegraph always; flank when ambush spawns present
	if path_points.size() > 1:
		VF.wave_telegraph(field, path_points)
	var has_flank := false
	for spawn in wave.get("spawns", []):
		if str(spawn.get("lane", "main")) == "flank":
			has_flank = true
			break
	if has_flank and flank_path_points.size() > 1:
		VF.flank_telegraph(field, flank_path_points)
		Juice.play_sfx("flank")
		if _ambush_lbl:
			Juice.flash_modulate(_ambush_lbl, Color(1.4, 0.85, 0.7, 1.0), 0.35)
			Juice.pulse(_ambush_lbl, 1.2, 0.22)
		status_label.text = str(wave.get("hint", "敌军来袭！")) + " · 侧翼伏击！"
	_refresh_hud()


func _tick_spawns(delta: float) -> void:
	if spawn_queue.is_empty():
		return
	spawn_timer -= delta
	if spawn_timer > 0:
		return
	var job: Dictionary = spawn_queue.pop_front()
	_spawn_enemy(str(job.enemy), str(job.get("lane", "main")))
	if not spawn_queue.is_empty():
		spawn_timer = float(spawn_queue[0].get("delay", 0.0)) + float(spawn_queue[0].interval)


func _spawn_enemy(eid: String, lane: String = "main") -> void:
	var e: Dictionary = ContentDB.get_enemy(eid)
	var node := VF.enemy_node(e, Vector2(64, 84))
	var lane_path := _path_for_lane(lane)
	var scale := _wave_hp_scale()
	node.position = lane_path[0] - Vector2(node.custom_minimum_size.x * 0.5, node.custom_minimum_size.y * 0.78)
	node.modulate.a = 0.0
	enemies_layer.add_child(node)
	node.set_meta("eid", eid)
	node.set_meta("hp", float(e.get("hp", 50)) * scale)
	node.set_meta("max_hp", float(e.get("hp", 50)) * scale)
	node.set_meta("speed", float(e.get("speed", 50)) * (1.0 + 0.02 * wave_index))
	node.set_meta("armor", float(e.get("armor", 0)))
	node.set_meta("reward", int(e.get("reward", 10)) + wave_index / 2)
	node.set_meta("leak", int(e.get("leak_damage", 1)))
	node.set_meta("path_i", 0)
	node.set_meta("progress", 0.0)
	node.set_meta("lane", lane)
	if lane == "flank" and node is Control:
		(node as Control).modulate = Color(1.15, 0.85, 0.8, 0.0)
	if node is Control:
		VF.set_enemy_hp_ratio(node as Control, 1.0)
		var spawn_at: Vector2 = lane_path[0]
		VF.placement_ring(enemies_layer, spawn_at, Color(0.95, 0.55, 0.4, 0.7) if lane == "flank" else Color(0.85, 0.75, 0.45, 0.65))
		var tw := (node as Control).create_tween()
		tw.tween_property(node, "modulate:a", 1.0, 0.16)
	enemies_alive += 1


func _path_for_lane(lane: String) -> PackedVector2Array:
	if lane == "flank" and flank_path_points.size() > 1:
		return flank_path_points
	return path_points


func _wave_hp_scale() -> float:
	if wave_director == null:
		return 1.0
	# Soft escalate like ape1121 difficulty curve without exploding early waves.
	return 1.0 + maxf(0.0, (wave_director.difficulty_at(wave_index) - 1.0) * 0.22)


func _tick_movement(delta: float) -> void:
	for node in enemies_layer.get_children():
		if not node.has_meta("eid"):
			continue
		var lane := str(node.get_meta("lane", "main"))
		var pts := _path_for_lane(lane)
		var path_i: int = int(node.get_meta("path_i"))
		if path_i >= pts.size() - 1:
			_leak(node)
			continue
		var a: Vector2 = pts[path_i]
		var b: Vector2 = pts[path_i + 1]
		var dist := a.distance_to(b)
		var prog: float = float(node.get_meta("progress"))
		prog += float(node.get_meta("speed")) * delta
		while prog >= dist and path_i < pts.size() - 1:
			prog -= dist
			path_i += 1
			node.set_meta("path_i", path_i)
			if path_i >= pts.size() - 1:
				break
			a = pts[path_i]
			b = pts[path_i + 1]
			dist = a.distance_to(b)
		node.set_meta("progress", prog)
		if path_i >= pts.size() - 1:
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
		atk *= 1.0 + 0.02 * GameState.effective_mastery(info.unit_id)
		atk *= float(GameState.knowledge_meta_bonuses().get("td_atk_mult", 1.0))
		if _has_learned_hook("unit_atk_small"):
			atk *= 1.03
		atk *= _atk_buff_multiplier(info.pos)
		var armor: float = float(target.get_meta("armor"))
		var dmg := maxf(1.0, atk - armor * 0.5)
		target.set_meta("hp", float(target.get_meta("hp")) - dmg)
		info.cooldown = float(td.get("attack_interval", 1.0))
		deployed[slot] = info
		var hit_pos: Vector2 = target.position + target.custom_minimum_size * 0.5
		var flash := Color(1.0, 0.9, 0.55, 0.9)
		var unit_node: Control = info.node if info.node is Control else null
		if unit_node and target is Control:
			VF.td_attack_fx(enemies_layer, unit_node, target as Control, flash)
		else:
			VF.hit_impact(enemies_layer, hit_pos, flash)
		Juice.float_number(hit_pos, str(int(dmg)), Color(1, 0.85, 0.45))
		var hp_now := float(target.get_meta("hp"))
		var hp_max := float(target.get_meta("max_hp"))
		if target is Control:
			VF.set_enemy_hp_ratio(target as Control, hp_now / maxf(hp_max, 1.0))
			_flash_enemy(target as Control)
		Juice.play_sfx("hit")
		if hp_now <= 0:
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
				if not node.has_meta("eid"):
					continue
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
		if not node.has_meta("eid"):
			continue
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
	var at: Vector2 = node.position + (node.custom_minimum_size * 0.5 if node is Control else Vector2.ZERO)
	Juice.float_number(at, "+%d" % reward, Color(0.7, 0.95, 0.65))
	VF.death_puff(enemies_layer, at)
	VF.placement_ring(enemies_layer, at, Color(0.95, 0.7, 0.4, 0.7))
	Juice.play_sfx("kill")
	node.queue_free()
	_refresh_hud()


func _flash_enemy(node: Control) -> void:
	if node == null:
		return
	var base := node.modulate
	node.modulate = Color(1.4, 1.2, 1.05, 1.0)
	var tw := node.create_tween()
	tw.tween_property(node, "modulate", base, 0.1)


func _leak(node: Node) -> void:
	lives -= int(node.get_meta("leak"))
	enemies_alive = max(0, enemies_alive - 1)
	Juice.screen_shake(field, 8.0)
	Juice.play_sfx("lose")
	Juice.threaten(hud_lives, 2)
	if _gate_node_ref:
		Juice.threaten(_gate_node_ref, 2)
	var gate_pt: Vector2 = path_points[path_points.size() - 1] if path_points.size() > 0 else Vector2.ZERO
	VF.hit_impact(enemies_layer, gate_pt, Color(0.95, 0.4, 0.3, 0.9))
	VF.slash_arc(enemies_layer, gate_pt, Color(0.95, 0.4, 0.3, 0.9), 1.1)
	node.queue_free()
	_refresh_hud()
	if lives <= 0:
		_defeat()


func _on_wave_cleared() -> void:
	wave_running = false
	_threat_armed = false
	start_wave_btn.disabled = false
	var wave: Dictionary = wave_director.build_wave(wave_index) if wave_director else {}
	silver += int(wave.get("silver_bonus", 30))
	wave_index += 1
	_refresh_hud()
	_update_wave_preview()
	status_label.text = "波次肃清。可调整阵容后点「下一波」。"
	Juice.play_sfx("win")
	Juice.pulse(hud_wave, 1.08, 0.16)
	if not GameState.unlocked_units.is_empty():
		var uid: String = GameState.unlocked_units[wave_index % GameState.unlocked_units.size()]
		GameState.add_fragments(uid, 1)
	if wave_index >= 5:
		GameState.unlock_unit("unit_zhaoyun")
	if wave_index >= 8:
		GameState.unlock_unit("unit_mingwang")
	# Soft milestone (seed chapter clear) — infinite run continues until leak-out.
	var milestone := int(ContentDB.waves_cfg.get("milestone_wave", 10))
	if not milestone_cleared and wave_index >= milestone:
		milestone_cleared = true
		GameState.total_td_clears += 1
		if GameState.total_td_clears >= 1:
			GameState.unlock_gear("gear_bamboo_cup")
		GameState.silver_bank += silver / 8
		GameState.persist_meta_keep_checkpoints()
		status_label.text = "第一章里程碑达成！无限波仍可继续，或存档回大厅。"
	var kid = wave.get("knowledge_card", null)
	_persist_prep()
	if kid != null and str(kid) != "":
		awaiting_knowledge = true
		knowledge_layer.present(str(kid))


func _on_knowledge_resolved(_id: String, _correct: bool) -> void:
	awaiting_knowledge = false
	_persist_prep()
	status_label.text = "知识已记入。准备下一波。"


func _has_learned_hook(hook_name: String) -> bool:
	for kid in GameState.knowledge_seen:
		if int(GameState.knowledge_correct.get(kid, 0)) <= 0:
			continue
		if ContentDB.knowledge_hook(str(kid), "td") == hook_name:
			return true
	return false


func _victory() -> void:
	# Retained for rare finite-mode / smoke callers; infinite default uses milestone.
	game_over = true
	GameState.total_td_clears += 1
	GameState.silver_bank += silver / 5
	if GameState.total_td_clears >= 1:
		GameState.unlock_gear("gear_bamboo_cup")
	GameState.td_checkpoint = {}
	GameState.persist_lobby()
	result_overlay.show_result(
		"剑阁无恙",
		"守住栈道。\n银两仓 +%d · 碎片已写入。" % (silver / 5),
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


func _load_checkpoint(cp: Dictionary) -> void:
	silver = int(cp.get("silver", 200))
	lives = int(cp.get("lives", 12))
	wave_index = int(cp.get("wave_index", 0))
	milestone_cleared = bool(cp.get("milestone_cleared", wave_index >= int(ContentDB.waves_cfg.get("milestone_wave", 10))))
	for item in cp.get("deployed", []):
		_spawn_unit_visual(int(item.slot), str(item.unit_id))
		if deployed.has(int(item.slot)):
			deployed[int(item.slot)].hp = float(item.get("hp", deployed[int(item.slot)].hp))
	status_label.text = "已从波次前存档续关。"
	_update_wave_preview()
	_refresh_hud()


func _persist_prep() -> void:
	var dep: Array = []
	for slot in deployed.keys():
		dep.append({"slot": slot, "unit_id": deployed[slot].unit_id, "hp": deployed[slot].hp})
	GameState.persist_td({
		"silver": silver,
		"lives": lives,
		"wave_index": wave_index,
		"deployed": dep,
		"milestone_cleared": milestone_cleared,
	})


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
	if wave_director == null or not wave_director.has_more(wave_index):
		status_label.text = "已达波次上限。"
		return
	var wave: Dictionary = wave_director.build_wave(wave_index)
	var label := str(wave.get("label", "第 %d 波" % (wave_index + 1)))
	status_label.text = "待命：%s — %s" % [label, str(wave.get("hint", ""))]


func _refresh_hud() -> void:
	hud_silver.text = "银两 · %d" % silver
	hud_lives.text = "据点 · %d" % lives
	if lives <= 3:
		hud_lives.add_theme_color_override("font_color", Color(0.95, 0.45, 0.35))
	else:
		hud_lives.add_theme_color_override("font_color", AP.PAPER_INK)
	hud_wave.text = "波次 · %d · ∞" % (wave_index + 1)
	start_wave_btn.text = "下一波 · 第 %d 波" % (wave_index + 1)
	start_wave_btn.disabled = wave_running or awaiting_knowledge or game_over
