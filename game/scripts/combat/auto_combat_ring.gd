extends RefCounted
## Shared auto-attack + active-skill combat ring (explore / arena / tower).
## First-party; AutoCombatKit ideas only — see THIRD_PARTY.md.

const VF := preload("res://scripts/util/visual_factory.gd")
const SV := preload("res://scripts/util/state_vfx.gd")

signal hero_defeated
signal enemies_cleared
signal enemy_killed(enemy_id: String)

var host: Control ## owns arena / juice tree
var arena: Control
var enemies_layer: Node2D
var hero_anchor: Control

var hero_id: String = "unit_feidao"
var hp: float = 120.0
var max_hp: float = 120.0
var atk: float = 28.0
var attack_interval: float = 0.65
var attack_cd: float = 0.0
var skill: Dictionary = {}
var skill_cd: float = 0.0
var shield: float = 0.0
var slow_all_timer: float = 0.0
var combat_active: bool = false
var enemies: Array = []
var hero_visual: Control
var paused: bool = false ## knowledge / overlays


func bind(p_host: Control, p_arena: Control, p_enemies: Node2D, p_hero_anchor: Control) -> void:
	host = p_host
	arena = p_arena
	enemies_layer = p_enemies
	hero_anchor = p_hero_anchor


func init_hero(uid: String, start_shield: float = 0.0) -> void:
	hero_id = uid
	var u: Dictionary = ContentDB.get_unit(hero_id)
	var ex: Dictionary = u.get("explore", {})
	max_hp = float(ex.get("hp", 120))
	hp = max_hp
	atk = float(ex.get("atk", 20))
	# Tower exclusive gear hook (data-driven; explore pool never grants this id).
	if "gear_tower_blade" in GameState.gear_equipped:
		atk *= 1.08
	var kb: Dictionary = GameState.knowledge_meta_bonuses()
	atk *= float(kb.get("auto_combat_atk_mult", 1.0))
	max_hp += float(kb.get("explore_max_hp", 0))
	hp = max_hp
	attack_interval = float(ex.get("attack_interval", 0.7))
	skill = ex.get("active", {}).duplicate(true)
	shield = start_shield
	skill_cd = 0.0
	attack_cd = 0.0
	slow_all_timer = 0.0
	if hero_visual and is_instance_valid(hero_visual):
		hero_visual.queue_free()
	hero_visual = VF.unit_node(u, Vector2(118, 148))
	hero_visual.position = hero_anchor.position if hero_anchor else Vector2(72, 200)
	if hero_anchor:
		hero_anchor.visible = false
	arena.add_child(hero_visual)
	VF.attach_hero_hp(hero_visual)
	# Re-attach with combat opts: morning/knowledge buff ring + idle aura from data.
	SV.attach(hero_visual, u, {
		"auto_buff": true,
		"buff": GameState.is_morning_buff_live() or float(GameState.knowledge_meta_bonuses().get("explore_shield", 0)) > 0.0,
	})
	_sync_hero_hp_bar()
	VF.idle_bob(hero_visual, 4.0, 2.6)


func clear_enemies() -> void:
	enemies.clear()
	if enemies_layer:
		for c in enemies_layer.get_children():
			c.queue_free()


func spawn_enemies(ids: Array, hp_scale: float = 1.0, atk_scale: float = 1.0) -> void:
	var i := enemies.size()
	for eid in ids:
		var e: Dictionary = ContentDB.get_enemy(str(eid))
		if e.is_empty():
			continue
		var node := VF.enemy_node(e, Vector2(100, 128))
		var col := i % 3
		var row := int(i / 3)
		node.position = Vector2(320 + col * 92, 90 + row * 105)
		node.modulate.a = 0.0
		enemies_layer.add_child(node)
		VF.idle_bob(node, 2.5, 2.2 + i * 0.15)
		var tw := node.create_tween()
		tw.tween_property(node, "modulate:a", 1.0, 0.22)
		tw.parallel().tween_property(node, "position:x", node.position.x - 12.0, 0.22).set_trans(Tween.TRANS_BACK)
		var emax := float(e.get("hp", 50)) * 0.85 * hp_scale
		VF.set_enemy_hp_ratio(node, 1.0)
		enemies.append({
			"id": str(eid),
			"hp": emax,
			"max_hp": emax,
			"atk": (8.0 + float(e.get("leak_damage", 1)) * 4.0) * atk_scale,
			"node": node,
			"attack_cd": 1.0 + i * 0.2,
		})
		i += 1
	combat_active = not enemies.is_empty()


func tick(delta: float) -> void:
	if paused or not combat_active:
		if skill_cd > 0:
			skill_cd = maxf(0.0, skill_cd - delta)
		return
	if skill_cd > 0:
		skill_cd = maxf(0.0, skill_cd - delta)
	if slow_all_timer > 0:
		slow_all_timer = maxf(0.0, slow_all_timer - delta)
	attack_cd -= delta
	_tick_enemies(delta)
	if not combat_active:
		return
	if attack_cd <= 0.0 and not enemies.is_empty():
		_hero_auto_attack()
		attack_cd = attack_interval
	if enemies.is_empty() and combat_active:
		combat_active = false
		enemies_cleared.emit()


func cast_skill() -> bool:
	if paused or skill_cd > 0.05:
		return false
	if not combat_active and enemies.is_empty():
		return false
	var effect := str(skill.get("effect", ""))
	var value := float(skill.get("value", 0))
	var burst_col := Color(0.7, 0.88, 0.75, 0.8)
	# 技能激发 state VFX (burst + optional 爆衣) — replaces bare skill_cast_fx for hero.
	if hero_visual:
		SV.trigger_skill(hero_visual, arena, effect if effect != "" else "default")
	match effect:
		"aoe_damage":
			burst_col = Color(0.95, 0.55, 0.35, 0.85)
			for enemy in enemies.duplicate():
				if enemy.node and is_instance_valid(enemy.node):
					VF.slash_arc(enemies_layer, enemy.node.position + enemy.node.custom_minimum_size * 0.5, burst_col, 1.15)
				_damage_enemy(enemy, value, burst_col)
		"heal":
			burst_col = Color(0.55, 0.9, 0.65, 0.85)
			hp = minf(max_hp, hp + value)
			Juice.float_number(hero_visual.position, "+%d" % int(value), Color(0.55, 0.9, 0.6))
		"shield":
			burst_col = Color(0.55, 0.75, 0.95, 0.85)
			shield += value
			Juice.float_number(hero_visual.position, "盾+%d" % int(value), Color(0.55, 0.75, 0.95))
		"slow_all":
			burst_col = Color(0.55, 0.75, 0.95, 0.8)
			slow_all_timer = float(skill.get("duration", 2.0))
			for enemy in enemies:
				if enemy.node:
					enemy.node.modulate = Color(0.65, 0.8, 1.1, 1.0)
		_:
			for enemy in enemies.duplicate():
				_damage_enemy(enemy, value, burst_col)
	skill_cd = float(skill.get("cooldown", 8.0))
	Juice.play_sfx("skill")
	Juice.screen_shake(arena, 6.0)
	_sync_hero_hp_bar()
	if enemies.is_empty() and combat_active:
		combat_active = false
		enemies_cleared.emit()
	return true


func skill_button_text() -> String:
	if skill_cd > 0.05:
		return "%s · %.1fs" % [skill.get("name", "技能"), skill_cd]
	return str(skill.get("name", "技能"))


func skill_disabled() -> bool:
	return skill_cd > 0.05 or (not combat_active and enemies.is_empty()) or paused


func hp_label_text() -> String:
	return "气血 · %d/%d%s" % [int(hp), int(max_hp), (" · 盾%d" % int(shield)) if shield > 0 else ""]


func _sync_hero_hp_bar() -> void:
	if hero_visual == null or not is_instance_valid(hero_visual):
		return
	var ratio := hp / maxf(max_hp, 1.0)
	VF.set_hero_hp_ratio(hero_visual, ratio, shield / maxf(max_hp, 1.0))
	SV.sync_hp(hero_visual, ratio)


func _hero_auto_attack() -> void:
	if enemies.is_empty():
		return
	var target: Dictionary = enemies[0]
	var flash := Color(1.0, 0.92, 0.55, 0.9)
	if hero_visual and target.has("node") and is_instance_valid(target.node):
		VF.attack_strike(arena, hero_visual, target.node, flash)
		Juice.pulse(hero_visual, 1.1, 0.1)
	_damage_enemy(target, atk, flash)


func _damage_enemy(enemy: Dictionary, dmg: float, flash: Color) -> void:
	if not enemy.has("node") or not is_instance_valid(enemy.node):
		enemies.erase(enemy)
		return
	# Crit-ish: big hit relative to enemy max HP or overkill finishing blow.
	var was_hp: float = float(enemy.hp)
	var is_crit := dmg >= atk * 1.45 or dmg >= float(enemy.max_hp) * 0.45
	enemy.hp -= dmg
	var pos: Vector2 = enemy.node.position + enemy.node.custom_minimum_size * 0.5
	Juice.float_number(pos, str(int(dmg)), Color(1, 0.88, 0.5))
	VF.hit_impact(enemies_layer, pos, flash)
	VF.set_enemy_hp_ratio(enemy.node, enemy.hp / maxf(enemy.max_hp, 1.0))
	Juice.play_sfx("hit")
	_pulse(enemy.node)
	if is_crit and hero_visual:
		SV.trigger_crit(hero_visual, arena)
	if enemy.hp <= 0:
		# Finishing blow also counts as crit moment for reveal.
		if was_hp > 0.0 and hero_visual and not is_crit:
			SV.trigger_crit(hero_visual, arena)
		VF.death_puff(enemies_layer, pos, Color(0.95, 0.5, 0.35, 0.85))
		VF.placement_ring(enemies_layer, pos, Color(0.95, 0.7, 0.4, 0.7))
		var eid := str(enemy.get("id", ""))
		enemy.node.queue_free()
		enemies.erase(enemy)
		Juice.play_sfx("kill")
		enemy_killed.emit(eid)


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
		if hero_visual and enemy.node and is_instance_valid(enemy.node):
			VF.attack_strike(arena, enemy.node, hero_visual, Color(0.95, 0.45, 0.4, 0.9))
			Juice.float_number(hero_visual.position, "-%d" % int(dmg), Color(0.95, 0.45, 0.4))
			Juice.flash_modulate(hero_visual, Color(1.45, 0.7, 0.65, 1.0), 0.12)
			VF.hit_impact(arena, hero_visual.position + hero_visual.custom_minimum_size * 0.5, Color(0.95, 0.4, 0.35, 0.85))
		Juice.play_sfx("hit")
		Juice.screen_shake(arena, 5.0)
		_pulse(enemy.node)
		_sync_hero_hp_bar()
		if hp <= 0:
			combat_active = false
			hero_defeated.emit()
			return


func _pulse(node: CanvasItem) -> void:
	if node == null or not is_instance_valid(node) or host == null:
		return
	var c := node.modulate
	node.modulate = Color(1.35, 1.35, 1.35, 1)
	host.get_tree().create_timer(0.08).timeout.connect(func():
		if is_instance_valid(node):
			node.modulate = c
	)
