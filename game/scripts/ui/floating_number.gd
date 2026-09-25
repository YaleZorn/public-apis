extends Label

const AP := preload("res://scripts/util/art_palette.gd")

var _life: float = 0.75


func setup(text: String, color: Color = Color(1, 0.92, 0.55)) -> void:
	self.text = text
	AP.apply_label(self, 18, color)
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	z_index = 50
	modulate.a = 1.0
	scale = Vector2(0.85, 0.85)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "position:y", position.y - 42.0, _life).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "modulate:a", 0.0, _life)
	tw.tween_property(self, "scale", Vector2(1.08, 1.08), _life * 0.35)
	tw.chain().tween_callback(queue_free)
