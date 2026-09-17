extends RefCounted
class_name Atmosphere
## Procedural portrait atmospheres — gradients, mist bands, mountain planes.

const AP := preload("res://scripts/util/art_palette.gd")
const TITLE_BG := "res://assets/textures/title-night-mist.jpg"
const TD_FIELD := "res://assets/textures/td-jiange-field.jpg"
const ATLAS := "res://assets/textures/unit-enemy-atlas.jpg"


static func night_gradient(size: Vector2i = Vector2i(72, 128)) -> Texture2D:
	var img := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	for y in size.y:
		var t := float(y) / float(size.y - 1)
		var c: Color
		if t < 0.35:
			c = AP.INK_NIGHT.lerp(AP.DEEP_CLIFF, t / 0.35)
		elif t < 0.7:
			c = AP.DEEP_CLIFF.lerp(AP.MIST_JADE, (t - 0.35) / 0.35)
		else:
			c = AP.MIST_JADE.lerp(Color(0.18, 0.28, 0.24, 1), (t - 0.7) / 0.3)
		for x in size.x:
			var edge := absf(float(x) / float(size.x - 1) - 0.5) * 2.0
			var cc := c.darkened(edge * 0.12)
			img.set_pixel(x, y, cc)
	return ImageTexture.create_from_image(img)


static func paper_gradient(size: Vector2i = Vector2i(64, 96)) -> Texture2D:
	var img := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	for y in size.y:
		var t := float(y) / float(size.y - 1)
		var c := Color(0.12, 0.16, 0.14).lerp(Color(0.18, 0.22, 0.18), t)
		for x in size.x:
			var n := fmod(float(x * 17 + y * 31), 7.0) / 7.0
			img.set_pixel(x, y, c.lightened(n * 0.04))
	return ImageTexture.create_from_image(img)


static func attach_full_bg(parent: Control, kind: String = "night") -> TextureRect:
	var bg := TextureRect.new()
	bg.name = "AtmosphereBg"
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	if kind == "night" and ResourceLoader.exists(TITLE_BG):
		bg.texture = load(TITLE_BG)
	elif kind == "td" and ResourceLoader.exists(TD_FIELD):
		bg.texture = load(TD_FIELD)
		# Shift art up so painted 门楼 sits in Field band, not under bottom HUD.
		bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		bg.offset_top = -40
		bg.offset_bottom = 120
	else:
		bg.texture = night_gradient() if kind != "paper" else paper_gradient()
	parent.add_child(bg)
	parent.move_child(bg, 0)
	return bg


static func attach_field_art(field_bg: Control) -> void:
	## Prefer full-bleed scene BG via attach_full_bg(..., "td").
	## Field-local art uses aspect-covered mapping so the painted road is not skewed.
	if field_bg == null:
		return
	if field_bg is TextureRect:
		var tr := field_bg as TextureRect
		if ResourceLoader.exists(TD_FIELD):
			tr.texture = load(TD_FIELD)
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		return
	var parent := field_bg.get_parent()
	if parent == null or not ResourceLoader.exists(TD_FIELD):
		return
	# Full-bleed art lives on the scene root; keep FieldBg as a soft veil only.
	field_bg.modulate = Color(0.06, 0.12, 0.10, 0.28)
	field_bg.visible = true


static func viewport_uv_to_field(field: Control, uv: Vector2) -> Vector2:
	## Map painted 720×1280 UV into Field-local pixels (full-bleed TD bg).
	var vp := Vector2(720.0, 1280.0)
	var global := Vector2(uv.x * vp.x, uv.y * vp.y)
	return global - field.position


static func mist_band(parent: Control, y_ratio: float, h: float, alpha: float = 0.14) -> ColorRect:
	var band := ColorRect.new()
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.set_anchors_preset(Control.PRESET_TOP_WIDE)
	band.anchor_top = y_ratio
	band.anchor_bottom = y_ratio
	band.offset_top = 0
	band.offset_bottom = h
	band.color = Color(AP.FOG_VEIL.r, AP.FOG_VEIL.g, AP.FOG_VEIL.b, alpha)
	parent.add_child(band)
	return band


static func mountain_plane(parent: Control, rect: Rect2, col: Color, skew: float = -0.08) -> ColorRect:
	var m := ColorRect.new()
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.position = rect.position
	m.size = rect.size
	m.color = col
	m.rotation = skew
	parent.add_child(m)
	return m


static func lantern_orb(parent: Control, pos: Vector2, radius: float = 22.0) -> Control:
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.position = pos
	root.size = Vector2(radius * 2, radius * 2)
	var glow := ColorRect.new()
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.size = Vector2(radius * 2.6, radius * 2.6)
	glow.position = Vector2(-radius * 0.3, -radius * 0.3)
	glow.color = Color(AP.LANTERN_GOLD.r, AP.LANTERN_GOLD.g, AP.LANTERN_GOLD.b, 0.18)
	root.add_child(glow)
	var core := ColorRect.new()
	core.mouse_filter = Control.MOUSE_FILTER_IGNORE
	core.size = Vector2(radius, radius)
	core.position = Vector2(radius * 0.5, radius * 0.5)
	core.color = AP.LANTERN_SOFT
	root.add_child(core)
	parent.add_child(root)
	return root


static func drift_loop(node: CanvasItem, amp: Vector2, period: float = 4.0) -> void:
	if node == null:
		return
	var base: Vector2 = node.position
	var tw := node.create_tween().set_loops()
	tw.tween_property(node, "position", base + amp, period * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(node, "position", base - amp * 0.5, period * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


static func flicker_loop(node: CanvasItem, lo: float = 0.72, hi: float = 1.0, period: float = 1.6) -> void:
	if node == null:
		return
	var tw := node.create_tween().set_loops()
	tw.tween_property(node, "modulate:a", hi, period * 0.4).set_trans(Tween.TRANS_SINE)
	tw.tween_property(node, "modulate:a", lo, period * 0.6).set_trans(Tween.TRANS_SINE)


static func build_title_decor(decor: Control) -> void:
	for c in decor.get_children():
		c.queue_free()
	# Soft vignette top for brand readability over painted bg
	var veil := ColorRect.new()
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veil.set_anchors_preset(Control.PRESET_TOP_WIDE)
	veil.offset_bottom = 360
	veil.color = Color(0.02, 0.06, 0.06, 0.42)
	decor.add_child(veil)
	var mist1 := mist_band(decor, 0.48, 100, 0.1)
	var mist2 := mist_band(decor, 0.62, 80, 0.08)
	drift_loop(mist1, Vector2(22, 0), 5.5)
	drift_loop(mist2, Vector2(-26, 0), 6.8)
	var lantern := lantern_orb(decor, Vector2(340, 620), 16)
	flicker_loop(lantern, 0.7, 1.0, 1.7)
	_spawn_rain(decor)


static func build_lobby_decor(decor: Control) -> void:
	for c in decor.get_children():
		c.queue_free()
	# Soft top veil so brand reads over mist bg
	var veil := ColorRect.new()
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veil.set_anchors_preset(Control.PRESET_TOP_WIDE)
	veil.offset_bottom = 200
	veil.color = Color(0.02, 0.06, 0.06, 0.38)
	decor.add_child(veil)
	mountain_plane(decor, Rect2(Vector2(-20, 980), Vector2(760, 320)), Color(0.08, 0.14, 0.12, 0.75), -0.04)
	var mist := mist_band(decor, 0.78, 60, 0.1)
	drift_loop(mist, Vector2(12, 0), 7.0)
	var lantern := lantern_orb(decor, Vector2(580, 70), 14)
	flicker_loop(lantern, 0.7, 1.0, 2.0)
	var lantern2 := lantern_orb(decor, Vector2(90, 110), 11)
	flicker_loop(lantern2, 0.65, 0.95, 2.4)


static func build_td_terrain(layer: Node2D, w: float, h: float, path: PackedVector2Array) -> void:
	for c in layer.get_children():
		c.queue_free()
	var patches := [
		[Vector2(w * 0.02, h * 0.05), Vector2(150, 100), Color(0.12, 0.22, 0.16, 0.55)],
		[Vector2(w * 0.55, h * 0.08), Vector2(180, 90), Color(0.10, 0.18, 0.14, 0.5)],
		[Vector2(w * 0.45, h * 0.48), Vector2(160, 100), Color(0.14, 0.22, 0.17, 0.48)],
		[Vector2(w * 0.02, h * 0.70), Vector2(140, 90), Color(0.11, 0.19, 0.15, 0.5)],
		[Vector2(w * 0.62, h * 0.78), Vector2(170, 80), Color(0.13, 0.2, 0.15, 0.45)],
	]
	for p in patches:
		var r := ColorRect.new()
		r.position = p[0]
		r.size = p[1]
		r.color = p[2]
		layer.add_child(r)
	for i in 5:
		var stem := ColorRect.new()
		stem.size = Vector2(6, 48 + i * 8)
		stem.position = Vector2(w * 0.08 + i * 28, h * 0.55 + (i % 2) * 20)
		stem.color = Color(0.22, 0.38, 0.28, 0.55)
		layer.add_child(stem)
	if path.size() > 0:
		var gate_pos: Vector2 = path[path.size() - 1]
		var gate := _gate_node()
		gate.position = gate_pos - Vector2(48, 58)
		layer.add_child(gate)
		var spawn := _spawn_marker()
		spawn.position = path[0] - Vector2(20, 20)
		layer.add_child(spawn)


static func _gate_node() -> Control:
	## Ornate 门楼 landmark — readable above bottom HUD.
	var root := Control.new()
	root.custom_minimum_size = Vector2(96, 64)
	root.size = Vector2(96, 64)
	var glow := ColorRect.new()
	glow.size = Vector2(110, 78)
	glow.position = Vector2(-7, -10)
	glow.color = Color(AP.LANTERN_GOLD.r, AP.LANTERN_GOLD.g, AP.LANTERN_GOLD.b, 0.14)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(glow)
	var base := ColorRect.new()
	base.size = Vector2(96, 64)
	base.color = Color(AP.GATE_WOOD.r, AP.GATE_WOOD.g, AP.GATE_WOOD.b, 0.88)
	root.add_child(base)
	var pillar_l := ColorRect.new()
	pillar_l.size = Vector2(12, 54)
	pillar_l.position = Vector2(6, 8)
	pillar_l.color = Color(0.28, 0.18, 0.1, 0.95)
	root.add_child(pillar_l)
	var pillar_r := ColorRect.new()
	pillar_r.size = Vector2(12, 54)
	pillar_r.position = Vector2(78, 8)
	pillar_r.color = Color(0.28, 0.18, 0.1, 0.95)
	root.add_child(pillar_r)
	var roof := ColorRect.new()
	roof.size = Vector2(108, 14)
	roof.position = Vector2(-6, -8)
	roof.color = Color(0.55, 0.28, 0.18, 0.95)
	root.add_child(roof)
	var roof2 := ColorRect.new()
	roof2.size = Vector2(96, 8)
	roof2.position = Vector2(0, 2)
	roof2.color = Color(AP.LANTERN_GOLD.r, AP.LANTERN_GOLD.g, AP.LANTERN_GOLD.b, 0.55)
	root.add_child(roof2)
	var arch := ColorRect.new()
	arch.size = Vector2(40, 36)
	arch.position = Vector2(28, 16)
	arch.color = Color(AP.GATE_SHADOW.r, AP.GATE_SHADOW.g, AP.GATE_SHADOW.b, 0.85)
	root.add_child(arch)
	var title := Label.new()
	title.text = "据点·门楼"
	AP.apply_label(title, 13, AP.LANTERN_GOLD)
	title.position = Vector2(12, 44)
	title.size = Vector2(72, 18)
	root.add_child(title)
	return root


static func _spawn_marker() -> Control:
	var root := Control.new()
	root.size = Vector2(28, 28)
	var outer := ColorRect.new()
	outer.size = Vector2(28, 28)
	outer.color = Color(AP.DANGER.r, AP.DANGER.g, AP.DANGER.b, 0.7)
	root.add_child(outer)
	var inner := ColorRect.new()
	inner.size = Vector2(14, 14)
	inner.position = Vector2(7, 7)
	inner.color = Color(0.08, 0.08, 0.08, 0.8)
	root.add_child(inner)
	var lbl := Label.new()
	lbl.text = "敌"
	AP.apply_label(lbl, 10, AP.PAPER_INK)
	lbl.position = Vector2(6, 6)
	root.add_child(lbl)
	return root



static func _spawn_rain(parent: Control, count: int = 28) -> void:
	var layer := Control.new()
	layer.name = "Rain"
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(layer)
	for i in count:
		var drop := ColorRect.new()
		drop.mouse_filter = Control.MOUSE_FILTER_IGNORE
		drop.size = Vector2(2, 10 + randi() % 12)
		drop.color = Color(0.7, 0.82, 0.78, 0.18 + randf() * 0.12)
		drop.position = Vector2(randf() * 720.0, randf() * 1280.0)
		layer.add_child(drop)
		var dist := 180.0 + randf() * 220.0
		var dur := 1.1 + randf() * 1.4
		var start_pos := drop.position
		var tw := drop.create_tween().set_loops()
		tw.tween_property(drop, "position", start_pos + Vector2(-20, dist), dur).set_trans(Tween.TRANS_LINEAR)
		tw.tween_callback(func():
			drop.position = Vector2(randf() * 720.0, -20.0)
		)
