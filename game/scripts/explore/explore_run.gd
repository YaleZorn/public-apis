extends Control
## M3 搜打撤：饥荒气质节点图 · 搜材料 → 打遭遇 → 撤据点结算。
## 自动普攻 + 点主动；单英雄接大厅花名册；节点边界可存。

const KnowledgeCardScene := preload("res://scenes/knowledge/knowledge_card.tscn")
const ResultOverlayScene := preload("res://scenes/ui/result_overlay.tscn")
const VF := preload("res://scripts/util/visual_factory.gd")
const Atmo := preload("res://scripts/util/atmosphere.gd")
const AP := preload("res://scripts/util/art_palette.gd")
const RunBag := preload("res://scripts/explore/run_bag.gd")

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
@onready var bag_label: Label = %BagLabel
@onready var map_layer: Control = %MapLayer
@onready var exit_row: HBoxContainer = %ExitRow
@onready var craft_row: HBoxContainer = %CraftRow

var hero_id: String = "unit_feidao"
var hp: float = 120
var max_hp: float = 120
var atk: float = 28
var attack_interval: float = 0.65
var attack_cd: float = 0.0
var skill: Dictionary = {}
var skill_cd: float = 0.0
var combat_active: bool = false
var enemies: Array = []
var knowledge_layer: CanvasLayer
var result_overlay: CanvasLayer
var awaiting_knowledge: bool = false
var shield: float = 0.0
var slow_all_timer: float = 0.0
var game_done: bool = false
var node_completed: bool = false
var _hero_visual: Control

# --- 搜打撤 map ---
var bag: RefCounted ## ExploreRunBag
var node_id: String = "settle"
var nodes_visited: int = 0
var cleared_once: Dictionary = {} ## node_id -> true
var showing_map: bool = false
var night_pressure: bool = false


func _ready() -> void:
	bag = RunBag.new()
	Atmo.attach_full_bg(self, "night")
	var old_bg := get_node_or_null("Bg")
	if old_bg:
		old_bg.visible = false
	AP.apply_label(room_label, 22, AP.LANTERN_GOLD)
	AP.apply_label(hp_label, 15, AP.PAPER_DIM)
	AP.apply_label(status_label, 14, AP.PAPER_DIM)
	AP.apply_label(loot_label, 15, AP.LANTERN_GOLD)
	AP.apply_label(bag_label, 14, Color(0.72, 0.82, 0.7, 1))
	Juice.start_explore_music()
	knowledge_layer = KnowledgeCardScene.instantiate()
	add_child(knowledge_layer)
	knowledge_layer.resolved.connect(_on_knowledge_resolved)
	result_overlay = ResultOverlayScene.instantiate()
	add_child(result_overlay)
	skill_btn.pressed.connect(_cast_skill)
	next_btn.pressed.connect(_on_next_or_map)
	flee_btn.pressed.connect(_on_withdraw_or_flee)
	lobby_btn.pressed.connect(_save_and_lobby)
	loot_label.visible = false
	next_btn.text = "选路"
	flee_btn.text = "撤离结算"
	if not GameState.explore_checkpoint.is_empty():
		_load_checkpoint(GameState.explore_checkpoint)
	else:
		hero_id = GameState.explore_hero_id
		if hero_id not in GameState.unlocked_units and not GameState.unlocked_units.is_empty():
			hero_id = GameState.unlocked_units[0]
		_init_hero_stats()
		node_id = str(ContentDB.rooms_cfg.get("start_node", "settle"))
		shield = 25 if GameState.is_morning_buff_live() else 0
		shield += int(GameState.knowledge_meta_bonuses().get("explore_shield", 0))
		if "gear_bamboo_cup" in GameState.gear_equipped:
			shield += 10
		if "gear_demo_trail_charm" in GameState.gear_equipped:
			shield += 8
		_apply_explore_hooks()
		_enter_node()
	_refresh()


func _apply_explore_hooks() -> void:
	## Light knowledge explore_hooks — only once each, subway-friendly numbers.
	var applied: Dictionary = {}
	for kid in GameState.knowledge_seen:
		if int(GameState.knowledge_correct.get(kid, 0)) <= 0:
			continue
		var hook := ContentDB.knowledge_hook(str(kid), "explore")
		if hook == "" or applied.has(hook):
			continue
		applied[hook] = true
		match hook:
			"start_shield_small":
				shield += 12
			"heal_on_enter":
				# Applied as small max-hp pad so first room feels safer.
				max_hp += 8
				hp = mini(hp + 8, max_hp)
			"atk_buff_room":
				atk *= 1.04
			"max_hp_small":
				max_hp += 10
				hp = mini(hp + 10, max_hp)
			"energy_room":
				shield += 6
			_:
				pass
	max_hp += float(GameState.knowledge_meta_bonuses().get("explore_max_hp", 0))
	hp = mini(hp + float(GameState.knowledge_meta_bonuses().get("explore_max_hp", 0)), max_hp)


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
	_hero_visual = VF.unit_node(u, Vector2(96, 112))
	_hero_visual.position = hero_node.position
	hero_node.visible = false
	arena.add_child(_hero_visual)
	VF.idle_bob(_hero_visual, 4.0, 2.6)


func _process(delta: float) -> void:
	if game_done or awaiting_knowledge or showing_map:
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


func _enter_node() -> void:
	combat_active = false
	showing_map = false
	enemies.clear()
	for c in enemies_layer.get_children():
		c.queue_free()
	map_layer.visible = false
	_clear_exit_row()
	_clear_craft_row()
	VF.room_wipe(self, Color(0.04, 0.10, 0.09, 0.7))
	_rebuild_visited_strip()
	var node: Dictionary = ContentDB.get_node_cfg(node_id)
	if node.is_empty():
		status_label.text = "节点缺失，回据点。"
		node_id = "settle"
		node = ContentDB.get_node_cfg(node_id)
	var rtype := str(node.get("type", "combat"))
	var run_name := str(ContentDB.rooms_cfg.get("display_name", "荒山搜打撤"))
	room_label.text = "%s · %s" % [run_name, node.get("label", rtype)]
	_apply_room_atmosphere(rtype)
	Juice.pulse(room_label, 1.06, 0.18)
	Juice.play_sfx("room")
	next_btn.visible = false
	loot_label.visible = false
	var pressure_after := int(ContentDB.rooms_cfg.get("night_pressure_after", 5))
	night_pressure = nodes_visited >= pressure_after
	match rtype:
		"settle":
			flee_btn.disabled = false
			flee_btn.text = "撤离回大厅"
			status_label.text = str(node.get("blurb", "据点：打造或撤离，材料入库。"))
			_show_settle_ui()
			node_completed = true
			_persist()
		"combat":
			flee_btn.disabled = false
			flee_btn.text = "战斗撤离"
			if node_completed:
				status_label.text = "本区已清。选路继续或回据点。"
				_show_path_choices()
			else:
				status_label.text = "遭遇敌人 · 自动普攻，点按主动技。" + (" 夜压↑" if night_pressure else "")
				_spawn_room_enemies(node.get("enemies", []))
				combat_active = true
		"event":
			flee_btn.disabled = true
			if node_completed:
				status_label.text = "事件已处理。选路。"
				_show_path_choices()
			else:
				status_label.text = "事件：功法笺。"
				awaiting_knowledge = true
				knowledge_layer.present(str(node.get("knowledge_card", "k_form")))
		"gather", "loot":
			flee_btn.disabled = true
			if node_completed or (bool(node.get("once", false)) and cleared_once.get(node_id, false)):
				status_label.text = "此处已搜过。选路。"
				_show_path_choices()
			else:
				_grant_node_loot(node)
				node_completed = true
				cleared_once[node_id] = true
				_show_path_choices()
				_persist()
		"train":
			flee_btn.disabled = true
			if not node_completed:
				var heal := float(node.get("heal", 20))
				hp = minf(max_hp, hp + heal)
				_show_loot("吐纳 +%d HP" % int(heal), Color(0.6, 0.85, 0.65))
				node_completed = true
			status_label.text = "吐纳毕。选路。"
			_show_path_choices()
			_persist()
		"supply":
			flee_btn.disabled = true
			if not node_completed:
				var heal2 := float(node.get("heal", 30))
				hp = minf(max_hp, hp + heal2)
				var sil := int(node.get("silver", 0))
				GameState.silver_bank += sil
				if node.has("materials"):
					bag.add_dict(node.get("materials", {}))
				_show_loot("补给 +%d HP · 银+%d · %s" % [
					int(heal2), sil, bag.summary_text(ContentDB.materials)
				], Color(0.75, 0.82, 0.55))
				node_completed = true
			_show_path_choices()
			_persist()
		_:
			_show_path_choices()
	_refresh()


func _grant_node_loot(node: Dictionary) -> void:
	var mats: Dictionary = node.get("materials", {})
	bag.add_dict(mats)
	var frags := int(node.get("fragments", 0))
	if frags > 0:
		GameState.add_fragments(hero_id, frags)
	var bits: PackedStringArray = []
	if not mats.is_empty():
		bits.append(bag.summary_text(ContentDB.materials))
	if frags > 0:
		bits.append("碎片+%d" % frags)
	_show_loot("搜获 · " + (" · ".join(bits) if not bits.is_empty() else "空"), Color(0.9, 0.75, 0.45))


func _show_settle_ui() -> void:
	next_btn.visible = true
	next_btn.text = "出山搜打"
	_rebuild_map(true)
	map_layer.visible = true
	showing_map = true
	_rebuild_craft_row()
	# Deposit preview — bag stays until explicit withdraw or deposit-at-settle.
	if not bag.is_empty():
		status_label.text = "据点可入库背包，或继续出山。当前背包：%s" % bag.summary_text(ContentDB.materials)
		var deposit_btn := Button.new()
		deposit_btn.text = "入库背包"
		deposit_btn.custom_minimum_size = Vector2(0, 44)
		deposit_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		deposit_btn.pressed.connect(_deposit_bag_full)
		exit_row.add_child(deposit_btn)


func _deposit_bag_full() -> void:
	if bag.is_empty():
		status_label.text = "背包已空。"
		return
	var got := GameState.deposit_run_bag(bag.duplicate_bag(), 1.0)
	bag.clear()
	_show_loot("入库 · %s" % _dict_summary(got), Color(0.65, 0.88, 0.7))
	GameState.persist_meta_keep_checkpoints()
	_persist()
	_refresh()
	_rebuild_craft_row()


func _rebuild_craft_row() -> void:
	_clear_craft_row()
	for recipe in ContentDB.recipes:
		var rid := str(recipe.get("id", ""))
		var b := Button.new()
		b.custom_minimum_size = Vector2(0, 40)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var ok := GameState.can_craft(rid)
		b.text = str(recipe.get("name", rid))
		b.disabled = not ok
		b.tooltip_text = str(recipe.get("blurb", ""))
		b.pressed.connect(func():
			var res: Dictionary = GameState.craft_recipe(rid, hero_id)
			if res.get("ok", false):
				Juice.play_sfx("win")
				_show_loot("打造完成 · %s" % recipe.get("name", rid), Color(0.75, 0.85, 0.55))
			else:
				status_label.text = str(res.get("reason", "无法打造"))
			_rebuild_craft_row()
			_refresh()
		)
		craft_row.add_child(b)


func _show_path_choices() -> void:
	next_btn.visible = true
	next_btn.text = "打开地图"
	flee_btn.disabled = false
	flee_btn.text = "回据点"
	_rebuild_map(false)
	map_layer.visible = true
	showing_map = true
	_rebuild_exit_buttons()


func _rebuild_exit_buttons() -> void:
	_clear_exit_row()
	var node: Dictionary = ContentDB.get_node_cfg(node_id)
	for eid in node.get("exits", []):
		var dest: Dictionary = ContentDB.get_node_cfg(str(eid))
		var b := Button.new()
		b.custom_minimum_size = Vector2(0, 48)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var tname := _room_type_name(str(dest.get("type", "")))
		b.text = "%s · %s" % [tname, dest.get("label", eid)]
		var target := str(eid)
		b.pressed.connect(func(): _travel_to(target))
		exit_row.add_child(b)


func _rebuild_map(from_settle: bool) -> void:
	for c in map_layer.get_children():
		c.queue_free()
	var title := Label.new()
	title.text = "荒山节点 · 搜打撤"
	AP.apply_label(title, 14, AP.MIST_TEAL.lightened(0.2))
	title.position = Vector2(8, 4)
	map_layer.add_child(title)
	var size := map_layer.size
	if size.x < 10:
		size = Vector2(680, 220)
	for n in ContentDB.rooms_cfg.get("nodes", []):
		var pos_arr: Array = n.get("map_pos", [0.5, 0.5])
		var px := float(pos_arr[0]) * (size.x - 72)
		var py := float(pos_arr[1]) * (size.y - 36) + 22
		var btn := Button.new()
		btn.position = Vector2(px, py)
		btn.custom_minimum_size = Vector2(70, 32)
		var nid := str(n.get("id", ""))
		var rtype := str(n.get("type", ""))
		btn.text = _room_type_name(rtype)
		btn.tooltip_text = str(n.get("label", nid))
		if nid == node_id:
			btn.modulate = AP.LANTERN_GOLD
		elif cleared_once.get(nid, false):
			btn.modulate = Color(0.55, 0.75, 0.6, 1)
		else:
			btn.modulate = _type_color(rtype)
		var reachable := from_settle or _is_exit(nid)
		btn.disabled = not reachable and nid != node_id
		if reachable and nid != node_id:
			btn.pressed.connect(func(): _travel_to(nid))
		map_layer.add_child(btn)


func _is_exit(nid: String) -> bool:
	var node: Dictionary = ContentDB.get_node_cfg(node_id)
	return nid in node.get("exits", [])


func _type_color(rtype: String) -> Color:
	match rtype:
		"combat": return Color(0.75, 0.45, 0.4, 1)
		"gather", "loot": return Color(0.75, 0.7, 0.4, 1)
		"settle": return Color(0.45, 0.7, 0.65, 1)
		"event": return Color(0.45, 0.55, 0.75, 1)
		"train": return Color(0.4, 0.65, 0.5, 1)
		"supply": return Color(0.65, 0.6, 0.4, 1)
		_: return Color(0.5, 0.55, 0.5, 1)


func _travel_to(target: String) -> void:
	if game_done or awaiting_knowledge or combat_active:
		return
	Juice.play_sfx("tap")
	Juice.fade_transition(func():
		nodes_visited += 1
		node_id = target
		node_completed = false
		showing_map = false
		_persist()
		_enter_node()
	, Color(0.03, 0.09, 0.08, 1.0), 0.28)


func _on_next_or_map() -> void:
	if awaiting_knowledge or game_done:
		return
	if str(ContentDB.get_node_cfg(node_id).get("type", "")) == "settle":
		# Open exits from settle — prefer first gather/combat.
		_show_path_choices()
		status_label.text = "选一条出路：搜 / 打。"
		return
	if not showing_map:
		_show_path_choices()
	else:
		status_label.text = "点地图节点或下方出路。"


func _apply_room_atmosphere(rtype: String) -> void:
	var full := get_node_or_null("AtmosphereBg") as TextureRect
	if full:
		var path := Atmo.explore_room_path(rtype)
		if ResourceLoader.exists(path) or FileAccess.file_exists(path):
			full.texture = load(path)
			full.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	Atmo.apply_explore_room(arena, rtype)
	var accent := get_node_or_null("Arena/ArenaAccent")
	if accent:
		match rtype:
			"combat":
				accent.color = Color(0.35, 0.18, 0.14, 0.32)
			"event":
				accent.color = Color(0.14, 0.24, 0.38, 0.35)
			"train":
				accent.color = Color(0.14, 0.34, 0.24, 0.32)
			"loot", "supply", "gather", "settle":
				accent.color = Color(0.42, 0.34, 0.14, 0.35)
			_:
				accent.color = Color(0.08, 0.1, 0.12, 0.4)
	var edge := get_node_or_null("ExploreMist")
	if edge == null:
		edge = ColorRect.new()
		edge.name = "ExploreMist"
		edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		edge.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(edge)
		move_child(edge, 1)
	(edge as ColorRect).color = Color(0.03, 0.08, 0.07, 0.14 if night_pressure else 0.1)


func _room_type_name(t: String) -> String:
	match t:
		"combat": return "打"
		"event": return "事"
		"train": return "修"
		"supply": return "补"
		"loot", "gather": return "搜"
		"settle": return "据"
		_: return t


func _rebuild_visited_strip() -> void:
	for c in room_strip.get_children():
		c.queue_free()
	var tip := Label.new()
	tip.text = "访%d · 包%d" % [nodes_visited, bag.total_count()]
	tip.add_theme_font_size_override("font_size", 12)
	AP.apply_label(tip, 12, AP.PAPER_DIM)
	room_strip.add_child(tip)
	for n in ContentDB.rooms_cfg.get("nodes", []):
		var wrap := ColorRect.new()
		wrap.custom_minimum_size = Vector2(14, 10)
		var nid := str(n.get("id", ""))
		if nid == node_id:
			wrap.color = AP.LANTERN_GOLD
		elif cleared_once.get(nid, false):
			wrap.color = Color(0.35, 0.62, 0.5)
		else:
			wrap.color = _type_color(str(n.get("type", ""))).darkened(0.35)
		room_strip.add_child(wrap)


func _spawn_room_enemies(ids: Array) -> void:
	var i := 0
	var atk_scale := 1.12 if night_pressure else 1.0
	for eid in ids:
		var e: Dictionary = ContentDB.get_enemy(str(eid))
		var node := VF.enemy_node(e, Vector2(84, 100))
		node.position = Vector2(340 + (i % 2) * 100, 120 + i * 110)
		node.modulate.a = 0.0
		enemies_layer.add_child(node)
		VF.idle_bob(node, 2.5, 2.2 + i * 0.15)
		var tw := node.create_tween()
		tw.tween_property(node, "modulate:a", 1.0, 0.22)
		tw.parallel().tween_property(node, "position:x", node.position.x - 12.0, 0.22).set_trans(Tween.TRANS_BACK)
		var emax := float(e.get("hp", 50)) * 0.85
		VF.set_enemy_hp_ratio(node, 1.0)
		enemies.append({
			"id": eid,
			"hp": emax,
			"max_hp": emax,
			"atk": (8.0 + float(e.get("leak_damage", 1)) * 4.0) * atk_scale,
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
	VF.hit_flash(enemies_layer, pos, Color(1.0, 0.92, 0.55, 0.9))
	VF.set_enemy_hp_ratio(target.node, target.hp / maxf(target.max_hp, 1.0))
	Juice.play_sfx("hit")
	_pulse(_hero_visual)
	_pulse(target.node)
	if target.hp <= 0:
		VF.death_puff(enemies_layer, pos, Color(0.95, 0.5, 0.35, 0.85))
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
	if skill_cd > 0 or awaiting_knowledge or game_done or showing_map:
		return
	if not combat_active and enemies.is_empty():
		return
	var effect := str(skill.get("effect", ""))
	var value := float(skill.get("value", 0))
	var burst_col := Color(0.7, 0.88, 0.75, 0.8)
	match effect:
		"aoe_damage":
			burst_col = Color(0.95, 0.55, 0.35, 0.85)
			for enemy in enemies.duplicate():
				enemy.hp -= value
				Juice.float_number(enemy.node.position, str(int(value)), Color(0.95, 0.7, 0.45))
				VF.hit_flash(enemies_layer, enemy.node.position + enemy.node.custom_minimum_size * 0.5, burst_col)
				VF.set_enemy_hp_ratio(enemy.node, enemy.hp / maxf(enemy.max_hp, 1.0))
				if enemy.hp <= 0:
					VF.death_puff(enemies_layer, enemy.node.position + enemy.node.custom_minimum_size * 0.5)
					enemy.node.queue_free()
					enemies.erase(enemy)
		"heal":
			burst_col = Color(0.55, 0.9, 0.65, 0.85)
			hp = minf(max_hp, hp + value)
			Juice.float_number(_hero_visual.position, "+%d" % int(value), Color(0.55, 0.9, 0.6))
		"shield":
			burst_col = Color(0.55, 0.75, 0.95, 0.85)
			shield += value
			Juice.float_number(_hero_visual.position, "盾+%d" % int(value), Color(0.55, 0.75, 0.95))
		"slow_all":
			burst_col = Color(0.55, 0.75, 0.95, 0.8)
			slow_all_timer = float(skill.get("duration", 2.0))
			for enemy in enemies:
				if enemy.node:
					enemy.node.modulate = Color(0.65, 0.8, 1.1, 1.0)
		_:
			for enemy in enemies.duplicate():
				enemy.hp -= value
				VF.set_enemy_hp_ratio(enemy.node, enemy.hp / maxf(enemy.max_hp, 1.0))
				if enemy.hp <= 0:
					VF.death_puff(enemies_layer, enemy.node.position + enemy.node.custom_minimum_size * 0.5)
					enemy.node.queue_free()
					enemies.erase(enemy)
	skill_cd = float(skill.get("cooldown", 8.0))
	var burst_at: Vector2 = arena.size * 0.5
	if _hero_visual:
		burst_at = _hero_visual.position + _hero_visual.custom_minimum_size * 0.5
	VF.skill_burst(arena, burst_at, burst_col)
	Juice.play_sfx("skill")
	Juice.screen_shake(arena, 5.0)
	_refresh_skill_btn()
	_refresh()
	if enemies.is_empty() and combat_active:
		_on_combat_cleared()


func _on_combat_cleared() -> void:
	combat_active = false
	node_completed = true
	cleared_once[node_id] = true
	var node: Dictionary = ContentDB.get_node_cfg(node_id)
	var loot: Dictionary = node.get("loot", {})
	bag.add_dict(loot)
	GameState.add_mastery(hero_id, 1)
	GameState.add_fragments(hero_id, int(node.get("fragments", 1)))
	_show_loot("清场 · %s · 熟练+1" % bag.summary_text(ContentDB.materials), Color(0.72, 0.88, 0.62))
	if bool(node.get("boss", false)):
		GameState.total_explore_clears += 1
		if GameState.total_explore_clears >= 1:
			GameState.unlock_gear("gear_linen_wrap")
	_show_path_choices()
	_persist()


func _show_loot(text: String, col: Color) -> void:
	status_label.text = text
	loot_label.text = text
	loot_label.add_theme_color_override("font_color", col)
	loot_label.visible = true
	Juice.play_sfx("win")
	Juice.pulse(loot_label, 1.08, 0.2)


func _on_knowledge_resolved(_id: String, correct: bool) -> void:
	awaiting_knowledge = false
	node_completed = true
	cleared_once[node_id] = true
	if correct:
		var bonus := 15
		if "gear_jade_token" in GameState.gear_equipped:
			bonus += 5
		hp = minf(max_hp, hp + bonus)
		bag.add("mat_herb", 1)
		status_label.text = "答对，恢复 +%d HP · 药草+1。" % bonus
	else:
		status_label.text = "已记下正解。选路继续。"
	_show_path_choices()
	_persist()
	_refresh()


func _on_withdraw_or_flee() -> void:
	if game_done:
		return
	var rtype := str(ContentDB.get_node_cfg(node_id).get("type", ""))
	if combat_active:
		# Mid-combat flee: keep half bag.
		_settle_run(0.5, "战斗撤离", "半袋物资带回据点入库。\n银两仓 +5。", true)
		return
	if rtype == "settle":
		_settle_run(1.0, "撤离结算", "全部背包入库 · 回大厅。", false)
		return
	# Non-combat: return to settle node with full bag (interrupt-friendly).
	Juice.play_sfx("tap")
	Juice.fade_transition(func():
		node_id = "settle"
		node_completed = true
		_persist()
		_enter_node()
	)


func _settle_run(keep_ratio: float, title: String, blurb: String, add_silver: bool) -> void:
	game_done = true
	combat_active = false
	if add_silver:
		GameState.silver_bank += 5
	var got := GameState.deposit_run_bag(bag.duplicate_bag(), keep_ratio)
	bag.clear()
	GameState.explore_checkpoint = {}
	GameState.persist_lobby()
	var detail := "%s\n入库：%s\n仓材料：%s" % [blurb, _dict_summary(got), GameState.materials_summary()]
	result_overlay.show_result(
		title,
		detail,
		"回大厅",
		Color(0.65, 0.75, 0.85),
		func(): GameState.go_lobby()
	)


func _defeat() -> void:
	game_done = true
	combat_active = false
	# Failure carries less — keep 40%.
	var got := GameState.deposit_run_bag(bag.duplicate_bag(), 0.4)
	bag.clear()
	GameState.explore_checkpoint = {}
	GameState.persist_lobby()
	result_overlay.show_result(
		"力竭撤离",
		"战败少带出（约四成）。\n入库：%s\n知识进度保留。" % _dict_summary(got),
		"回大厅",
		Color(0.85, 0.45, 0.4),
		func(): GameState.go_lobby()
	)


func _dict_summary(d: Dictionary) -> String:
	if d.is_empty():
		return "无"
	var parts: PackedStringArray = []
	for k in d.keys():
		parts.append("%s×%d" % [ContentDB.get_material(str(k)).get("name", k), int(d[k])])
	return " · ".join(parts)


func _persist() -> void:
	GameState.persist_explore({
		"hero_id": hero_id,
		"hp": hp,
		"max_hp": max_hp,
		"shield": shield,
		"node_id": node_id,
		"skill_cd": skill_cd,
		"node_completed": node_completed,
		"nodes_visited": nodes_visited,
		"bag": bag.duplicate_bag(),
		"cleared_once": cleared_once.duplicate(),
	})


func _load_checkpoint(cp: Dictionary) -> void:
	hero_id = str(cp.get("hero_id", GameState.explore_hero_id))
	_init_hero_stats()
	hp = float(cp.get("hp", max_hp))
	max_hp = float(cp.get("max_hp", max_hp))
	shield = float(cp.get("shield", 0))
	# Migrate legacy room_index checkpoints → settle.
	if cp.has("node_id"):
		node_id = str(cp.get("node_id", "settle"))
	else:
		node_id = str(ContentDB.rooms_cfg.get("start_node", "settle"))
	skill_cd = float(cp.get("skill_cd", 0))
	node_completed = bool(cp.get("node_completed", cp.get("room_completed", false)))
	nodes_visited = int(cp.get("nodes_visited", 0))
	bag.load_from(cp.get("bag", {}))
	cleared_once = cp.get("cleared_once", {})
	if typeof(cleared_once) != TYPE_DICTIONARY:
		cleared_once = {}
	status_label.text = "已从节点边界存档续关。"
	_enter_node()


func _save_and_lobby() -> void:
	if combat_active:
		status_label.text = "战斗中请先清场或战斗撤离"
		return
	_persist()
	Juice.fade_transition(func(): GameState.go_lobby())


func _refresh() -> void:
	hp_label.text = "HP %d/%d%s" % [int(hp), int(max_hp), (" ·盾%d" % int(shield)) if shield > 0 else ""]
	hp_bar.max_value = max_hp
	hp_bar.value = hp
	bag_label.text = "背包 %s" % bag.summary_text(ContentDB.materials)
	_refresh_skill_btn()


func _refresh_skill_btn() -> void:
	if skill_cd > 0.05:
		skill_btn.text = "%s (%.1fs)" % [skill.get("name", "技能"), skill_cd]
		skill_btn.disabled = true
	else:
		skill_btn.text = str(skill.get("name", "技能"))
		skill_btn.disabled = (not combat_active and enemies.is_empty()) or showing_map


func _clear_exit_row() -> void:
	for c in exit_row.get_children():
		c.queue_free()


func _clear_craft_row() -> void:
	for c in craft_row.get_children():
		c.queue_free()


func _pulse(node: CanvasItem) -> void:
	if node == null:
		return
	var c := node.modulate
	node.modulate = Color(1.35, 1.35, 1.35, 1)
	await get_tree().create_timer(0.08).timeout
	if is_instance_valid(node):
		node.modulate = c
