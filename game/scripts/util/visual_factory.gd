extends RefCounted
class_name VisualFactory
## Atlas silhouettes + role fallbacks — subway-readable wuxia shapes.

const AP := preload("res://scripts/util/art_palette.gd")
const ATLAS_PATH := "res://assets/textures/unit-enemy-atlas.jpg"

# Atlas is 1280x720, 7 figures in one row.
const ATLAS_W := 1280.0
const ATLAS_H := 720.0
const COLS := 7

# Per-index crop insets (L,T,R,B) as fractions of cell — tighter silhouettes.
const CROP_INSETS := [
	Vector4(0.10, 0.06, 0.10, 0.08), # 0 tank
	Vector4(0.12, 0.08, 0.10, 0.10), # 1 dps
	Vector4(0.10, 0.05, 0.10, 0.08), # 2 control
	Vector4(0.11, 0.06, 0.11, 0.08), # 3 support
	Vector4(0.12, 0.10, 0.12, 0.10), # 4 bandit
	Vector4(0.10, 0.07, 0.10, 0.08), # 5 armored
	Vector4(0.14, 0.10, 0.10, 0.12), # 6 fast
]

static var _atlas_tex: Texture2D


static func _atlas() -> Texture2D:
	if _atlas_tex == null and ResourceLoader.exists(ATLAS_PATH):
		_atlas_tex = load(ATLAS_PATH)
	return _atlas_tex


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
		"summon": return 3
		_: return 1


static func _enemy_index(tags: Array) -> int:
	if "armored" in tags:
		return 5
	if "fast" in tags:
		return 6
	return 4


static func unit_node(unit: Dictionary, size: Vector2 = Vector2(64, 72)) -> Control:
	var role := str(unit.get("role", "dps"))
	var root := Control.new()
	root.custom_minimum_size = size
	root.size = size
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var plate := ColorRect.new()
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.size = size
	plate.color = Color(0.03, 0.06, 0.05, 0.42)
	root.add_child(plate)
	# Soft gold rim for silhouette pop on busy terrain
	var rim := ColorRect.new()
	rim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rim.size = size + Vector2(4, 4)
	rim.position = Vector2(-2, -2)
	rim.color = Color(AP.LANTERN_GOLD.r, AP.LANTERN_GOLD.g, AP.LANTERN_GOLD.b, 0.16)
	root.add_child(rim)
	root.move_child(rim, 0)
	var tex := _region(_role_index(role))
	if tex:
		var spr := TextureRect.new()
		spr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		spr.texture = tex
		spr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		spr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		spr.size = size - Vector2(2, 8)
		spr.position = Vector2(1, 1)
		if role == "summon":
			spr.modulate = Color(1.05, 0.95, 0.75, 1.0)
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


static func enemy_node(enemy: Dictionary, size: Vector2 = Vector2(40, 48)) -> Control:
	var tags: Array = enemy.get("tags", [])
	var root := Control.new()
	root.custom_minimum_size = size
	root.size = size
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shadow := ColorRect.new()
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shadow.size = size + Vector2(4, 4)
	shadow.position = Vector2(-2, -2)
	shadow.color = Color(0.02, 0.02, 0.02, 0.45)
	root.add_child(shadow)
	var tex := _region(_enemy_index(tags))
	if tex:
		var spr := TextureRect.new()
		spr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		spr.texture = tex
		spr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		spr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		spr.size = size
		root.add_child(spr)
	else:
		var body := ColorRect.new()
		body.mouse_filter = Control.MOUSE_FILTER_IGNORE
		body.size = size
		body.color = Color(str(enemy.get("color", "#a0522d")))
		root.add_child(body)
	var rim := ColorRect.new()
	rim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rim.size = Vector2(size.x, 4)
	if "fast" in tags:
		rim.color = Color(0.95, 0.35, 0.3)
	elif "armored" in tags:
		rim.color = Color(0.7, 0.75, 0.8)
	else:
		rim.color = Color(0.9, 0.6, 0.35)
	root.add_child(rim)
	var badge := Label.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.text = str(enemy.get("name", "?")).substr(0, 1)
	AP.apply_label(badge, 11, Color(1, 0.94, 0.86))
	badge.position = Vector2(0, size.y - 16)
	badge.size = Vector2(size.x, 14)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(badge)
	return root


static func gate_marker(size: Vector2 = Vector2(84, 56)) -> Control:
	var Atmo := preload("res://scripts/util/atmosphere.gd")
	return Atmo._gate_node()


static func terrain_patch(col: Color, size: Vector2) -> ColorRect:
	var r := ColorRect.new()
	r.size = size
	r.color = col
	return r


static func hit_flash(parent: Node, at: Vector2, color: Color = Color(1, 0.9, 0.55, 0.85)) -> void:
	var flash := ColorRect.new()
	flash.size = Vector2(28, 28)
	flash.position = at - flash.size * 0.5
	flash.color = color
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(flash)
	var tw := flash.create_tween()
	tw.tween_property(flash, "scale", Vector2(1.8, 1.8), 0.12)
	tw.parallel().tween_property(flash, "modulate:a", 0.0, 0.18)
	tw.tween_callback(flash.queue_free)


static func skill_burst(parent: Node, at: Vector2, color: Color = Color(0.7, 0.85, 0.95, 0.7)) -> void:
	var ring := ColorRect.new()
	ring.size = Vector2(40, 40)
	ring.position = at - ring.size * 0.5
	ring.color = color
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(ring)
	var tw := ring.create_tween()
	tw.tween_property(ring, "scale", Vector2(3.2, 3.2), 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(ring, "modulate:a", 0.0, 0.28)
	tw.tween_callback(ring.queue_free)


static func idle_bob(node: Control, amp: float = 3.0, period: float = 2.4) -> void:
	if node == null:
		return
	var base := node.position
	var tw := node.create_tween().set_loops()
	tw.tween_property(node, "position:y", base.y - amp, period * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(node, "position:y", base.y + amp * 0.4, period * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
