extends Label

var _life: float = 0.75


func setup(text: String, color: Color = Color(1, 0.92, 0.55)) -> void:
	self.text = text
	add_theme_font_size_override("font_size", 18)
	add_theme_color_override("font_color", color)
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	z_index = 50
	modulate.a = 1.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "position:y", position.y - 36.0, _life)
	tw.tween_property(self, "modulate:a", 0.0, _life)
	tw.chain().tween_callback(queue_free)
