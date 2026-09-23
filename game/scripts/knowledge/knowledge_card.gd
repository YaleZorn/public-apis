extends CanvasLayer
## Situational knowledge card: 2–4 lines + pick one reasonable action.

signal resolved(entry_id: String, correct: bool)

@onready var panel: PanelContainer = %Panel
@onready var title: Label = %Title
@onready var body: RichTextLabel = %Body
@onready var choices: VBoxContainer = %Choices

var _entry_id: String = ""
var _answered: bool = false


func present(entry_id: String) -> void:
	_entry_id = entry_id
	_answered = false
	visible = true
	var entry: Dictionary = ContentDB.get_knowledge(entry_id)
	if entry.is_empty():
		_finish(true)
		return
	title.text = "功法笺 · %s" % entry.get("title", entry_id)
	var scen: Dictionary = entry.get("scenario", {})
	body.clear()
	body.append_text("%s" % scen.get("prompt", entry.get("misconception", "选最合理的做法：")))
	Juice.play_sfx("card")
	for c in choices.get_children():
		c.queue_free()
	var opts: Array = scen.get("choices", [])
	if opts.is_empty():
		var btn := Button.new()
		btn.text = "记下：%s" % entry.get("correct", "了解")
		btn.pressed.connect(func(): _pick(true))
		choices.add_child(btn)
		return
	for opt in opts:
		var b := Button.new()
		b.text = str(opt.get("text", "?"))
		b.custom_minimum_size = Vector2(0, 52)
		var is_correct := bool(opt.get("correct", false))
		b.pressed.connect(_pick.bind(is_correct))
		choices.add_child(b)


func _pick(correct: bool) -> void:
	if _answered:
		return
	_answered = true
	GameState.mark_knowledge_delivered(_entry_id, correct)
	var entry: Dictionary = ContentDB.get_knowledge(_entry_id)
	body.append_text("\n\n[b]%s[/b]\n建议：%s\n[i]%s[/i]" % [
		"答对了" if correct else "再想想",
		entry.get("correct", ""),
		entry.get("why", ""),
	])
	await get_tree().create_timer(0.85).timeout
	_finish(correct)


func _finish(correct: bool) -> void:
	visible = false
	resolved.emit(_entry_id, correct)
