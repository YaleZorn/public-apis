extends RefCounted
class_name VisualFactory
## Coherent shape language for units/enemies until final art lands.

static func unit_node(unit: Dictionary, size: Vector2 = Vector2(58, 58)) -> Control:
	var role := str(unit.get("role", "dps"))
	var col := Color(str(unit.get("color", "#6a8f71")))
	var root := Control.new()
	root.custom_minimum_size = size
	var body := _shape_for_role(role, size, col)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(body)
	var ring := ColorRect.new()
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.size = size + Vector2(6, 6)
	ring.position = Vector2(-3, -3)
	ring.color = Color(col.r, col.g, col.b, 0.22)
	root.add_child(ring)
	root.move_child(ring, 0)
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = str(unit.get("name", "?")).substr(0, 2)
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(0.98, 0.95, 0.88))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(label)
	return root


static func enemy_node(enemy: Dictionary, size: Vector2 = Vector2(32, 32)) -> Control:
	var tags: Array = enemy.get("tags", [])
	var col := Color(str(enemy.get("color", "#a0522d")))
	var root := Control.new()
	root.custom_minimum_size = size
	var shape := "square"
	if "fast" in tags:
		shape = "diamond"
	elif "armored" in tags:
		shape = "hex"
	var body := _shape(shape, size, col.darkened(0.05))
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(body)
	var badge := Label.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.text = str(enemy.get("name", "?")).substr(0, 1)
	badge.add_theme_font_size_override("font_size", 11)
	badge.add_theme_color_override("font_color", Color(1, 0.94, 0.86))
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(badge)
	return root


static func gate_marker(size: Vector2 = Vector2(72, 48)) -> Control:
	var root := Control.new()
	root.custom_minimum_size = size
	var base := ColorRect.new()
	base.size = size
	base.color = Color(0.55, 0.42, 0.22, 0.95)
	root.add_child(base)
	var arch := ColorRect.new()
	arch.size = Vector2(size.x * 0.55, size.y * 0.65)
	arch.position = Vector2(size.x * 0.225, size.y * 0.1)
	arch.color = Color(0.12, 0.16, 0.14)
	root.add_child(arch)
	var title := Label.new()
	title.text = "剑阁"
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(0.95, 0.86, 0.55))
	title.position = Vector2(8, size.y - 22)
	root.add_child(title)
	return root


static func terrain_patch(col: Color, size: Vector2) -> ColorRect:
	var r := ColorRect.new()
	r.size = size
	r.color = col
	return r


static func _shape_for_role(role: String, size: Vector2, col: Color) -> Control:
	match role:
		"tank":
			return _shape("square", size, col)
		"support":
			return _shape("circle", size, col)
		"control":
			return _shape("diamond", size, col.lightened(0.05))
		"summon":
			return _shape("hex", size, col)
		_:
			return _shape("diamond", size, col)


static func _shape(kind: String, size: Vector2, col: Color) -> Control:
	var c := Control.new()
	c.custom_minimum_size = size
	var body := ColorRect.new()
	body.size = size
	body.color = col
	if kind == "circle":
		# Approximate with smaller square + tint — readable without shaders.
		body.size = size * 0.92
		body.position = (size - body.size) * 0.5
		body.color = col.lightened(0.06)
	elif kind == "diamond":
		body.rotation = deg_to_rad(45)
		body.size = size * 0.72
		body.position = (size - body.size) * 0.5
	elif kind == "hex":
		body.color = col.darkened(0.08)
	c.add_child(body)
	var edge := ColorRect.new()
	edge.size = size
	edge.color = Color(col.r, col.g, col.b, 0.35)
	edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(edge)
	c.move_child(edge, 0)
	return c
