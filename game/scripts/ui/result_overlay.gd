extends CanvasLayer
## Full-screen win/lose/retreat overlay with one primary action.

signal confirmed

@onready var panel: PanelContainer = %Panel
@onready var title_label: Label = %Title
@onready var body_label: Label = %Body
@onready var action_btn: Button = %ActionBtn
@onready var dim: ColorRect = %Dim

var _callback: Callable


func _ready() -> void:
	visible = false
	action_btn.pressed.connect(_on_action)


func show_result(title: String, body: String, button_text: String, accent: Color, callback: Callable) -> void:
	title_label.text = title
	body_label.text = body
	action_btn.text = button_text
	panel.modulate = Color(accent.r, accent.g, accent.b, 1.0)
	_callback = callback
	visible = true
	dim.modulate.a = 0.0
	panel.scale = Vector2(0.92, 0.92)
	var tw := create_tween()
	tw.tween_property(dim, "modulate:a", 1.0, 0.18)
	tw.parallel().tween_property(panel, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Juice.play_sfx("win" if "胜" in title or "通关" in title else "lose")


func _on_action() -> void:
	visible = false
	if _callback.is_valid():
		_callback.call()
	confirmed.emit()
