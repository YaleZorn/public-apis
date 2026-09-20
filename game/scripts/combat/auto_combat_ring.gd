extends RefCounted
## Shared auto-attack + active-skill combat ring (explore / arena / tower).
## First-party; AutoCombatKit ideas only — see THIRD_PARTY.md.

const VF := preload("res://scripts/util/visual_factory.gd")

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
	attack_interval = float(ex.get("attack_interval", 0.7))
	skill = ex.get("active", {}).duplicate(true)
	shield = start_shield
	skill_cd = 0.0
	attack_cd = 0.0
	slow_all_timer = 0.0
	if hero_visual and is_instance_valid(hero_visual):
		hero_visual.queue_free()
	hero_visual = VF.unit_node(u, Vector2(96, 112))
	hero_visual.position = hero_anchor.position if hero_anchor else Vector2(72, 200)
	if hero_anchor:
		hero_anchor.visible = false
	arena.add_child(hero_visual)
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
		var node := VF.enemy_node(e, Vector2(84, 100))
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
	match effect:
		"aoe_damage":
			burst_col = Color(0.95, 0.55, 0.35, 0.85)
			for enemy in enemies.duplicate():
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
	var burst_at: Vector2 = arena.size * 0.5
	if hero_visual:
		burst_at = hero_visual.position + hero_visual.custom_minimum_size * 0.5
	VF.skill_burst(arena, burst_at, burst_col)
	Juice.play_sfx("skill")
	Juice.screen_shake(arena, 5.0)
	if enemies.is_empty() and combat_active:
		combat_active = false
		enemies_cleared.emit()
	return true


func skill_button_text() -> String:
	if skill_cd > 0.05:
		return "%s (%.1fs)" % [skill.get("name", "技能"), skill_cd]
	return str(skill.get("name", "技能"))


func skill_disabled() -> bool:
	return skill_cd > 0.05 or (not combat_active and enemies.is_empty()) or paused


func hp_label_text() -> String:
	return "HP %d/%d%s" % [int(hp), int(max_hp), (" ·盾%d" % int(shield)) if shield > 0 else ""]


func _hero_auto_attack() -> void:
	if enemies.is_empty():
		return
	var target: Dictionary = enemies[0]
	_damage_enemy(target, atk, Color(1.0, 0.92, 0.55, 0.9))
	_pulse(hero_visual)


func _damage_enemy(enemy: Dictionary, dmg: float, flash: Color) -> void:
	if not enemy.has("node") or not is_instance_valid(enemy.node):
		enemies.erase(enemy)
		return
	enemy.hp -= dmg
	var pos: Vector2 = enemy.node.position + enemy.node.custom_minimum_size * 0.5
	Juice.float_number(pos, str(int(dmg)), Color(1, 0.88, 0.5))
	VF.hit_flash(enemies_layer, pos, flash)
	VF.set_enemy_hp_ratio(enemy.node, enemy.hp / maxf(enemy.max_hp, 1.0))
	Juice.play_sfx("hit")
	_pulse(enemy.node)
	if enemy.hp <= 0:
		VF.death_puff(enemies_layer, pos, Color(0.95, 0.5, 0.35, 0.85))
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
		if hero_visual:
			Juice.float_number(hero_visual.position, "-%d" % int(dmg), Color(0.95, 0.45, 0.4))
		Juice.play_sfx("hit")
		Juice.screen_shake(arena, 5.0)
		_pulse(enemy.node)
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
