extends RefCounted
class_name Atmosphere
## Procedural portrait atmospheres — gradients, mist bands, mountain planes.

const AP := preload("res://scripts/util/art_palette.gd")
const TITLE_BG := "res://assets/textures/title-night-mist.jpg"
const TD_FIELD := "res://assets/textures/td-jiange-field.jpg"
const ATLAS := "res://assets/textures/unit-enemy-atlas.jpg"
const EXPLORE_ROOM := {
	"combat": "res://assets/textures/explore/room_combat.jpg",
	"event": "res://assets/textures/explore/room_event.jpg",
	"train": "res://assets/textures/explore/room_train.jpg",
	"supply": "res://assets/textures/explore/room_supply.jpg",
	"loot": "res://assets/textures/explore/room_loot.jpg",
	"gather": "res://assets/textures/explore/room_loot.jpg",
	"settle": "res://assets/textures/explore/room_supply.jpg",
}


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
		# Aggressive up-shift: painted 门楼 lives in Field, not under bottom HUD.
		bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		bg.offset_top = -180
		bg.offset_bottom = 10
	else:
		bg.texture = night_gradient() if kind != "paper" else paper_gradient()
	parent.add_child(bg)
	parent.move_child(bg, 0)
	return bg


static func explore_room_path(rtype: String) -> String:
	if EXPLORE_ROOM.has(rtype):
		return str(EXPLORE_ROOM[rtype])
	return str(EXPLORE_ROOM.get("combat", TITLE_BG))


static func apply_explore_room(arena: Control, rtype: String) -> void:
	## Authored room plate inside Arena — matches TD field authorship.
	if arena == null:
		return
	var plate := arena.get_node_or_null("RoomArt") as TextureRect
	if plate == null:
		plate = TextureRect.new()
		plate.name = "RoomArt"
		plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
		plate.set_anchors_preset(Control.PRESET_FULL_RECT)
		plate.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		plate.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		arena.add_child(plate)
		arena.move_child(plate, 0)
	var path := explore_room_path(rtype)
	if ResourceLoader.exists(path) or FileAccess.file_exists(path):
		plate.texture = load(path)
		plate.visible = true
	else:
		plate.visible = false
	var veil := arena.get_node_or_null("ArenaBg") as ColorRect
	if veil:
		# Keep arena plate readable — light ink wash only
		veil.color = Color(AP.room_tint(rtype).r, AP.room_tint(rtype).g, AP.room_tint(rtype).b, 0.12)
	_build_explore_props(arena, rtype)


static func _build_explore_props(arena: Control, rtype: String) -> void:
	var old := arena.get_node_or_null("RoomProps")
	if old:
		old.queue_free()
	var layer := Control.new()
	layer.name = "RoomProps"
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	arena.add_child(layer)
	# Keep props under units: move just above RoomArt/ArenaBg
	var insert_at := mini(2, arena.get_child_count() - 1)
	arena.move_child(layer, maxi(insert_at, 0))

	# Parallax depth: far mist / mid props / near fog — thickness ≈ TD field
	var far := mist_band(layer, 0.28, 110, 0.1)
	drift_loop(far, Vector2(14, 0), 9.5)
	var mid := mist_band(layer, 0.48, 88, 0.16)
	drift_loop(mid, Vector2(26, 0), 6.2)
	var near := mist_band(layer, 0.72, 70, 0.2)
	drift_loop(near, Vector2(-20, 0), 4.6)
	var ground := mist_band(layer, 0.88, 48, 0.14)
	drift_loop(ground, Vector2(8, 0), 7.5)
	mountain_plane(layer, Rect2(Vector2(-40, 360), Vector2(780, 260)), Color(0.04, 0.09, 0.08, 0.32), -0.03)
	mountain_plane(layer, Rect2(Vector2(200, 420), Vector2(560, 180)), Color(0.05, 0.11, 0.1, 0.22), 0.02)

	match rtype:
		"combat":
			var lan := lantern_orb(layer, Vector2(520, 70), 14)
			flicker_loop(lan, 0.68, 1.0, 1.5)
			var lan_b := lantern_orb(layer, Vector2(90, 120), 11)
			flicker_loop(lan_b, 0.62, 0.95, 2.1)
			var threat := ColorRect.new()
			threat.mouse_filter = Control.MOUSE_FILTER_IGNORE
			threat.size = Vector2(140, 8)
			threat.position = Vector2(36, 36)
			threat.color = Color(AP.DANGER.r, AP.DANGER.g, AP.DANGER.b, 0.4)
			layer.add_child(threat)
			# Rope rail suggestion
			for i in 4:
				var post := ColorRect.new()
				post.mouse_filter = Control.MOUSE_FILTER_IGNORE
				post.size = Vector2(5, 42 + (i % 2) * 10)
				post.position = Vector2(48 + i * 52, 430)
				post.color = Color(0.32, 0.24, 0.14, 0.55)
				layer.add_child(post)
			_spawn_embers(layer, 10, Color(AP.LANTERN_GOLD.r, AP.LANTERN_GOLD.g, AP.LANTERN_GOLD.b, 0.55))
		"event":
			var lan2 := lantern_orb(layer, Vector2(80, 90), 13)
			flicker_loop(lan2, 0.7, 0.98, 2.2)
			var scroll := ColorRect.new()
			scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
			scroll.size = Vector2(28, 72)
			scroll.position = Vector2(580, 160)
			scroll.color = Color(0.78, 0.72, 0.55, 0.45)
			layer.add_child(scroll)
			mountain_plane(layer, Rect2(Vector2(-30, 400), Vector2(700, 200)), Color(0.06, 0.12, 0.18, 0.38), -0.02)
			_spawn_embers(layer, 6, Color(0.55, 0.75, 0.9, 0.4))
		"train":
			for i in 5:
				var post := ColorRect.new()
				post.mouse_filter = Control.MOUSE_FILTER_IGNORE
				post.size = Vector2(12, 58 + i * 6)
				post.position = Vector2(40 + i * 34, 340 + (i % 2) * 14)
				post.color = Color(0.28, 0.42, 0.32, 0.6)
				layer.add_child(post)
			var lamp := lantern_orb(layer, Vector2(540, 100), 12)
			flicker_loop(lamp, 0.72, 1.0, 1.9)
		"supply", "loot":
			var glow := lantern_orb(layer, Vector2(560, 110), 16)
			flicker_loop(glow, 0.75, 1.0, 1.8)
			for i in 3:
				var crate := ColorRect.new()
				crate.mouse_filter = Control.MOUSE_FILTER_IGNORE
				crate.size = Vector2(58 - i * 6, 30 + i * 4)
				crate.position = Vector2(36 + i * 28, 400 - i * 12)
				crate.color = Color(0.42, 0.32, 0.16, 0.55 + i * 0.05)
				layer.add_child(crate)
			_spawn_embers(layer, 8, Color(AP.LANTERN_GOLD.r, AP.LANTERN_GOLD.g, AP.LANTERN_GOLD.b, 0.5))
		_:
			pass


static func _spawn_embers(parent: Control, count: int, col: Color) -> void:
	for i in count:
		var e := ColorRect.new()
		e.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var s := 3.0 + float(i % 3)
		e.size = Vector2(s, s)
		e.color = col
		e.position = Vector2(40.0 + randf() * 600.0, 80.0 + randf() * 420.0)
		parent.add_child(e)
		var rise := 40.0 + randf() * 70.0
		var dur := 2.2 + randf() * 2.4
		var start := e.position
		var tw := e.create_tween().set_loops()
		tw.tween_property(e, "position", start + Vector2(randf_range(-12, 12), -rise), dur).set_trans(Tween.TRANS_SINE)
		tw.parallel().tween_property(e, "modulate:a", 0.15, dur)
		tw.tween_callback(func():
			e.position = Vector2(40.0 + randf() * 600.0, 200.0 + randf() * 300.0)
			e.modulate.a = 1.0
		)


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
		gate.position = gate_pos - Vector2(44, 50)
		layer.add_child(gate)
		var spawn := _spawn_marker()
		spawn.position = path[0] - Vector2(20, 20)
		layer.add_child(spawn)


static func _gate_node() -> Control:
	## Compact ornate 门楼 — kept clear above bottom HUD (safe band ≥128px).
	var root := Control.new()
	root.custom_minimum_size = Vector2(80, 50)
	root.size = Vector2(80, 50)
	var glow := ColorRect.new()
	glow.size = Vector2(92, 60)
	glow.position = Vector2(-6, -8)
	glow.color = Color(AP.LANTERN_GOLD.r, AP.LANTERN_GOLD.g, AP.LANTERN_GOLD.b, 0.18)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(glow)
	var base := ColorRect.new()
	base.size = Vector2(80, 50)
	base.color = Color(AP.GATE_WOOD.r, AP.GATE_WOOD.g, AP.GATE_WOOD.b, 0.92)
	root.add_child(base)
	var pillar_l := ColorRect.new()
	pillar_l.size = Vector2(9, 40)
	pillar_l.position = Vector2(5, 8)
	pillar_l.color = Color(0.28, 0.18, 0.1, 0.95)
	root.add_child(pillar_l)
	var pillar_r := ColorRect.new()
	pillar_r.size = Vector2(9, 40)
	pillar_r.position = Vector2(66, 8)
	pillar_r.color = Color(0.28, 0.18, 0.1, 0.95)
	root.add_child(pillar_r)
	var roof := ColorRect.new()
	roof.size = Vector2(90, 11)
	roof.position = Vector2(-5, -6)
	roof.color = Color(0.55, 0.28, 0.18, 0.95)
	root.add_child(roof)
	var roof2 := ColorRect.new()
	roof2.size = Vector2(80, 6)
	roof2.position = Vector2(0, 2)
	roof2.color = Color(AP.LANTERN_GOLD.r, AP.LANTERN_GOLD.g, AP.LANTERN_GOLD.b, 0.62)
	root.add_child(roof2)
	var arch := ColorRect.new()
	arch.size = Vector2(32, 26)
	arch.position = Vector2(24, 14)
	arch.color = Color(AP.GATE_SHADOW.r, AP.GATE_SHADOW.g, AP.GATE_SHADOW.b, 0.85)
	root.add_child(arch)
	var title := Label.new()
	title.text = "据点"
	AP.apply_label(title, 11, AP.LANTERN_GOLD)
	title.position = Vector2(14, 34)
	title.size = Vector2(52, 14)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
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
