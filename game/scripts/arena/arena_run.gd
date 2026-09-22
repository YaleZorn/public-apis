extends Control
## M4 演武场：生存 ramp · 复用自动战环 · 随时下场结算修为/熟练度。

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
@onready var leave_btn: Button = %LeaveBtn
@onready var lobby_btn: Button = %LobbyBtn
@onready var stats_label: Label = %StatsLabel
@onready var portrait_slot: Control = %PortraitSlot

var ring: RefCounted ## AutoCombatRing
var cfg: Dictionary = {}
var survival_sec: float = 0.0
var spawn_cd: float = 1.0
var spawn_interval: float = 2.4
var kills: int = 0
var mastery_earned: int = 0
var xiuwei_earned: int = 0
var silver_earned: int = 0
var tick_mastery_accum: float = 0.0
var tick_xiuwei_accum: float = 0.0
var tick_silver_accum: float = 0.0
var game_done: bool = false
var result_overlay: CanvasLayer
var _portrait: Control


func _ready() -> void:
	cfg = ContentDB.arena_cfg
	ring = AutoCombatRing.new()
	ring.bind(self, arena, enemies_layer, hero_node)
	ring.hero_defeated.connect(_on_defeated)
	ring.enemy_killed.connect(_on_kill)
	Atmo.attach_full_bg(self, "night")
	var old_bg := get_node_or_null("Bg")
	if old_bg:
		old_bg.visible = false
	Atmo.apply_explore_room(arena, "combat")
	# Arena: warmer lantern wash for survival grind feel (same palette family).
	var veil := arena.get_node_or_null("ArenaBg") as ColorRect
	if veil:
		veil.color = Color(0.14, 0.11, 0.08, 0.16)
	AP.apply_label(room_label, 22, AP.LANTERN_GOLD)
	AP.apply_label(hp_label, 15, AP.PAPER_DIM)
	AP.apply_label(status_label, 14, AP.PAPER_DIM)
	AP.apply_label(stats_label, 14, Color(0.72, 0.82, 0.7, 1))
	room_label.text = str(cfg.get("display_name", "演武场"))
	Juice.start_arena_music()
	result_overlay = ResultOverlayScene.instantiate()
	add_child(result_overlay)
	skill_btn.pressed.connect(func():
		if ring.cast_skill():
			_refresh()
	)
	leave_btn.pressed.connect(_settle_leave)
	lobby_btn.pressed.connect(_settle_leave)
	leave_btn.text = "下场结算"
	lobby_btn.text = "中断 · 结算回大厅"
	spawn_interval = float(cfg.get("spawn_interval_start", 2.4))
	spawn_cd = 0.6
	var shield := 0.0
	if GameState.is_morning_buff_live():
		shield += float(cfg.get("morning_shield", 20))
	shield += float(GameState.knowledge_meta_bonuses().get("explore_shield", 0))
	if "gear_bamboo_cup" in GameState.gear_equipped:
		shield += float(cfg.get("bamboo_shield", 10))
	if "gear_demo_trail_charm" in GameState.gear_equipped:
		shield += 8.0
	var hero := GameState.explore_hero_id
	if hero not in GameState.unlocked_units and not GameState.unlocked_units.is_empty():
		hero = GameState.unlocked_units[0]
	if not GameState.arena_checkpoint.is_empty():
		_load_checkpoint(GameState.arena_checkpoint)
	else:
		ring.init_hero(hero, shield)
		_build_portrait(hero)
		status_label.text = str(cfg.get("blurb", "敌人持续增压 · 随时可下场。"))
	ring.combat_active = true
	_refresh()
	_persist_soft()


func _build_portrait(uid: String) -> void:
	if _portrait and is_instance_valid(_portrait):
		_portrait.queue_free()
	var u: Dictionary = ContentDB.get_unit(uid)
	_portrait = VF.unit_node(u, Vector2(72, 96))
	_portrait.position = Vector2(8, 8)
	portrait_slot.add_child(_portrait)
	VF.idle_bob(_portrait, 2.0, 2.5)


func _process(delta: float) -> void:
	if game_done:
		return
	survival_sec += delta
	tick_mastery_accum += delta
	tick_xiuwei_accum += delta
	tick_silver_accum += delta
	# Soft checkpoint ~every 5s for interrupt resume.
	if int(survival_sec) % 5 == 0 and int((survival_sec - delta)) % 5 != 0:
		_persist_soft()
	# Time-based soft rewards (accrued, applied on settle).
	while tick_mastery_accum >= 30.0:
		tick_mastery_accum -= 30.0
		mastery_earned += int(cfg.get("mastery_per_30s", 1))
	while tick_xiuwei_accum >= 10.0:
		tick_xiuwei_accum -= 10.0
		xiuwei_earned += int(cfg.get("xiuwei_per_10s", 2))
	while tick_silver_accum >= 30.0:
		tick_silver_accum -= 30.0
		silver_earned += int(cfg.get("silver_per_30s", 3))
	# Ramp spawn.
	spawn_cd -= delta
	var max_alive := int(cfg.get("max_alive", 5))
	if spawn_cd <= 0.0 and ring.enemies.size() < max_alive:
		_spawn_one()
		spawn_interval = maxf(
			float(cfg.get("spawn_interval_min", 0.85)),
			spawn_interval - float(cfg.get("spawn_interval_decay", 0.045))
		)
		spawn_cd = spawn_interval
	ring.tick(delta)
	_refresh()


func _spawn_one() -> void:
	var pool: Array = cfg.get("enemy_pool", ["enemy_bandit"])
	if pool.is_empty():
		return
	var mins := survival_sec / 60.0
	var hp_s := 1.0 + mins * float(cfg.get("ramp_hp_per_min", 0.18))
	var atk_s := 1.0 + mins * float(cfg.get("ramp_atk_per_min", 0.22))
	var eid := str(pool[randi() % pool.size()])
	ring.spawn_enemies([eid], hp_s, atk_s)
	ring.combat_active = true


func _on_kill(_eid: String) -> void:
	kills += 1
	mastery_earned += int(cfg.get("mastery_per_kill", 1))
	xiuwei_earned += int(cfg.get("xiuwei_per_kill", 1))
	Juice.pulse(stats_label, 1.05, 0.12)


func _on_defeated() -> void:
	_settle(false, "力竭下场", "撑不住了，按存活发放熟练与修为。")


func _settle_leave() -> void:
	if game_done:
		return
	_settle(true, "演武结算", "主动下场 · 地铁友好。")


func _settle(voluntary: bool, title: String, blurb: String) -> void:
	if game_done:
		return
	game_done = true
	ring.combat_active = false
	ring.clear_enemies()
	# Guarantee a minimal reward if they entered at all.
	if mastery_earned <= 0 and survival_sec >= 3.0:
		mastery_earned = 1
	if xiuwei_earned <= 0 and survival_sec >= 5.0:
		xiuwei_earned = 1
	GameState.add_mastery(ring.hero_id, mastery_earned)
	GameState.xiuwei_bank += xiuwei_earned
	GameState.silver_bank += silver_earned
	GameState.arena_best_sec = maxf(GameState.arena_best_sec, survival_sec)
	GameState.total_arena_runs += 1
	GameState.arena_checkpoint = {}
	GameState.persist_lobby()
	var detail := "%s\n存活 %.0fs · 击杀 %d\n熟练 +%d · 修为 +%d · 银 +%d\n历史最佳 %.0fs" % [
		blurb, survival_sec, kills, mastery_earned, xiuwei_earned, silver_earned, GameState.arena_best_sec
	]
	if not voluntary:
		detail += "\n（力竭仍发放已攒奖励）"
	result_overlay.show_result(
		title,
		detail,
		"回大厅",
		Color(0.7, 0.78, 0.55) if voluntary else Color(0.85, 0.45, 0.4),
		func(): GameState.go_lobby()
	)


func _persist_soft() -> void:
	# Soft checkpoint so continue can resume mid-grind (interrupt-friendly).
	GameState.persist_arena({
		"hero_id": ring.hero_id,
		"hp": ring.hp,
		"max_hp": ring.max_hp,
		"shield": ring.shield,
		"skill_cd": ring.skill_cd,
		"survival_sec": survival_sec,
		"spawn_interval": spawn_interval,
		"kills": kills,
		"mastery_earned": mastery_earned,
		"xiuwei_earned": xiuwei_earned,
		"silver_earned": silver_earned,
	})


func _load_checkpoint(cp: Dictionary) -> void:
	var hero := str(cp.get("hero_id", GameState.explore_hero_id))
	ring.init_hero(hero, float(cp.get("shield", 0)))
	ring.hp = float(cp.get("hp", ring.max_hp))
	ring.max_hp = float(cp.get("max_hp", ring.max_hp))
	ring.skill_cd = float(cp.get("skill_cd", 0))
	survival_sec = float(cp.get("survival_sec", 0))
	spawn_interval = float(cp.get("spawn_interval", cfg.get("spawn_interval_start", 2.4)))
	kills = int(cp.get("kills", 0))
	mastery_earned = int(cp.get("mastery_earned", 0))
	xiuwei_earned = int(cp.get("xiuwei_earned", 0))
	silver_earned = int(cp.get("silver_earned", 0))
	_build_portrait(hero)
	status_label.text = "演武续关 · 已存活 %.0fs" % survival_sec


func _refresh() -> void:
	hp_label.text = ring.hp_label_text()
	hp_bar.max_value = ring.max_hp
	hp_bar.value = ring.hp
	var ratio: float = ring.hp / maxf(ring.max_hp, 1.0)
	if ratio < 0.35:
		hp_bar.modulate = Color(1.15, 0.65, 0.55)
	elif ratio < 0.65:
		hp_bar.modulate = Color(1.05, 0.95, 0.7)
	else:
		hp_bar.modulate = Color(0.85, 1.05, 0.9)
	if ring.hero_visual:
		VF.set_hero_hp_ratio(ring.hero_visual, ratio, ring.shield / maxf(ring.max_hp, 1.0))
	skill_btn.text = ring.skill_button_text()
	skill_btn.disabled = ring.skill_disabled()
	stats_label.text = "存活 · %.0fs · 杀 %d · 熟练 %d · 修为 %d" % [
		survival_sec, kills, mastery_earned, xiuwei_earned
	]
