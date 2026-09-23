extends RefCounted
class_name StateVfx
## Data-driven character state VFX (v0.9.9):
## idle aura · 技能激发 burst · 爆衣/reveal · buff 光环.
## Tasteful 17+ game VFX — no porn / genital close-ups / sex UI.

const AP := preload("res://scripts/util/art_palette.gd")
const VF := preload("res://scripts/util/visual_factory.gd")

const FIGURE_DIR := "res://assets/textures/figures/"
const LOW_HP_RATIO := 0.35
const REVEAL_HOLD := 2.0


static func hooks_of(unit: Dictionary) -> Dictionary:
	if unit.is_empty():
		return {}
	var v: Variant = unit.get("vfx", {})
	return v if typeof(v) == TYPE_DICTIONARY else {}


static func hooks_for_id(uid: String) -> Dictionary:
	if uid == "" or ContentDB == null:
		return {}
	return hooks_of(ContentDB.get_unit(uid))


static func _parse_color(raw: Variant, fallback: Color) -> Color:
	if typeof(raw) == TYPE_COLOR:
		return raw
	var s := str(raw)
	if s.begins_with("#") and s.length() >= 7:
		return Color(s)
	return fallback


static func attach(figure: Control, unit: Dictionary = {}, opts: Dictionary = {}) -> void:
	## Call after VF.unit_node / hero spawn. Idempotent.
	if figure == null or not is_instance_valid(figure):
		return
	var hooks := hooks_of(unit) if not unit.is_empty() else hooks_for_id(str(figure.get_meta("unit_id", figure.get_meta("figure_id", ""))))
	figure.set_meta("vfx_hooks", hooks)
	figure.set_meta("vfx_revealed", false)
	figure.set_meta("vfx_low_hp", false)
	_ensure_layer(figure)
	# Optional subtle idle aura
	var idle_on := bool(hooks.get("idle_aura", false))
	if idle_on or bool(opts.get("force_idle_aura", false)):
		var col := _parse_color(hooks.get("idle_aura_color", "#6aa89a"), Color(0.45, 0.72, 0.62, 0.55))
		show_idle_aura(figure, true, col)
	# Buff ring (morning knowledge / training / explicit)
	var want_buff := bool(opts.get("buff", false))
	if not want_buff and bool(opts.get("auto_buff", true)):
		want_buff = _should_auto_buff(str(figure.get_meta("unit_id", "")))
	if want_buff:
		var bcol := _parse_color(hooks.get("buff_ring_color", "#d4a017"), Color(AP.LANTERN_GOLD.r, AP.LANTERN_GOLD.g, AP.LANTERN_GOLD.b, 0.75))
		show_buff_ring(figure, true, bcol)
	# TD aura units get a faint persistent ring matching aura type
	if bool(opts.get("td_aura", false)):
		_attach_td_aura_hint(figure, unit if not unit.is_empty() else ContentDB.get_unit(str(figure.get_meta("unit_id", ""))))


static func _should_auto_buff(uid: String) -> bool:
	if uid == "" or GameState == null:
		return false
	if GameState.is_morning_buff_live():
		return true
	# Training occupancy
	for slot in GameState.training_slots:
		if str(slot.get("unit_id", "")) == uid:
			return true
	return false


static func _ensure_layer(figure: Control) -> Control:
	var layer := figure.get_node_or_null("StateVfxLayer") as Control
	if layer:
		return layer
	layer = Control.new()
	layer.name = "StateVfxLayer"
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.size = figure.size if figure.size.x > 1.0 else figure.custom_minimum_size
	figure.add_child(layer)
	# Behind name label but above figure — move near front of children except last labels.
	figure.move_child(layer, mini(figure.get_child_count() - 1, 2))
	return layer


static func show_idle_aura(figure: Control, on: bool, color: Color = Color(0.45, 0.72, 0.62, 0.55)) -> void:
	if figure == null or not is_instance_valid(figure):
		return
	var layer := _ensure_layer(figure)
	var old := layer.get_node_or_null("IdleAura")
	if old:
		old.queue_free()
	if not on:
		return
	var sz := figure.custom_minimum_size if figure.custom_minimum_size.x > 1.0 else figure.size
	var radius := maxf(18.0, sz.x * 0.38)
	var ring := VF._fx_ring(radius, 2.0, Color(color.r, color.g, color.b, 0.42), 24)
	ring.name = "IdleAura"
	ring.position = Vector2(sz.x * 0.5, sz.y * 0.78)
	ring.z_index = 2
	layer.add_child(ring)
	# Soft breath pulse
	var tw := ring.create_tween().set_loops()
	tw.tween_property(ring, "modulate:a", 0.35, 1.4).set_trans(Tween.TRANS_SINE)
	tw.tween_property(ring, "modulate:a", 0.85, 1.4).set_trans(Tween.TRANS_SINE)
	# Inner mist disc
	var mist := VF._fx_disc(radius * 0.55, Color(color.r, color.g, color.b, 0.12), 16)
	mist.name = "IdleAuraMist"
	mist.position = Vector2(sz.x * 0.5 - radius * 0.55, sz.y * 0.72 - radius * 0.35)
	mist.z_index = 1
	layer.add_child(mist)


static func show_buff_ring(figure: Control, on: bool, color: Color = Color(0.85, 0.7, 0.3, 0.8)) -> void:
	if figure == null or not is_instance_valid(figure):
		return
	var layer := _ensure_layer(figure)
	var old := layer.get_node_or_null("BuffRing")
	if old:
		old.queue_free()
	var old2 := layer.get_node_or_null("BuffRingOuter")
	if old2:
		old2.queue_free()
	if not on:
		figure.set_meta("vfx_buff", false)
		return
	figure.set_meta("vfx_buff", true)
	var sz := figure.custom_minimum_size if figure.custom_minimum_size.x > 1.0 else figure.size
	var radius := maxf(22.0, sz.x * 0.42)
	var ring := VF._fx_ring(radius, 3.2, Color(color.r, color.g, color.b, 0.85), 26)
	ring.name = "BuffRing"
	ring.position = Vector2(sz.x * 0.5, sz.y * 0.82)
	ring.z_index = 3
	layer.add_child(ring)
	var outer := VF._fx_ring(radius * 1.18, 1.6, Color(AP.MIST_TEAL.r, AP.MIST_TEAL.g, AP.MIST_TEAL.b, 0.55), 22)
	outer.name = "BuffRingOuter"
	outer.position = Vector2(sz.x * 0.5, sz.y * 0.82)
	outer.z_index = 2
	layer.add_child(outer)
	var tw := ring.create_tween().set_loops()
	tw.tween_property(ring, "scale", Vector2(1.08, 1.08), 0.9).set_trans(Tween.TRANS_SINE)
	tw.tween_property(ring, "scale", Vector2(0.96, 0.96), 0.9).set_trans(Tween.TRANS_SINE)
	var otw := outer.create_tween().set_loops()
	otw.tween_property(outer, "rotation", TAU, 4.5)


static func _attach_td_aura_hint(figure: Control, unit: Dictionary) -> void:
	if unit.is_empty():
		return
	var aura: Dictionary = unit.get("td", {}).get("aura", {})
	var t := str(aura.get("type", "none"))
	if t == "" or t == "none":
		return
	var col := Color(0.55, 0.78, 0.7, 0.7)
	match t:
		"regen":
			col = Color(0.45, 0.9, 0.55, 0.75)
		"slow":
			col = Color(0.5, 0.7, 0.95, 0.75)
		"atk_buff":
			col = Color(0.95, 0.7, 0.35, 0.8)
		"armor_share":
			col = Color(0.65, 0.75, 0.9, 0.75)
	show_buff_ring(figure, true, col)


static func trigger_skill(figure: Control, parent: Node = null, effect: String = "") -> void:
	## 技能激发 — burst + brief intensify + optional reveal.
	if figure == null or not is_instance_valid(figure):
		return
	var hooks: Dictionary = figure.get_meta("vfx_hooks", {})
	if hooks.is_empty():
		hooks = hooks_for_id(str(figure.get_meta("unit_id", figure.get_meta("figure_id", ""))))
	var burst_style := str(hooks.get("skill_burst", "jade"))
	var col := _burst_color(burst_style, effect)
	var at := figure.position + (figure.custom_minimum_size if figure.custom_minimum_size.x > 1.0 else figure.size) * 0.5
	var host: Node = parent if parent else figure.get_parent()
	if host:
		VF.skill_cast_fx(host, at, effect if effect != "" else "default", col)
		_skill_intensify_ring(host, at, col)
	Juice.pulse(figure, 1.16, 0.16)
	Juice.flash_modulate(figure, Color(1.35, 1.25, 1.05, 1.0), 0.18)
	# Reveal on skill if configured
	var reveal_on: Array = hooks.get("reveal_on", ["skill", "low_hp", "crit"])
	if "skill" in reveal_on and str(hooks.get("reveal", "none")) != "none":
		trigger_reveal(figure, "skill")


static func _burst_color(style: String, effect: String) -> Color:
	match effect:
		"heal":
			return Color(0.55, 0.92, 0.65, 0.9)
		"shield":
			return Color(0.55, 0.78, 0.98, 0.9)
		"aoe_damage":
			return Color(0.95, 0.55, 0.35, 0.9)
		"slow_all":
			return Color(0.55, 0.75, 0.98, 0.85)
	match style:
		"gold":
			return Color(0.95, 0.78, 0.35, 0.9)
		"petal":
			return Color(0.95, 0.55, 0.65, 0.88)
		"blade":
			return Color(0.75, 0.85, 0.95, 0.9)
		_:
			return Color(0.55, 0.88, 0.75, 0.9)


static func _skill_intensify_ring(parent: Node, at: Vector2, color: Color) -> void:
	var ring := VF._fx_ring(14.0, 4.5, color, 20)
	ring.position = at
	ring.z_index = 16
	parent.add_child(ring)
	var tw := ring.create_tween()
	tw.tween_property(ring, "scale", Vector2(4.0, 4.0), 0.38).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(ring, "modulate:a", 0.0, 0.38)
	tw.tween_callback(ring.queue_free)
	# Rising ink petals
	for i in 5:
		var petal := VF._fx_petal(Vector2(12, 16), Color(color.r, color.g, color.b, 0.9))
		petal.position = at - Vector2(6, 8)
		petal.z_index = 15
		parent.add_child(petal)
		var ang := -PI * 0.5 + (float(i) - 2.0) * 0.35
		var dest := at + Vector2(cos(ang), sin(ang)) * (40.0 + i * 8.0) - Vector2(6, 8)
		var ptw := petal.create_tween()
		ptw.tween_property(petal, "position", dest, 0.34).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		ptw.parallel().tween_property(petal, "modulate:a", 0.0, 0.34)
		ptw.tween_callback(petal.queue_free)


static func trigger_crit(figure: Control, parent: Node = null) -> void:
	if figure == null or not is_instance_valid(figure):
		return
	var hooks: Dictionary = figure.get_meta("vfx_hooks", {})
	if hooks.is_empty():
		hooks = hooks_for_id(str(figure.get_meta("unit_id", figure.get_meta("figure_id", ""))))
	var reveal_on: Array = hooks.get("reveal_on", ["skill", "low_hp", "crit"])
	Juice.pulse(figure, 1.12, 0.1)
	var host: Node = parent if parent else figure.get_parent()
	if host:
		var at := figure.position + (figure.custom_minimum_size if figure.custom_minimum_size.x > 1.0 else figure.size) * 0.45
		VF.placement_ring(host, at, Color(1.0, 0.85, 0.45, 0.7))
	if "crit" in reveal_on and str(hooks.get("reveal", "none")) != "none":
		trigger_reveal(figure, "crit")


static func sync_hp(figure: Control, ratio: float) -> void:
	## Sticky 爆衣 while critically low HP; restore when recovered.
	if figure == null or not is_instance_valid(figure):
		return
	var hooks: Dictionary = figure.get_meta("vfx_hooks", {})
	if hooks.is_empty():
		hooks = hooks_for_id(str(figure.get_meta("unit_id", figure.get_meta("figure_id", ""))))
	var reveal_on: Array = hooks.get("reveal_on", ["skill", "low_hp", "crit"])
	if str(hooks.get("reveal", "none")) == "none" or not ("low_hp" in reveal_on):
		return
	var low := ratio <= LOW_HP_RATIO and ratio > 0.0
	var was_low := bool(figure.get_meta("vfx_low_hp", false))
	figure.set_meta("vfx_low_hp", low)
	if low and not was_low:
		trigger_reveal(figure, "low_hp", true)
	elif not low and was_low and bool(figure.get_meta("vfx_revealed", false)):
		_restore_figure(figure)


static func trigger_reveal(figure: Control, reason: String = "skill", sticky: bool = false) -> void:
	## 爆衣 / costume-damage reveal — swap to *_reveal.png + tear scrap FX.
	if figure == null or not is_instance_valid(figure):
		return
	if bool(figure.get_meta("vfx_revealed", false)) and sticky:
		return
	var fig_id := str(figure.get_meta("figure_id", figure.get_meta("unit_id", "")))
	if fig_id == "":
		return
	var reveal_path := FIGURE_DIR + fig_id + "_reveal.png"
	var has_reveal := ResourceLoader.exists(reveal_path) or FileAccess.file_exists(reveal_path)
	var anim := figure.get_node_or_null("AnimRoot") as Control
	var spr := anim.get_node_or_null("FigureSpr") as TextureRect if anim else null
	if spr == null:
		spr = figure.get_node_or_null("AnimRoot/FigureSpr") as TextureRect
	# Tear scrap burst always (even without texture swap)
	_cloth_burst_fx(figure)
	if has_reveal and spr:
		# Stop walk cycler briefly; show reveal still.
		if spr.has_meta("frame_tw"):
			var old_tw: Variant = spr.get_meta("frame_tw")
			if old_tw is Tween and is_instance_valid(old_tw):
				(old_tw as Tween).kill()
			spr.remove_meta("frame_tw")
		var tex: Texture2D = load(reveal_path)
		if tex:
			spr.texture = tex
			spr.modulate = Color(
				minf(1.35, spr.modulate.r * 1.08),
				minf(1.25, spr.modulate.g * 1.02),
				minf(1.2, spr.modulate.b * 0.98),
				1.0
			)
	figure.set_meta("vfx_revealed", true)
	figure.set_meta("vfx_reveal_reason", reason)
	Juice.flash_modulate(figure, Color(1.4, 1.15, 1.05, 1.0), 0.2)
	if anim:
		var tw := anim.create_tween()
		tw.tween_property(anim, "scale", Vector2(1.1, 0.94), 0.08)
		tw.tween_property(anim, "scale", Vector2(1.0, 1.0), 0.18).set_trans(Tween.TRANS_BACK)
	if not sticky:
		var tree := figure.get_tree()
		if tree:
			var t := tree.create_timer(REVEAL_HOLD)
			t.timeout.connect(func():
				if is_instance_valid(figure) and not bool(figure.get_meta("vfx_low_hp", false)):
					_restore_figure(figure)
			, CONNECT_ONE_SHOT)


static func _restore_figure(figure: Control) -> void:
	if figure == null or not is_instance_valid(figure):
		return
	figure.set_meta("vfx_revealed", false)
	var fig_id := str(figure.get_meta("figure_id", figure.get_meta("unit_id", "")))
	var anim := figure.get_node_or_null("AnimRoot") as Control
	var spr := anim.get_node_or_null("FigureSpr") as TextureRect if anim else null
	if spr == null or fig_id == "":
		return
	var is_enemy := figure.has_meta("enemy_id")
	VF._apply_figure_tex(spr, fig_id, "walk", 9.0 if is_enemy else 5.5)
	spr.modulate = VF._figure_modulate(fig_id, is_enemy)


static func _cloth_burst_fx(figure: Control) -> void:
	var layer := _ensure_layer(figure)
	var sz := figure.custom_minimum_size if figure.custom_minimum_size.x > 1.0 else figure.size
	var origin := Vector2(sz.x * 0.5, sz.y * 0.42)
	# Expanding tear ring
	var ring := VF._fx_ring(10.0, 2.5, Color(0.95, 0.75, 0.6, 0.85), 18)
	ring.position = origin
	ring.z_index = 8
	layer.add_child(ring)
	var rtw := ring.create_tween()
	rtw.tween_property(ring, "scale", Vector2(3.4, 3.4), 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	rtw.parallel().tween_property(ring, "modulate:a", 0.0, 0.32)
	rtw.tween_callback(ring.queue_free)
	# Fabric scraps
	for i in 7:
		var scrap := VF._fx_petal(Vector2(9, 12), Color(0.92, 0.82, 0.7, 0.95))
		if i % 2 == 0:
			scrap = VF._fx_diamond(Vector2(8, 8), Color(0.85, 0.7, 0.55, 0.9))
		scrap.position = origin - Vector2(4, 4)
		scrap.z_index = 9
		layer.add_child(scrap)
		var ang := TAU * float(i) / 7.0 + randf() * 0.3
		var dest := origin + Vector2(cos(ang), sin(ang) - 0.35) * (28.0 + randf() * 22.0) - Vector2(4, 4)
		var stw := scrap.create_tween()
		stw.tween_property(scrap, "position", dest, 0.36).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		stw.parallel().tween_property(scrap, "rotation", randf_range(-1.2, 1.2), 0.36)
		stw.parallel().tween_property(scrap, "modulate:a", 0.0, 0.36)
		stw.tween_callback(scrap.queue_free)
