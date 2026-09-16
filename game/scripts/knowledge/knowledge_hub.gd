extends Control
## Knowledge book + morning 3-question quiz with light buff.

@onready var book: RichTextLabel = %Book
@onready var quiz_box: VBoxContainer = %QuizBox
@onready var quiz_title: Label = %QuizTitle
@onready var status: Label = %Status
@onready var back_btn: Button = %BackBtn
@onready var start_quiz_btn: Button = %StartQuizBtn

var _quiz_items: Array = []
var _quiz_index: int = 0
var _quiz_score: int = 0
var _in_quiz: bool = false


func _ready() -> void:
	back_btn.pressed.connect(func(): GameState.go_lobby())
	start_quiz_btn.pressed.connect(_start_quiz)
	_refresh_book()
	_refresh_quiz_state()


func _refresh_book() -> void:
	book.clear()
	book.append_text("[b]健身知识本[/b]（%d 条）\n" % ContentDB.knowledge_list.size())
	book.append_text("[i]%s[/i]\n\n" % ContentDB.knowledge_disclaimer)
	for entry in ContentDB.knowledge_list:
		var seen: bool = entry["id"] in GameState.knowledge_seen
		var mark := "✓" if seen else "○"
		book.append_text("%s [b]%s[/b] · %s\n%s\n因果：%s\n\n" % [
			mark, entry.get("title", ""), entry.get("topic", ""),
			entry.get("correct", ""), entry.get("why", "")
		])


func _refresh_quiz_state() -> void:
	if GameState.can_morning_quiz():
		start_quiz_btn.disabled = false
		start_quiz_btn.text = "晨课测验（3 题）"
		status.text = "今日尚未晨课。答对 ≥2 题获得轻量局内 buff。"
	else:
		start_quiz_btn.disabled = true
		start_quiz_btn.text = "今日晨课已完成"
		status.text = "晨课 buff：%s" % ("生效中" if GameState.morning_buff_active else "未激活")


func _start_quiz() -> void:
	_quiz_items = _pick_quiz_items(3)
	_quiz_index = 0
	_quiz_score = 0
	_in_quiz = true
	start_quiz_btn.visible = false
	_show_quiz_question()


func _pick_quiz_items(n: int) -> Array:
	var pool: Array = []
	for kid in GameState.knowledge_review_queue:
		if ContentDB.knowledge.has(kid):
			pool.append(ContentDB.knowledge[kid])
	for entry in ContentDB.knowledge_list:
		if entry not in pool:
			pool.append(entry)
	pool.shuffle()
	return pool.slice(0, mini(n, pool.size()))


func _show_quiz_question() -> void:
	for c in quiz_box.get_children():
		if c != quiz_title:
			c.queue_free()
	if _quiz_index >= _quiz_items.size():
		_finish_quiz()
		return
	var entry: Dictionary = _quiz_items[_quiz_index]
	var quiz: Array = entry.get("quiz", [])
	if quiz.is_empty():
		_quiz_index += 1
		_show_quiz_question()
		return
	var q: Dictionary = quiz[0]
	quiz_title.text = "晨课 %d/%d · %s" % [_quiz_index + 1, _quiz_items.size(), entry.get("title", "")]
	var qlabel := Label.new()
	qlabel.text = str(q.get("q", ""))
	qlabel.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	quiz_box.add_child(qlabel)
	var choices: Array = q.get("choices", [])
	var answer := int(q.get("answer", 0))
	for i in choices.size():
		var b := Button.new()
		b.text = str(choices[i])
		b.custom_minimum_size = Vector2(0, 48)
		b.pressed.connect(_answer.bind(i == answer, entry["id"]))
		quiz_box.add_child(b)


func _answer(correct: bool, kid: String) -> void:
	if correct:
		_quiz_score += 1
	GameState.mark_knowledge_delivered(kid, correct)
	_quiz_index += 1
	_show_quiz_question()


func _finish_quiz() -> void:
	_in_quiz = false
	GameState.complete_morning_quiz(_quiz_score)
	quiz_title.text = "晨课结束：%d/%d" % [_quiz_score, _quiz_items.size()]
	for c in quiz_box.get_children():
		if c != quiz_title:
			c.queue_free()
	var tip := Label.new()
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.text = "答对 ≥2 获得轻量 buff（TD 开局银两 +20 / 探索开局小护盾）。" if _quiz_score >= 2 else "明日再来。错题已进复习队列。"
	quiz_box.add_child(tip)
	start_quiz_btn.visible = true
	_refresh_book()
	_refresh_quiz_state()
