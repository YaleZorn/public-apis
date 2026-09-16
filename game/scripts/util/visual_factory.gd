extends RefCounted
class_name VisualFactory
## Coherent shape language for units/enemies until final art lands.

static func unit_node(unit: Dictionary, size: Vector2 = Vector2(58, 58)) -> Control:
	var role := str(unit.get("role", "dps"))
	var col := Color(str(unit.get("color", "#6a8f71")))
	var root := Control.new()
	root.custom_minimum_size = size
	root.size = size
	# Soft outer plate
	var plate := ColorRect.new()
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.size = size
	plate.color = Color(0.08, 0.1, 0.09, 0.75)
	root.add_child(plate)
	var body := ColorRect.new()
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.size = size - Vector2(8, 8)
	body.position = Vector2(4, 4)
	body.color = col
	root.add_child(body)
	# Role accent strip
	var strip := ColorRect.new()
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.size = Vector2(size.x, 6)
	strip.position = Vector2(0, size.y - 6)
	strip.color = _role_accent(role)
	root.add_child(strip)
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = str(unit.get("name", "?")).substr(0, 2)
	label.add_theme_font_size_override("font_size", 14)
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
	root.size = size
	var body := ColorRect.new()
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.size = size
	body.color = col.darkened(0.05)
	root.add_child(body)
	# Tag edge color: fast=red rim, armored=steel rim
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
	badge.add_theme_font_size_override("font_size", 12)
	badge.add_theme_color_override("font_color", Color(1, 0.94, 0.86))
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(badge)
	return root


static func gate_marker(size: Vector2 = Vector2(84, 56)) -> Control:
	var root := Control.new()
	root.custom_minimum_size = size
	root.size = size
	var base := ColorRect.new()
	base.size = size
	base.color = Color(0.55, 0.42, 0.22, 0.95)
	root.add_child(base)
	var arch := ColorRect.new()
	arch.size = Vector2(size.x * 0.5, size.y * 0.7)
	arch.position = Vector2(size.x * 0.25, size.y * 0.08)
	arch.color = Color(0.1, 0.14, 0.12)
	root.add_child(arch)
	var title := Label.new()
	title.text = "剑阁"
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", Color(0.95, 0.86, 0.55))
	title.position = Vector2(14, size.y - 24)
	root.add_child(title)
	return root


static func terrain_patch(col: Color, size: Vector2) -> ColorRect:
	var r := ColorRect.new()
	r.size = size
	r.color = col
	return r


static func _role_accent(role: String) -> Color:
	match role:
		"tank": return Color(0.45, 0.7, 0.5)
		"support": return Color(0.45, 0.85, 0.55)
		"control": return Color(0.45, 0.65, 0.95)
		"summon": return Color(0.9, 0.75, 0.35)
		_: return Color(0.9, 0.55, 0.3)
