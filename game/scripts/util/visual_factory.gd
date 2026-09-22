extends RefCounted
class_name VisualFactory
## Per-character portrait cards + role accents — subway-readable wuxia identity.

const AP := preload("res://scripts/util/art_palette.gd")
const ATLAS_PATH := "res://assets/textures/unit-enemy-atlas.jpg"
const PORTRAIT_DIR := "res://assets/textures/portraits/"

# Atlas fallback (1280x720, 7 figures).
const ATLAS_W := 1280.0
const ATLAS_H := 720.0
const COLS := 7

const CROP_INSETS := [
	Vector4(0.10, 0.06, 0.10, 0.08),
	Vector4(0.12, 0.08, 0.10, 0.10),
	Vector4(0.10, 0.05, 0.10, 0.08),
	Vector4(0.11, 0.06, 0.11, 0.08),
	Vector4(0.12, 0.10, 0.12, 0.10),
	Vector4(0.10, 0.07, 0.10, 0.08),
	Vector4(0.14, 0.10, 0.10, 0.12),
]

static var _atlas_tex: Texture2D
static var _portrait_cache: Dictionary = {}


## --- Shaped FX primitives (Polygon2D / Line2D — not ColorRect blobs) ---

static func _fx_diamond(sz: Vector2, col: Color) -> Polygon2D:
	var p := Polygon2D.new()
	var w := sz.x * 0.5
	var h := sz.y * 0.5
	p.polygon = PackedVector2Array([
		Vector2(w, 0.0), Vector2(sz.x, h), Vector2(w, sz.y), Vector2(0.0, h)
	])
	p.color = col
	return p


static func _fx_petal(sz: Vector2, col: Color) -> Polygon2D:
	## Soft leaf / petal — heal / mist sparks.
	var p := Polygon2D.new()
	var w := sz.x
	var h := sz.y
	p.polygon = PackedVector2Array([
		Vector2(w * 0.5, 0.0),
		Vector2(w * 0.92, h * 0.35),
		Vector2(w * 0.55, h),
		Vector2(w * 0.08, h * 0.35),
	])
	p.color = col
	return p


static func _fx_blade(length: float, thickness: float, col: Color) -> Polygon2D:
	## Tapered slash wedge — readable crescent substitute.
	var p := Polygon2D.new()
	p.polygon = PackedVector2Array([
		Vector2(0.0, thickness * 0.5),
		Vector2(length * 0.18, 0.0),
		Vector2(length, thickness * 0.32),
		Vector2(length * 0.18, thickness),
	])
	p.color = col
	return p


static func _fx_disc(radius: float, col: Color, segs: int = 14) -> Polygon2D:
	var p := Polygon2D.new()
	var pts := PackedVector2Array()
	var c := Vector2(radius, radius)
	for i in segs:
		var a := TAU * float(i) / float(segs)
		pts.append(c + Vector2(cos(a), sin(a)) * radius)
	p.polygon = pts
	p.color = col
	return p


static func _fx_ring(radius: float, width: float, col: Color, segs: int = 22) -> Line2D:
	var line := Line2D.new()
	line.width = width
	line.default_color = col
	line.closed = true
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	var pts := PackedVector2Array()
	for i in (segs + 1):
		var a := TAU * float(i) / float(segs)
		pts.append(Vector2(cos(a), sin(a)) * radius)
	line.points = pts
	return line


static func _atlas() -> Texture2D:
	if _atlas_tex == null and ResourceLoader.exists(ATLAS_PATH):
		_atlas_tex = load(ATLAS_PATH)
	return _atlas_tex


static func _portrait_tex(id: String) -> Texture2D:
	if id == "":
		return null
	if _portrait_cache.has(id):
		return _portrait_cache[id]
	var path := PORTRAIT_DIR + id + ".png"
	if ResourceLoader.exists(path) or FileAccess.file_exists(path):
		var tex: Texture2D = load(path)
		_portrait_cache[id] = tex
		return tex
	_portrait_cache[id] = null
	return null


static func _region(index: int) -> AtlasTexture:
	var src := _atlas()
	if src == null:
		return null
	var cell_w := ATLAS_W / float(COLS)
	var inset: Vector4 = CROP_INSETS[clampi(index, 0, CROP_INSETS.size() - 1)]
	var at := AtlasTexture.new()
	at.atlas = src
	at.region = Rect2(
		index * cell_w + cell_w * inset.x,
		ATLAS_H * inset.y,
		cell_w * (1.0 - inset.x - inset.z),
		ATLAS_H * (1.0 - inset.y - inset.w)
	)
	return at


static func _role_index(role: String) -> int:
	match role:
		"tank": return 0
		"dps": return 1
		"control": return 2
		"support": return 3
		"summon": return 1
		_: return 1


static func _enemy_index(tags: Array) -> int:
	if "armored" in tags:
		return 5
	if "fast" in tags:
		return 6
	return 4


static func _unit_tex(unit: Dictionary) -> Texture2D:
	var tex := _portrait_tex(str(unit.get("id", "")))
	if tex:
		return tex
	return _region(_role_index(str(unit.get("role", "dps"))))


static func _enemy_tex(enemy: Dictionary) -> Texture2D:
	var tex := _portrait_tex(str(enemy.get("id", "")))
	if tex:
		return tex
	return _region(_enemy_index(enemy.get("tags", [])))


static func unit_node(unit: Dictionary, size: Vector2 = Vector2(64, 72)) -> Control:
	var role := str(unit.get("role", "dps"))
	var root := Control.new()
	root.custom_minimum_size = size
	root.size = size
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.set_meta("unit_id", str(unit.get("id", "")))
	root.set_meta("role", role)

	var rim := ColorRect.new()
	rim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rim.size = size + Vector2(4, 4)
	rim.position = Vector2(-2, -2)
	rim.color = Color(AP.LANTERN_GOLD.r, AP.LANTERN_GOLD.g, AP.LANTERN_GOLD.b, 0.22)
	root.add_child(rim)

	var plate := ColorRect.new()
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.size = size
	plate.color = Color(0.03, 0.06, 0.05, 0.55)
	root.add_child(plate)

	var tex := _unit_tex(unit)
	if tex:
		var spr := TextureRect.new()
		spr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		spr.texture = tex
		spr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		spr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		spr.size = size - Vector2(2, 6)
		spr.position = Vector2(1, 1)
		# Match enemy midtone lift so TD/explore stands share visual weight
		spr.modulate = Color(1.06, 1.04, 1.02, 1.0)
		root.add_child(spr)
	else:
		_draw_unit_body(root, role, Color(str(unit.get("color", "#6a8f71"))), size)

	var strip := ColorRect.new()
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.size = Vector2(size.x, 5)
	strip.position = Vector2(0, size.y - 5)
	strip.color = AP.role_accent(role)
	root.add_child(strip)

	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = str(unit.get("name", "?")).substr(0, 2)
	AP.apply_label(label, 12, AP.PAPER_INK)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(0, size.y - 22)
	label.size = Vector2(size.x, 18)
	root.add_child(label)
	root.set_meta("idle_bob", true)
	return root


## Lobby / roster: taller portrait card with faction + role chip.
static func portrait_card(unit: Dictionary, size: Vector2 = Vector2(96, 120), selected: bool = false, locked: bool = false) -> Control:
	var role := str(unit.get("role", "dps"))
	var root := Control.new()
	root.custom_minimum_size = size
	root.size = size
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var frame := ColorRect.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.size = size
	frame.color = Color(0.05, 0.10, 0.09, 0.92)
	root.add_child(frame)

	var border := ColorRect.new()
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	border.size = size + Vector2(4, 4)
	border.position = Vector2(-2, -2)
	border.color = Color(AP.LANTERN_GOLD.r, AP.LANTERN_GOLD.g, AP.LANTERN_GOLD.b, 0.55 if selected else 0.28)
	root.add_child(border)
	root.move_child(border, 0)

	var tex := _unit_tex(unit)
	if tex:
		var spr := TextureRect.new()
		spr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		spr.texture = tex
		spr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		spr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		spr.size = Vector2(size.x - 6, size.y - 28)
		spr.position = Vector2(3, 3)
		# Unified midtone lift across roster (portraits normalized offline)
		spr.modulate = Color(1.04, 1.03, 1.02, 1.0)
		root.add_child(spr)

	var role_chip := ColorRect.new()
	role_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	role_chip.size = Vector2(size.x - 6, 22)
	role_chip.position = Vector2(3, size.y - 25)
	role_chip.color = Color(AP.role_accent(role).r, AP.role_accent(role).g, AP.role_accent(role).b, 0.85)
	root.add_child(role_chip)

	var name_l := Label.new()
	name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_l.text = str(unit.get("name", "?"))
	AP.apply_label(name_l, 12, AP.PAPER_INK)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.position = Vector2(0, size.y - 24)
	name_l.size = Vector2(size.x, 20)
	root.add_child(name_l)

	if selected:
		var star := Label.new()
		star.mouse_filter = Control.MOUSE_FILTER_IGNORE
		star.text = "★"
		AP.apply_label(star, 14, AP.LANTERN_GOLD)
		star.position = Vector2(4, 4)
		root.add_child(star)
	elif locked:
		var lock := lock_badge(Vector2(22, 24))
		lock.position = Vector2(3, 3)
		root.add_child(lock)
	return root


static func _draw_unit_body(root: Control, role: String, col: Color, size: Vector2) -> void:
	var body := ColorRect.new()
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	match role:
		"tank":
			body.size = size - Vector2(10, 14)
			body.position = Vector2(5, 6)
			body.color = col
			root.add_child(body)
		_:
			body.size = Vector2(size.x * 0.45, size.y * 0.7)
			body.position = Vector2(size.x * 0.28, size.y * 0.1)
			body.color = col
			root.add_child(body)


static func enemy_node(enemy: Dictionary, size: Vector2 = Vector2(48, 58)) -> Control:
	## Standing portrait parity with ally unit_node — readable midtones, gold plate, name.
	var tags: Array = enemy.get("tags", [])
	var root := Control.new()
	root.custom_minimum_size = size
	root.size = size
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.set_meta("enemy_id", str(enemy.get("id", "")))

	var threat := Color(0.9, 0.6, 0.35)
	if "fast" in tags:
		threat = Color(0.95, 0.38, 0.32)
	elif "armored" in tags:
		threat = Color(0.72, 0.78, 0.84)

	var rim := ColorRect.new()
	rim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rim.size = size + Vector2(4, 4)
	rim.position = Vector2(-2, -2)
	rim.color = Color(threat.r, threat.g, threat.b, 0.42)
	root.add_child(rim)

	var plate := ColorRect.new()
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.size = size
	plate.color = Color(0.04, 0.07, 0.06, 0.62)
	root.add_child(plate)

	var tex := _enemy_tex(enemy)
	if tex:
		var spr := TextureRect.new()
		spr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		spr.texture = tex
		spr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		spr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		spr.size = size - Vector2(2, 8)
		spr.position = Vector2(1, 1)
		# Parity midtone lift with ally stands (portraits already normalized)
		spr.modulate = Color(1.08, 1.05, 1.03, 1.0)
		root.add_child(spr)
	else:
		var body := ColorRect.new()
		body.mouse_filter = Control.MOUSE_FILTER_IGNORE
		body.size = size - Vector2(8, 12)
		body.position = Vector2(4, 4)
		body.color = Color(str(enemy.get("color", "#a0522d")))
		root.add_child(body)

	var strip := ColorRect.new()
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.size = Vector2(size.x, 5)
	strip.position = Vector2(0, size.y - 5)
	strip.color = threat
	root.add_child(strip)

	# HP bar above frame
	var hp_bg := ColorRect.new()
	hp_bg.name = "HpBg"
	hp_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_bg.size = Vector2(size.x, 5)
	hp_bg.position = Vector2(0, -8)
	hp_bg.color = Color(0.06, 0.06, 0.06, 0.8)
	root.add_child(hp_bg)
	var hp_fill := ColorRect.new()
	hp_fill.name = "HpFill"
	hp_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_fill.size = Vector2(size.x, 5)
	hp_fill.position = Vector2(0, -8)
	hp_fill.color = Color(0.85, 0.35, 0.28, 0.95)
	root.add_child(hp_fill)

	var badge := Label.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.text = str(enemy.get("name", "?")).substr(0, 2)
	AP.apply_label(badge, 12, AP.PAPER_INK)
	badge.position = Vector2(0, size.y - 22)
	badge.size = Vector2(size.x, 18)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(badge)
	root.set_meta("idle_bob", true)
	return root


static func set_enemy_hp_ratio(node: Control, ratio: float) -> void:
	if node == null:
		return
	var fill := node.get_node_or_null("HpFill") as ColorRect
	if fill == null:
		return
	var w := node.custom_minimum_size.x if node.custom_minimum_size.x > 0 else node.size.x
	fill.size.x = maxf(1.0, w * clampf(ratio, 0.0, 1.0))
	if ratio < 0.35:
		fill.color = Color(0.95, 0.25, 0.2, 0.95)
	elif ratio < 0.65:
		fill.color = Color(0.95, 0.7, 0.3, 0.95)
	else:
		fill.color = Color(0.85, 0.35, 0.28, 0.95)


static func attach_hero_hp(node: Control) -> void:
	## Thin HP strip above ally stand — shared combat ring readability.
	if node == null or node.get_node_or_null("HeroHpFill") != null:
		return
	var w := node.custom_minimum_size.x if node.custom_minimum_size.x > 0 else node.size.x
	var hp_bg := ColorRect.new()
	hp_bg.name = "HeroHpBg"
	hp_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_bg.size = Vector2(w, 6)
	hp_bg.position = Vector2(0, -10)
	hp_bg.color = Color(0.05, 0.07, 0.06, 0.85)
	node.add_child(hp_bg)
	var hp_fill := ColorRect.new()
	hp_fill.name = "HeroHpFill"
	hp_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_fill.size = Vector2(w, 6)
	hp_fill.position = Vector2(0, -10)
	hp_fill.color = Color(0.45, 0.82, 0.58, 0.95)
	node.add_child(hp_fill)
	var shield := ColorRect.new()
	shield.name = "HeroShieldFill"
	shield.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shield.size = Vector2(0, 3)
	shield.position = Vector2(0, -14)
	shield.color = Color(0.55, 0.75, 0.95, 0.9)
	node.add_child(shield)


static func set_hero_hp_ratio(node: Control, hp_ratio: float, shield_ratio: float = 0.0) -> void:
	if node == null:
		return
	var fill := node.get_node_or_null("HeroHpFill") as ColorRect
	var w := node.custom_minimum_size.x if node.custom_minimum_size.x > 0 else node.size.x
	if fill:
		fill.size.x = maxf(1.0, w * clampf(hp_ratio, 0.0, 1.0))
		if hp_ratio < 0.35:
			fill.color = Color(0.95, 0.35, 0.28, 0.95)
		elif hp_ratio < 0.65:
			fill.color = Color(0.92, 0.78, 0.4, 0.95)
		else:
			fill.color = Color(0.45, 0.82, 0.58, 0.95)
	var sh := node.get_node_or_null("HeroShieldFill") as ColorRect
	if sh:
		sh.size.x = maxf(0.0, w * clampf(shield_ratio, 0.0, 1.0))


static func placement_ring(parent: Node, at: Vector2, color: Color = Color(0.9, 0.76, 0.42, 0.75)) -> void:
	if parent == null:
		return
	var ring := _fx_ring(14.0, 3.2, color, 20)
	ring.position = at
	ring.z_index = 12
	parent.add_child(ring)
	var tw := ring.create_tween()
	tw.tween_property(ring, "scale", Vector2(2.8, 2.8), 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(ring, "modulate:a", 0.0, 0.28)
	tw.tween_callback(ring.queue_free)
	# Soft gold dust diamonds
	for i in 4:
		var d := _fx_diamond(Vector2(8, 8), Color(AP.LANTERN_GOLD.r, AP.LANTERN_GOLD.g, AP.LANTERN_GOLD.b, 0.9))
		d.position = at - Vector2(4, 4)
		d.z_index = 12
		parent.add_child(d)
		var ang := TAU * float(i) / 4.0
		var dest := at + Vector2(cos(ang), sin(ang)) * 36.0 - Vector2(4, 4)
		var dtw := d.create_tween()
		dtw.tween_property(d, "position", dest, 0.26)
		dtw.parallel().tween_property(d, "modulate:a", 0.0, 0.26)
		dtw.tween_callback(d.queue_free)


static func placement_burst(parent: Node, at: Vector2, color: Color = Color(0.95, 0.82, 0.48, 0.9)) -> void:
	## TD place: ring + lantern disc + radial diamonds — readable from subway distance.
	if parent == null:
		return
	placement_ring(parent, at, color)
	var core := _fx_disc(11.0, Color(AP.LANTERN_GOLD.r, AP.LANTERN_GOLD.g, AP.LANTERN_GOLD.b, 0.95), 12)
	core.position = at - Vector2(11, 11)
	core.z_index = 13
	parent.add_child(core)
	var ctw := core.create_tween()
	ctw.tween_property(core, "scale", Vector2(2.4, 2.4), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	ctw.parallel().tween_property(core, "modulate:a", 0.0, 0.26)
	ctw.tween_callback(core.queue_free)
	for i in 6:
		var spark := _fx_diamond(Vector2(10, 10), Color(color.r, color.g, color.b, 0.95))
		spark.position = at - Vector2(5, 5)
		spark.z_index = 13
		parent.add_child(spark)
		var ang := TAU * float(i) / 6.0
		var dest := at + Vector2(cos(ang), sin(ang)) * 48.0 - Vector2(5, 5)
		var stw := spark.create_tween()
		stw.tween_property(spark, "position", dest, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		stw.parallel().tween_property(spark, "modulate:a", 0.0, 0.3)
		stw.tween_callback(spark.queue_free)
	slash_arc(parent, at, color, 0.75)


static func lane_telegraph(parent: Node, points: PackedVector2Array, color: Color = Color(1.0, 0.78, 0.42, 0.0), width: float = 16.0) -> void:
	## Pulse along a path (main wave or flank) — dual-pass for subway readability.
	if parent == null or points.size() < 2:
		return
	var line := Line2D.new()
	line.width = width
	line.default_color = Color(color.r, color.g, color.b, 0.0)
	line.z_index = 8
	line.points = points
	parent.add_child(line)
	var outline := Line2D.new()
	outline.width = width + 10.0
	outline.default_color = Color(color.r, color.g, color.b, 0.0)
	outline.z_index = 7
	outline.points = points
	parent.add_child(outline)
	var tw := line.create_tween()
	tw.tween_property(line, "default_color:a", 0.78, 0.16)
	tw.parallel().tween_property(outline, "default_color:a", 0.28, 0.16)
	tw.tween_property(line, "default_color:a", 0.0, 0.55)
	tw.parallel().tween_property(outline, "default_color:a", 0.0, 0.55)
	tw.tween_callback(func():
		if is_instance_valid(line):
			line.queue_free()
		if is_instance_valid(outline):
			outline.queue_free()
	)
	# Chase sparks along path
	var spark_n := mini(5, points.size())
	for i in spark_n:
		var idx := int(round(float(i) * float(points.size() - 1) / float(maxi(spark_n - 1, 1))))
		var pt: Vector2 = points[idx]
		var delay := 0.05 * float(i)
		var spark := _fx_diamond(Vector2(16, 16), Color(color.r, color.g, color.b, 0.0))
		spark.position = pt - Vector2(8, 8)
		spark.z_index = 9
		parent.add_child(spark)
		var stw := spark.create_tween()
		stw.tween_interval(delay)
		stw.tween_property(spark, "modulate:a", 1.0, 0.08)
		stw.tween_property(spark, "scale", Vector2(2.0, 2.0), 0.22)
		stw.parallel().tween_property(spark, "modulate:a", 0.0, 0.22)
		stw.tween_callback(spark.queue_free)


static func flank_telegraph(parent: Node, points: PackedVector2Array) -> void:
	## Brief bright pulse along flank path when ambush wave starts.
	if parent == null or points.size() < 2:
		return
	lane_telegraph(parent, points, Color(1.0, 0.45, 0.32, 0.0), 15.0)
	# Origin flare
	placement_ring(parent, points[0], Color(1.0, 0.5, 0.35, 0.85))
	slash_arc(parent, points[0], Color(1.0, 0.5, 0.35, 0.9), 1.0)


static func wave_telegraph(parent: Node, points: PackedVector2Array) -> void:
	## Main-lane wave start pulse (gold) — pairs with flank_telegraph.
	if parent == null or points.size() < 2:
		return
	lane_telegraph(parent, points, Color(1.0, 0.82, 0.42, 0.0), 14.0)
	placement_ring(parent, points[0], Color(AP.LANTERN_GOLD.r, AP.LANTERN_GOLD.g, AP.LANTERN_GOLD.b, 0.85))


static func gate_marker(size: Vector2 = Vector2(84, 56)) -> Control:
	var Atmo := preload("res://scripts/util/atmosphere.gd")
	return Atmo._gate_node()


static func terrain_patch(col: Color, size: Vector2) -> ColorRect:
	var r := ColorRect.new()
	r.size = size
	r.color = col
	return r


static func hit_flash(parent: Node, at: Vector2, color: Color = Color(1, 0.9, 0.55, 0.85)) -> void:
	hit_impact(parent, at, color)


static func hit_impact(parent: Node, at: Vector2, color: Color = Color(1, 0.9, 0.55, 0.85)) -> void:
	## Readable hit: disc core + blade strokes + expanding ring.
	if parent == null:
		return
	var flash := _fx_disc(12.0, color, 12)
	flash.position = at - Vector2(12, 12)
	flash.z_index = 14
	parent.add_child(flash)
	for i in 3:
		var slash := _fx_blade(30.0 + float(i) * 8.0, 4.0, Color(color.r, color.g, color.b, 0.75 - i * 0.15))
		slash.position = at + Vector2(-16 - i * 2, -8 + i * 6)
		slash.rotation = -0.65 + i * 0.4
		slash.z_index = 14
		parent.add_child(slash)
		var stw := slash.create_tween()
		stw.tween_property(slash, "modulate:a", 0.0, 0.18)
		stw.parallel().tween_property(slash, "position", slash.position + Vector2(10, -4), 0.18)
		stw.tween_callback(slash.queue_free)
	var ring := _fx_ring(10.0, 2.4, Color(color.r, color.g, color.b, 0.7), 18)
	ring.position = at
	ring.z_index = 14
	parent.add_child(ring)
	var rtw := ring.create_tween()
	rtw.tween_property(ring, "scale", Vector2(2.6, 2.6), 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	rtw.parallel().tween_property(ring, "modulate:a", 0.0, 0.2)
	rtw.tween_callback(ring.queue_free)
	var tw := flash.create_tween()
	tw.tween_property(flash, "scale", Vector2(2.0, 2.0), 0.12)
	tw.parallel().tween_property(flash, "modulate:a", 0.0, 0.18)
	tw.tween_callback(flash.queue_free)


static func slash_arc(parent: Node, at: Vector2, color: Color, scale_mult: float = 1.0) -> void:
	## Wide crescent slash — tapered Polygon2D blades, subway-readable.
	if parent == null:
		return
	for i in 4:
		var blade := _fx_blade((42.0 + float(i) * 10.0) * scale_mult, 5.0, Color(color.r, color.g, color.b, 0.85 - i * 0.12))
		blade.position = at + Vector2(-8, -12 + i * 7)
		blade.rotation = -0.95 + i * 0.28
		blade.z_index = 14
		parent.add_child(blade)
		var tw := blade.create_tween()
		tw.tween_property(blade, "rotation", blade.rotation + 0.55, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(blade, "modulate:a", 0.0, 0.2)
		tw.tween_callback(blade.queue_free)


static func attack_strike(parent: Node, attacker: Control, target: Control, color: Color = Color(1.0, 0.92, 0.55, 0.9)) -> void:
	## Lunge toward target + slash arc + travel spark — beyond flash/bob.
	if parent == null or attacker == null or target == null:
		return
	if not is_instance_valid(attacker) or not is_instance_valid(target):
		return
	var from := attacker.position + attacker.custom_minimum_size * 0.5
	var to := target.position + target.custom_minimum_size * 0.5
	var dir := (to - from)
	if dir.length() < 4.0:
		dir = Vector2(40, 0)
	var lunge := dir.normalized() * minf(28.0, dir.length() * 0.22)
	var base := attacker.position
	var tw := attacker.create_tween()
	tw.tween_property(attacker, "position", base + lunge, 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(attacker, "position", base, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	slash_arc(parent, to, color, 1.05)
	# Travel diamond along strike line
	var spark := _fx_diamond(Vector2(14, 14), Color(color.r, color.g, color.b, 0.95))
	spark.position = from - Vector2(7, 7)
	spark.z_index = 14
	parent.add_child(spark)
	var stw := spark.create_tween()
	stw.tween_property(spark, "position", to - Vector2(7, 7), 0.1)
	stw.parallel().tween_property(spark, "modulate:a", 0.35, 0.1)
	stw.tween_callback(spark.queue_free)
	# Secondary trail blade
	var trail := _fx_blade(maxf(16.0, dir.length() * 0.2), 4.0, Color(color.r, color.g, color.b, 0.7))
	trail.position = from
	trail.rotation = dir.angle()
	trail.z_index = 13
	parent.add_child(trail)
	var trtw := trail.create_tween()
	trtw.tween_property(trail, "modulate:a", 0.0, 0.12)
	trtw.tween_callback(trail.queue_free)


static func td_attack_fx(parent: Node, attacker: Control, target: Control, color: Color = Color(1.0, 0.92, 0.55, 0.9)) -> void:
	## TD volley: short lunge + travel bolt + impact — matches AutoCombatRing readability.
	if parent == null or attacker == null or target == null:
		return
	if not is_instance_valid(attacker) or not is_instance_valid(target):
		return
	var from := attacker.position + attacker.custom_minimum_size * 0.5
	var to := target.position + target.custom_minimum_size * 0.5
	var dir := to - from
	var dist := dir.length()
	if dist < 4.0:
		dir = Vector2(0, -40)
		dist = 40.0
	# Slot units: smaller lunge so they stay readable on pads
	var lunge := dir.normalized() * minf(18.0, dist * 0.12)
	var base := attacker.position
	var tw := attacker.create_tween()
	tw.tween_property(attacker, "position", base + lunge, 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(attacker, "position", base, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Thick travel bolt (tapered blade)
	var bolt := _fx_blade(maxf(18.0, dist * 0.18), 6.0, Color(color.r, color.g, color.b, 0.95))
	bolt.position = from
	bolt.rotation = dir.angle()
	bolt.z_index = 14
	parent.add_child(bolt)
	var btw := bolt.create_tween()
	btw.tween_property(bolt, "position", to - Vector2(9, 3), 0.09)
	btw.parallel().tween_property(bolt, "modulate:a", 0.25, 0.09)
	btw.tween_callback(bolt.queue_free)
	# Tip diamond
	var tip := _fx_diamond(Vector2(14, 14), Color(AP.LANTERN_GOLD.r, AP.LANTERN_GOLD.g, AP.LANTERN_GOLD.b, 1.0))
	tip.position = from - Vector2(7, 7)
	tip.z_index = 15
	parent.add_child(tip)
	var ttw := tip.create_tween()
	ttw.tween_property(tip, "position", to - Vector2(7, 7), 0.09)
	ttw.tween_callback(tip.queue_free)
	slash_arc(parent, to, color, 0.95)
	hit_impact(parent, to, color)


static func skill_cast_fx(parent: Node, at: Vector2, effect: String, color: Color = Color(0.7, 0.85, 0.95, 0.7)) -> void:
	## Per-effect readable skill presentation (aoe / heal / shield / slow / default).
	if parent == null:
		return
	match effect:
		"aoe_damage":
			skill_burst(parent, at, color)
			slash_arc(parent, at + Vector2(20, 0), color, 1.35)
			slash_arc(parent, at + Vector2(-16, 12), color, 1.1)
		"heal":
			# Rising jade petals
			for i in 5:
				var petal := _fx_petal(Vector2(12, 16), Color(color.r, color.g, color.b, 0.9))
				petal.position = at + Vector2(-20 + i * 10, 8)
				petal.z_index = 14
				parent.add_child(petal)
				var ptw := petal.create_tween()
				ptw.tween_property(petal, "position:y", petal.position.y - 48.0 - i * 4.0, 0.36).set_trans(Tween.TRANS_SINE)
				ptw.parallel().tween_property(petal, "modulate:a", 0.0, 0.36)
				ptw.tween_callback(petal.queue_free)
			skill_burst(parent, at, color)
		"shield":
			# Expanding shield disc + rim
			var plate := _fx_disc(28.0, Color(color.r, color.g, color.b, 0.5), 16)
			plate.position = at - Vector2(28, 28)
			plate.z_index = 14
			parent.add_child(plate)
			var shield_rim := _fx_ring(30.0, 3.0, Color(color.r, color.g, color.b, 0.85), 20)
			shield_rim.position = at
			shield_rim.z_index = 15
			parent.add_child(shield_rim)
			var ptw2 := plate.create_tween()
			ptw2.tween_property(plate, "scale", Vector2(1.55, 1.55), 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			ptw2.parallel().tween_property(plate, "modulate:a", 0.0, 0.32)
			ptw2.tween_callback(plate.queue_free)
			var rtw2 := shield_rim.create_tween()
			rtw2.tween_property(shield_rim, "scale", Vector2(1.7, 1.7), 0.3)
			rtw2.parallel().tween_property(shield_rim, "modulate:a", 0.0, 0.3)
			rtw2.tween_callback(shield_rim.queue_free)
			skill_burst(parent, at, color)
		"slow_all":
			# Frost wash bands as Line2D
			for i in 3:
				var band := Line2D.new()
				band.width = 7.0
				band.default_color = Color(color.r, color.g, color.b, 0.75)
				band.z_index = 14
				var y := at.y - 20.0 + float(i) * 18.0
				band.points = PackedVector2Array([Vector2(at.x - 60, y), Vector2(at.x + 60, y)])
				parent.add_child(band)
				var btw := band.create_tween()
				btw.tween_method(func(w: float):
					if is_instance_valid(band):
						band.points = PackedVector2Array([Vector2(at.x - w * 0.5, y), Vector2(at.x + w * 0.5, y)])
				, 120.0, 180.0, 0.28)
				btw.parallel().tween_property(band, "modulate:a", 0.0, 0.3)
				btw.tween_callback(band.queue_free)
			skill_burst(parent, at, color)
		_:
			skill_burst(parent, at, color)
			slash_arc(parent, at, color, 1.0)


static func lock_badge(size: Vector2 = Vector2(22, 24)) -> Control:
	## Proper 「锁」 glyph on jade seal — not ColorRect padlock geometry.
	var root := Control.new()
	root.custom_minimum_size = size
	root.size = size
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Soft jade seal plate behind the character
	var seal := _fx_disc(size.x * 0.48, Color(0.06, 0.12, 0.10, 0.88), 16)
	seal.position = Vector2(size.x * 0.02, size.y * 0.02)
	root.add_child(seal)
	var rim := _fx_ring(size.x * 0.42, 1.6, Color(AP.LANTERN_GOLD.r, AP.LANTERN_GOLD.g, AP.LANTERN_GOLD.b, 0.55), 18)
	rim.position = Vector2(size.x * 0.5, size.y * 0.5)
	root.add_child(rim)
	var glyph := Label.new()
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glyph.text = "锁"
	AP.apply_label(glyph, int(clampf(size.y * 0.72, 14.0, 22.0)), Color(0.86, 0.90, 0.82, 0.98))
	glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	glyph.position = Vector2(-1, -2)
	glyph.size = size + Vector2(2, 4)
	root.add_child(glyph)
	return root


static func skill_burst(parent: Node, at: Vector2, color: Color = Color(0.7, 0.85, 0.95, 0.7)) -> void:
	if parent == null:
		return
	# Expanding outer ring
	var ring := _fx_ring(18.0, 3.5, color, 20)
	ring.position = at
	ring.z_index = 14
	parent.add_child(ring)
	# Inner core pulse
	var core := _fx_disc(9.0, Color(AP.LANTERN_GOLD.r, AP.LANTERN_GOLD.g, AP.LANTERN_GOLD.b, 0.85), 12)
	core.position = at - Vector2(9, 9)
	core.z_index = 15
	parent.add_child(core)
	# Radial diamond sparks
	for i in 6:
		var spark := _fx_diamond(Vector2(10, 10), Color(color.r, color.g, color.b, 0.9))
		spark.position = at - Vector2(5, 5)
		spark.z_index = 14
		parent.add_child(spark)
		var ang := TAU * float(i) / 6.0
		var dest := at + Vector2(cos(ang), sin(ang)) * 56.0 - Vector2(5, 5)
		var stw := spark.create_tween()
		stw.tween_property(spark, "position", dest, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		stw.parallel().tween_property(spark, "modulate:a", 0.0, 0.28)
		stw.tween_callback(spark.queue_free)
	var tw := ring.create_tween()
	tw.tween_property(ring, "scale", Vector2(3.2, 3.2), 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(ring, "modulate:a", 0.0, 0.32)
	tw.tween_callback(ring.queue_free)
	var ctw := core.create_tween()
	ctw.tween_property(core, "scale", Vector2(2.2, 2.2), 0.2)
	ctw.parallel().tween_property(core, "modulate:a", 0.0, 0.22)
	ctw.tween_callback(core.queue_free)


static func death_puff(parent: Node, at: Vector2, color: Color = Color(0.9, 0.55, 0.35, 0.8)) -> void:
	if parent == null:
		return
	for i in 5:
		var p := _fx_diamond(Vector2(12, 12), color)
		p.position = at - Vector2(6, 6)
		p.z_index = 12
		parent.add_child(p)
		var ang := TAU * float(i) / 5.0 + randf() * 0.4
		var dest := at + Vector2(cos(ang), sin(ang)) * (28.0 + randf() * 24.0) - Vector2(6, 6)
		var tw := p.create_tween()
		tw.tween_property(p, "position", dest, 0.28)
		tw.parallel().tween_property(p, "modulate:a", 0.0, 0.28)
		tw.tween_callback(p.queue_free)


static func room_wipe(parent: Control, color: Color = Color(0.04, 0.10, 0.09, 0.85)) -> void:
	if parent == null:
		return
	var veil := ColorRect.new()
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	veil.color = Color(color.r, color.g, color.b, 0.0)
	parent.add_child(veil)
	var tw := veil.create_tween()
	tw.tween_property(veil, "color:a", color.a, 0.12)
	tw.tween_property(veil, "color:a", 0.0, 0.22)
	tw.tween_callback(veil.queue_free)


static func idle_bob(node: Control, amp: float = 3.0, period: float = 2.4) -> void:
	if node == null:
		return
	var base := node.position
	var tw := node.create_tween().set_loops()
	tw.tween_property(node, "position:y", base.y - amp, period * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(node, "position:y", base.y + amp * 0.4, period * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
