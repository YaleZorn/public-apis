extends Control
## Knowledge book + morning 3-question quiz — jade journal look.

const AP := preload("res://scripts/util/art_palette.gd")
const Atmo := preload("res://scripts/util/atmosphere.gd")

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
	Atmo.attach_full_bg(self, "night")
	var old_bg := get_node_or_null("Bg")
	if old_bg:
		old_bg.visible = false
	AP.apply_label(quiz_title, 26, AP.LANTERN_GOLD)
	AP.apply_label(status, 15, AP.PAPER_DIM)
	AP.apply_richtext(book, 15)
	Juice.start_ambient()
	_polish_book_panel()
	back_btn.pressed.connect(func():
		Juice.play_sfx("tap")
		Juice.fade_transition(func(): GameState.go_lobby())
	)
	start_quiz_btn.pressed.connect(_start_quiz)
	start_quiz_btn.theme_type_variation = &"ButtonPrimary"
	_refresh_book()
	_refresh_quiz_state()
	Juice.slide_in(quiz_title, 16.0, 0.28)


func _polish_book_panel() -> void:
	var panel := get_node_or_null("VBox/BookPanel") as PanelContainer
	if panel == null:
		return
	# Soft jade paper plate over mist bg
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.12, 0.11, 0.92)
	style.border_color = Color(AP.LANTERN_GOLD.r, AP.LANTERN_GOLD.g, AP.LANTERN_GOLD.b, 0.45)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", style)
	# Top gold rule accent
	var rule := ColorRect.new()
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rule.custom_minimum_size = Vector2(0, 3)
	rule.color = Color(AP.LANTERN_GOLD.r, AP.LANTERN_GOLD.g, AP.LANTERN_GOLD.b, 0.55)
	var vbox := get_node_or_null("VBox") as VBoxContainer
	if vbox:
		var idx := panel.get_index()
		vbox.add_child(rule)
		vbox.move_child(rule, idx)


func _refresh_book() -> void:
	book.clear()
	book.append_text("[color=#e6c15a][b]健身知识本[/b][/color]  ·  墨笺\n")
	book.append_text("[color=#5a9a90]%d 条已录 · 局内遇见解锁详情[/color]\n" % ContentDB.knowledge_list.size())
	book.append_text("[color=#5a9a90][i]%s[/i][/color]\n\n" % ContentDB.knowledge_disclaimer)
	for entry in ContentDB.knowledge_list:
		var seen: bool = entry["id"] in GameState.knowledge_seen
		var topic := str(entry.get("topic", ""))
		if seen:
			book.append_text("[color=#e6c15a]◆[/color] [b][color=#e8e0d0]%s[/color][/b]  [color=#5a9a90]%s[/color]\n" % [
				entry.get("title", ""), topic
			])
			book.append_text("[color=#c8d8c8]建议[/color]  %s\n" % entry.get("correct", ""))
			book.append_text("[color=#8a9a90]因果[/color]  %s\n\n" % entry.get("why", ""))
		else:
			book.append_text("[color=#4a5a52]◇[/color] [b][color=#8a9488]%s[/color][/b]  [color=#4a5a52]%s[/color]\n" % [
				entry.get("title", ""), topic
			])
			book.append_text("[i][color=#4a5a52]—— 雾中未开 ——[/color][/i]\n\n")


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
	Juice.play_sfx("card")
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
	AP.apply_label(qlabel, 17, AP.PAPER_INK)
	quiz_box.add_child(qlabel)
	var choices: Array = q.get("choices", [])
	var answer := int(q.get("answer", 0))
	for i in choices.size():
		var b := Button.new()
		b.text = str(choices[i])
		b.custom_minimum_size = Vector2(0, 52)
		b.pressed.connect(_answer.bind(i == answer, entry["id"]))
		quiz_box.add_child(b)
	Juice.slide_in(qlabel, 10.0, 0.2)


func _answer(correct: bool, kid: String) -> void:
	Juice.play_sfx("tap")
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
	AP.apply_label(tip, 15, AP.MIST_TEAL.lightened(0.2))
	quiz_box.add_child(tip)
	start_quiz_btn.visible = true
	_refresh_book()
	_refresh_quiz_state()
