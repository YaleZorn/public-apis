extends RefCounted
class_name StateVfx
## Data-driven character state VFX (v0.10.0 quality rebuild):
## soft layered idle/buff 光环 · cinematic 技能激发 · authored 爆衣 reveal.
## Tasteful 17+ game VFX — no porn / genital close-ups / sex UI.
## Uses runtime autoload lookup so --script captures compile cleanly.

const AP := preload("res://scripts/util/art_palette.gd")
const VF := preload("res://scripts/util/visual_factory.gd")

const FIGURE_DIR := "res://assets/textures/figures/"
const VFX_DIR := "res://assets/textures/vfx/"
const LOW_HP_RATIO := 0.35
const REVEAL_HOLD := 2.2

static var _tex_cache: Dictionary = {}


static func _autoload(name: String) -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null(name)


static func _content_db() -> Node:
	return _autoload("ContentDB")


static func _game_state() -> Node:
	return _autoload("GameState")


static func _juice() -> Node:
	return _autoload("Juice")


static func _vfx_tex(name: String) -> Texture2D:
	if _tex_cache.has(name):
		return _tex_cache[name]
	var path := VFX_DIR + name
	var tex: Texture2D = null
	if ResourceLoader.exists(path) or FileAccess.file_exists(path):
		tex = load(path)
	_tex_cache[name] = tex
	return tex


static func hooks_of(unit: Dictionary) -> Dictionary:
	if unit.is_empty():
		return {}
	var v: Variant = unit.get("vfx", {})
	return v if typeof(v) == TYPE_DICTIONARY else {}


static func hooks_for_id(uid: String) -> Dictionary:
	if uid == "":
		return {}
	var cdb := _content_db()
	if cdb == null:
		return {}
	return hooks_of(cdb.get_unit(uid))


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
	# Hide decorative sash — it reads as a UI bar next to VFX.
	var sash := figure.get_node_or_null("AnimRoot/SashBob") as CanvasItem
	if sash:
		sash.visible = false
	var idle_on := bool(hooks.get("idle_aura", false))
	if idle_on or bool(opts.get("force_idle_aura", false)):
		var col := _parse_color(hooks.get("idle_aura_color", "#6aa89a"), Color(0.45, 0.72, 0.62, 0.55))
		show_idle_aura(figure, true, col)
	var want_buff := bool(opts.get("buff", false))
	if not want_buff and bool(opts.get("auto_buff", true)):
		want_buff = _should_auto_buff(str(figure.get_meta("unit_id", "")))
	if want_buff:
		var bcol := _parse_color(hooks.get("buff_ring_color", "#d4a017"), Color(AP.LANTERN_GOLD.r, AP.LANTERN_GOLD.g, AP.LANTERN_GOLD.b, 0.75))
		show_buff_ring(figure, true, bcol)
	if bool(opts.get("td_aura", false)):
		var u := unit
		if u.is_empty():
			var cdb := _content_db()
			if cdb:
				u = cdb.get_unit(str(figure.get_meta("unit_id", "")))
		_attach_td_aura_hint(figure, u)


static func _should_auto_buff(uid: String) -> bool:
	if uid == "":
		return false
	var gs := _game_state()
	if gs == null:
		return false
	if gs.is_morning_buff_live():
		return true
	for slot in gs.training_slots:
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
	figure.move_child(layer, mini(figure.get_child_count() - 1, 2))
	return layer


static func _fig_size(figure: Control) -> Vector2:
	return figure.custom_minimum_size if figure.custom_minimum_size.x > 1.0 else figure.size


static func _tex_sprite(tex: Texture2D, sz: Vector2, col: Color) -> TextureRect:
	var spr := TextureRect.new()
	spr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spr.texture = tex
	spr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	spr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	spr.size = sz
	spr.modulate = col
	spr.pivot_offset = sz * 0.5
	return spr


## --- 光环: soft layered rings + orbiting mist petals (ink-mist palette) ---

static func show_idle_aura(figure: Control, on: bool, color: Color = Color(0.45, 0.72, 0.62, 0.55)) -> void:
	if figure == null or not is_instance_valid(figure):
		return
	var layer := _ensure_layer(figure)
	for n in ["IdleAura", "IdleAuraOuter", "IdleAuraMist", "IdleAuraPets"]:
		var old := layer.get_node_or_null(n)
		if old:
			old.queue_free()
	if not on:
		return
	var sz := _fig_size(figure)
	var ring_tex := _vfx_tex("aura_ring_soft.png")
	var mist_tex := _vfx_tex("aura_mist_disc.png")
	var petal_tex := _vfx_tex("mist_petal.png")
	var base_r := maxf(56.0, sz.x * 1.15)
	# Soft mist underfoot
	if mist_tex:
		var mist := _tex_sprite(mist_tex, Vector2(base_r * 1.5, base_r * 0.82), Color(color.r, color.g, color.b, 0.72))
		mist.name = "IdleAuraMist"
		mist.position = Vector2(sz.x * 0.5 - mist.size.x * 0.5, sz.y * 0.68 - mist.size.y * 0.35)
		mist.z_index = 1
		layer.add_child(mist)
		var mtw := mist.create_tween().set_loops()
		mtw.tween_property(mist, "modulate:a", 0.38, 1.6).set_trans(Tween.TRANS_SINE)
		mtw.tween_property(mist, "modulate:a", 0.78, 1.6).set_trans(Tween.TRANS_SINE)
	# Outer soft ring (slow rotate)
	if ring_tex:
		var outer := _tex_sprite(ring_tex, Vector2(base_r * 1.25, base_r * 1.25), Color(color.r, color.g, color.b, 0.78))
		outer.name = "IdleAuraOuter"
		outer.position = Vector2(sz.x * 0.5 - outer.size.x * 0.5, sz.y * 0.78 - outer.size.y * 0.5)
		outer.z_index = 2
		layer.add_child(outer)
		var otw := outer.create_tween().set_loops()
		otw.tween_property(outer, "rotation", TAU, 7.5)
		# Inner ring — counter-rotate + breath scale
		var inner := _tex_sprite(ring_tex, Vector2(base_r * 0.88, base_r * 0.88), Color(
			minf(1.0, color.r * 1.15 + 0.15),
			minf(1.0, color.g * 1.05 + 0.08),
			minf(1.0, color.b * 0.9),
			0.92
		))
		inner.name = "IdleAura"
		inner.position = Vector2(sz.x * 0.5 - inner.size.x * 0.5, sz.y * 0.80 - inner.size.y * 0.5)
		inner.z_index = 3
		layer.add_child(inner)
		var itw := inner.create_tween().set_loops()
		itw.tween_property(inner, "rotation", -TAU, 5.2)
		var btw := inner.create_tween().set_loops()
		btw.tween_property(inner, "scale", Vector2(1.08, 1.08), 1.35).set_trans(Tween.TRANS_SINE)
		btw.tween_property(inner, "scale", Vector2(0.94, 0.94), 1.35).set_trans(Tween.TRANS_SINE)
	else:
		# Fallback geometry rings if textures missing
		var radius := maxf(18.0, sz.x * 0.38)
		var ring := VF._fx_ring(radius, 2.4, Color(color.r, color.g, color.b, 0.5), 28)
		ring.name = "IdleAura"
		ring.position = Vector2(sz.x * 0.5, sz.y * 0.78)
		layer.add_child(ring)
	# Orbiting mist petals — parent rotates so children ride the ring.
	var pets := Control.new()
	pets.name = "IdleAuraPets"
	pets.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pets.position = Vector2(sz.x * 0.5, sz.y * 0.72)
	pets.pivot_offset = Vector2.ZERO
	pets.z_index = 4
	layer.add_child(pets)
	for i in 5:
		var ang0 := TAU * float(i) / 5.0
		var orbit_r := 22.0 + float(i % 2) * 8.0
		var slot := Control.new()
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.position = Vector2(cos(ang0), sin(ang0) * 0.55) * orbit_r
		pets.add_child(slot)
		if petal_tex:
			var pet := _tex_sprite(petal_tex, Vector2(14, 18), Color(color.r, color.g, color.b, 0.85))
			pet.position = Vector2(-7, -9)
			slot.add_child(pet)
		else:
			var pet2 := VF._fx_petal(Vector2(12, 16), Color(color.r, color.g, color.b, 0.85))
			pet2.position = Vector2(-6, -8)
			slot.add_child(pet2)
	var ptw := pets.create_tween().set_loops()
	ptw.tween_property(pets, "rotation", TAU, 4.8)


static func show_buff_ring(figure: Control, on: bool, color: Color = Color(0.85, 0.7, 0.3, 0.8)) -> void:
	if figure == null or not is_instance_valid(figure):
		return
	var layer := _ensure_layer(figure)
	for n in ["BuffRing", "BuffRingOuter", "BuffRingMist", "BuffSpark"]:
		var old := layer.get_node_or_null(n)
		if old:
			old.queue_free()
	if not on:
		figure.set_meta("vfx_buff", false)
		return
	figure.set_meta("vfx_buff", true)
	var sz := _fig_size(figure)
	var ring_tex := _vfx_tex("aura_ring_soft.png")
	var mist_tex := _vfx_tex("aura_mist_disc.png")
	var base_r := maxf(48.0, sz.x * 1.05)
	if mist_tex:
		var mist := _tex_sprite(mist_tex, Vector2(base_r * 1.2, base_r * 0.55), Color(color.r, color.g, color.b, 0.45))
		mist.name = "BuffRingMist"
		mist.position = Vector2(sz.x * 0.5 - mist.size.x * 0.5, sz.y * 0.78 - mist.size.y * 0.3)
		mist.z_index = 2
		layer.add_child(mist)
	if ring_tex:
		var outer := _tex_sprite(ring_tex, Vector2(base_r * 1.2, base_r * 1.2), Color(AP.MIST_TEAL.r, AP.MIST_TEAL.g, AP.MIST_TEAL.b, 0.5))
		outer.name = "BuffRingOuter"
		outer.position = Vector2(sz.x * 0.5 - outer.size.x * 0.5, sz.y * 0.82 - outer.size.y * 0.5)
		outer.z_index = 3
		layer.add_child(outer)
		var otw := outer.create_tween().set_loops()
		otw.tween_property(outer, "rotation", TAU, 4.8)
		var ring := _tex_sprite(ring_tex, Vector2(base_r * 0.88, base_r * 0.88), Color(color.r, color.g, color.b, 0.9))
		ring.name = "BuffRing"
		ring.position = Vector2(sz.x * 0.5 - ring.size.x * 0.5, sz.y * 0.82 - ring.size.y * 0.5)
		ring.z_index = 4
		layer.add_child(ring)
		var tw := ring.create_tween().set_loops()
		tw.tween_property(ring, "scale", Vector2(1.1, 1.1), 0.85).set_trans(Tween.TRANS_SINE)
		tw.tween_property(ring, "scale", Vector2(0.94, 0.94), 0.85).set_trans(Tween.TRANS_SINE)
		# Lantern spark pulse at rim
		var spark := VF._fx_diamond(Vector2(10, 10), Color(AP.LANTERN_GOLD.r, AP.LANTERN_GOLD.g, AP.LANTERN_GOLD.b, 0.95))
		spark.name = "BuffSpark"
		spark.position = Vector2(sz.x * 0.5 - 5.0, sz.y * 0.82 - base_r * 0.38)
		spark.z_index = 5
		layer.add_child(spark)
		var stw := spark.create_tween().set_loops()
		stw.tween_property(spark, "modulate:a", 0.25, 0.55)
		stw.tween_property(spark, "modulate:a", 1.0, 0.55)
	else:
		var radius := maxf(22.0, sz.x * 0.42)
		var ring := VF._fx_ring(radius, 3.2, Color(color.r, color.g, color.b, 0.85), 26)
		ring.name = "BuffRing"
		ring.position = Vector2(sz.x * 0.5, sz.y * 0.82)
		layer.add_child(ring)


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


## --- 技能激发: distinct cast flourish (energy + slash trails + flash) ---

static func trigger_skill(figure: Control, parent: Node = null, effect: String = "") -> void:
	if figure == null or not is_instance_valid(figure):
		return
	var hooks: Dictionary = figure.get_meta("vfx_hooks", {})
	if hooks.is_empty():
		hooks = hooks_for_id(str(figure.get_meta("unit_id", figure.get_meta("figure_id", ""))))
	var burst_style := str(hooks.get("skill_burst", "jade"))
	var col := _burst_color(burst_style, effect)
	var at := figure.position + _fig_size(figure) * 0.5
	var host: Node = parent if parent else figure.get_parent()
	if host:
		_skill_cast_flourish(host, at, col, burst_style, effect if effect != "" else "default")
	var juice := _juice()
	if juice:
		juice.pulse(figure, 1.18, 0.16)
		juice.flash_modulate(figure, Color(1.4, 1.28, 1.08, 1.0), 0.2)
	var reveal_on: Array = hooks.get("reveal_on", ["skill", "low_hp", "crit"])
	if "skill" in reveal_on and str(hooks.get("reveal", "none")) != "none":
		trigger_reveal(figure, "skill")


static func _burst_color(style: String, effect: String) -> Color:
	match effect:
		"heal":
			return Color(0.55, 0.92, 0.65, 0.95)
		"shield":
			return Color(0.55, 0.78, 0.98, 0.95)
		"aoe_damage":
			return Color(0.95, 0.55, 0.35, 0.95)
		"slow_all":
			return Color(0.55, 0.75, 0.98, 0.9)
	match style:
		"gold":
			return Color(0.95, 0.78, 0.35, 0.95)
		"petal":
			return Color(0.95, 0.55, 0.65, 0.92)
		"blade":
			return Color(0.75, 0.85, 0.95, 0.95)
		_:
			return Color(0.55, 0.88, 0.75, 0.95)


static func _skill_cast_flourish(parent: Node, at: Vector2, color: Color, style: String, effect: String) -> void:
	## Phone-portrait readable: flash core + expanding rings + slash trails + rising energy.
	if parent == null:
		return
	var flash_tex := _vfx_tex("burst_flash.png")
	var slash_tex := _vfx_tex("slash_trail.png")
	var ring_tex := _vfx_tex("aura_ring_soft.png")
	var petal_tex := _vfx_tex("mist_petal.png")
	# Core flash
	if flash_tex:
		var flash := _tex_sprite(flash_tex, Vector2(88, 88), Color(1.0, 0.95, 0.8, 0.98))
		flash.position = at - flash.size * 0.5
		flash.z_index = 18
		parent.add_child(flash)
		var ftw := flash.create_tween()
		ftw.tween_property(flash, "scale", Vector2(1.55, 1.55), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		ftw.tween_property(flash, "modulate:a", 0.0, 0.32)
		ftw.parallel().tween_property(flash, "scale", Vector2(2.1, 2.1), 0.32)
		ftw.tween_callback(flash.queue_free)
	else:
		var core := VF._fx_disc(14.0, Color(AP.LANTERN_GOLD.r, AP.LANTERN_GOLD.g, AP.LANTERN_GOLD.b, 0.95), 14)
		core.position = at - Vector2(14, 14)
		core.z_index = 18
		parent.add_child(core)
		var ctw := core.create_tween()
		ctw.tween_property(core, "scale", Vector2(2.4, 2.4), 0.22)
		ctw.parallel().tween_property(core, "modulate:a", 0.0, 0.24)
		ctw.tween_callback(core.queue_free)
	# Expanding soft ring
	if ring_tex:
		var ering := _tex_sprite(ring_tex, Vector2(56, 56), Color(color.r, color.g, color.b, 0.9))
		ering.position = at - ering.size * 0.5
		ering.z_index = 16
		parent.add_child(ering)
		var rtw := ering.create_tween()
		rtw.tween_property(ering, "scale", Vector2(3.6, 3.6), 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		rtw.parallel().tween_property(ering, "modulate:a", 0.0, 0.4)
		rtw.tween_callback(ering.queue_free)
	else:
		var ring := VF._fx_ring(14.0, 4.5, color, 24)
		ring.position = at
		ring.z_index = 16
		parent.add_child(ring)
		var rtw2 := ring.create_tween()
		rtw2.tween_property(ring, "scale", Vector2(4.2, 4.2), 0.38).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		rtw2.parallel().tween_property(ring, "modulate:a", 0.0, 0.38)
		rtw2.tween_callback(ring.queue_free)
	# Dual slash trails (wuxia readable on portrait)
	var slash_count := 3 if style == "blade" or effect == "aoe_damage" else 2
	for i in slash_count:
		var ang := -0.65 + float(i) * 0.65
		if style == "blade":
			ang = -1.0 + float(i) * 0.75
		if slash_tex:
			var trail := _tex_sprite(slash_tex, Vector2(140, 58), Color(color.r, color.g, color.b, 0.98))
			trail.pivot_offset = trail.size * 0.5
			trail.rotation = ang
			trail.position = at - trail.size * 0.5 + Vector2(cos(ang), sin(ang)) * 10.0
			trail.z_index = 17
			trail.scale = Vector2(0.4, 0.6)
			parent.add_child(trail)
			var stw := trail.create_tween()
			stw.tween_property(trail, "scale", Vector2(1.35 + float(i) * 0.1, 1.05), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			stw.tween_property(trail, "modulate:a", 0.0, 0.28)
			stw.parallel().tween_property(trail, "position", trail.position + Vector2(cos(ang), sin(ang)) * 36.0, 0.28)
			stw.tween_callback(trail.queue_free)
		else:
			VF.slash_arc(parent, at + Vector2(cos(ang), sin(ang)) * 12.0, color, 1.25 + float(i) * 0.12)
	# Rising energy petals / sparks
	for i in 7:
		var pet: CanvasItem
		if petal_tex and style != "blade":
			pet = _tex_sprite(petal_tex, Vector2(16, 20), Color(color.r, color.g, color.b, 0.95))
			(pet as Control).position = at - Vector2(8, 10)
		else:
			pet = VF._fx_diamond(Vector2(11, 11), Color(color.r, color.g, color.b, 0.95))
			(pet as Node2D).position = at - Vector2(5, 5)
		parent.add_child(pet)
		if pet is CanvasItem:
			(pet as CanvasItem).z_index = 15
		var ang2 := -PI * 0.5 + (float(i) - 3.0) * 0.28
		var dest := at + Vector2(cos(ang2), sin(ang2)) * (48.0 + float(i) * 7.0)
		var ptw := (pet as Node).create_tween()
		if pet is Control:
			ptw.tween_property(pet, "position", dest - Vector2(8, 10), 0.36).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		else:
			ptw.tween_property(pet, "position", dest - Vector2(5, 5), 0.36).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		ptw.parallel().tween_property(pet, "modulate:a", 0.0, 0.36)
		ptw.tween_callback(pet.queue_free)
	# Also call legacy per-effect accents for heal/shield/slow
	match effect:
		"heal", "shield", "slow_all", "aoe_damage":
			VF.skill_cast_fx(parent, at, effect, color)
		_:
			pass


static func trigger_crit(figure: Control, parent: Node = null) -> void:
	if figure == null or not is_instance_valid(figure):
		return
	var hooks: Dictionary = figure.get_meta("vfx_hooks", {})
	if hooks.is_empty():
		hooks = hooks_for_id(str(figure.get_meta("unit_id", figure.get_meta("figure_id", ""))))
	var reveal_on: Array = hooks.get("reveal_on", ["skill", "low_hp", "crit"])
	var juice := _juice()
	if juice:
		juice.pulse(figure, 1.14, 0.1)
	var host: Node = parent if parent else figure.get_parent()
	if host:
		var at := figure.position + _fig_size(figure) * 0.45
		var flash_tex := _vfx_tex("burst_flash.png")
		if flash_tex:
			var flash := _tex_sprite(flash_tex, Vector2(48, 48), Color(1.0, 0.88, 0.5, 0.9))
			flash.position = at - flash.size * 0.5
			flash.z_index = 16
			host.add_child(flash)
			var ftw := flash.create_tween()
			ftw.tween_property(flash, "scale", Vector2(1.6, 1.6), 0.18)
			ftw.parallel().tween_property(flash, "modulate:a", 0.0, 0.2)
			ftw.tween_callback(flash.queue_free)
		else:
			VF.placement_ring(host, at, Color(1.0, 0.85, 0.45, 0.7))
	if "crit" in reveal_on and str(hooks.get("reveal", "none")) != "none":
		trigger_reveal(figure, "crit")


static func sync_hp(figure: Control, ratio: float) -> void:
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


## --- 爆衣: authored *_reveal.png swap + cinematic fabric burst ---

static func trigger_reveal(figure: Control, reason: String = "skill", sticky: bool = false) -> void:
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
	_cloth_burst_fx(figure)
	if has_reveal and spr:
		if spr.has_meta("frame_tw"):
			var old_tw: Variant = spr.get_meta("frame_tw")
			if old_tw is Tween and is_instance_valid(old_tw):
				(old_tw as Tween).kill()
			spr.remove_meta("frame_tw")
		var tex: Texture2D = load(reveal_path)
		if tex:
			spr.texture = tex
			# Clear sheet-region so full reveal still shows
			if spr.texture is AtlasTexture:
				spr.texture = tex
			spr.modulate = Color(1.08, 1.04, 1.0, 1.0)
	figure.set_meta("vfx_revealed", true)
	figure.set_meta("vfx_reveal_reason", reason)
	var juice := _juice()
	if juice:
		juice.flash_modulate(figure, Color(1.45, 1.2, 1.05, 1.0), 0.22)
	if anim:
		var tw := anim.create_tween()
		tw.tween_property(anim, "scale", Vector2(1.14, 0.9), 0.07)
		tw.tween_property(anim, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_BACK)
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
	## Cinematic costume-change burst — shockwave + fabric scraps + ink petals.
	var layer := _ensure_layer(figure)
	var sz := _fig_size(figure)
	var origin := Vector2(sz.x * 0.5, sz.y * 0.42)
	var flash_tex := _vfx_tex("burst_flash.png")
	var ring_tex := _vfx_tex("aura_ring_soft.png")
	var petal_tex := _vfx_tex("mist_petal.png")
	if flash_tex:
		var flash := _tex_sprite(flash_tex, Vector2(64, 64), Color(1.0, 0.85, 0.7, 0.95))
		flash.position = origin - flash.size * 0.5
		flash.z_index = 10
		layer.add_child(flash)
		var ftw := flash.create_tween()
		ftw.tween_property(flash, "scale", Vector2(1.7, 1.7), 0.2)
		ftw.parallel().tween_property(flash, "modulate:a", 0.0, 0.26)
		ftw.tween_callback(flash.queue_free)
	if ring_tex:
		var ring := _tex_sprite(ring_tex, Vector2(36, 36), Color(0.95, 0.75, 0.6, 0.9))
		ring.position = origin - ring.size * 0.5
		ring.z_index = 8
		layer.add_child(ring)
		var rtw := ring.create_tween()
		rtw.tween_property(ring, "scale", Vector2(3.8, 3.8), 0.36).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		rtw.parallel().tween_property(ring, "modulate:a", 0.0, 0.36)
		rtw.tween_callback(ring.queue_free)
	else:
		var ring2 := VF._fx_ring(10.0, 2.5, Color(0.95, 0.75, 0.6, 0.85), 18)
		ring2.position = origin
		ring2.z_index = 8
		layer.add_child(ring2)
		var rtw2 := ring2.create_tween()
		rtw2.tween_property(ring2, "scale", Vector2(3.4, 3.4), 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		rtw2.parallel().tween_property(ring2, "modulate:a", 0.0, 0.32)
		rtw2.tween_callback(ring2.queue_free)
	# Fabric scraps + mist petals
	for i in 10:
		var scrap: CanvasItem
		var use_petal := petal_tex != null and i % 3 != 0
		if use_petal:
			scrap = _tex_sprite(petal_tex, Vector2(12, 16), Color(0.95, 0.82, 0.72, 0.95))
			(scrap as Control).position = origin - Vector2(6, 8)
		elif i % 2 == 0:
			scrap = VF._fx_petal(Vector2(10, 14), Color(0.92, 0.82, 0.7, 0.95))
			(scrap as Node2D).position = origin - Vector2(5, 7)
		else:
			scrap = VF._fx_diamond(Vector2(9, 9), Color(0.85, 0.7, 0.55, 0.9))
			(scrap as Node2D).position = origin - Vector2(4, 4)
		scrap.z_index = 9
		layer.add_child(scrap)
		var ang := TAU * float(i) / 10.0 + randf() * 0.25
		var dest := origin + Vector2(cos(ang), sin(ang) - 0.4) * (32.0 + randf() * 28.0)
		var stw := (scrap as Node).create_tween()
		if scrap is Control:
			stw.tween_property(scrap, "position", dest - Vector2(6, 8), 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			stw.parallel().tween_property(scrap, "rotation", randf_range(-1.4, 1.4), 0.4)
		else:
			stw.tween_property(scrap, "position", dest - Vector2(4, 4), 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			stw.parallel().tween_property(scrap, "rotation", randf_range(-1.4, 1.4), 0.4)
		stw.parallel().tween_property(scrap, "modulate:a", 0.0, 0.4)
		stw.tween_callback(scrap.queue_free)
