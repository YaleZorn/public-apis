extends Control
## Knowledge book + morning quiz + spaced review — jade journal product surface.

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
var _topic_filter: String = "全部" ## 全部 / 训练 / 饮食 / 作息 / 待复习
var _filter_bar: HBoxContainer
var _review_btn: Button
var _pack_label: Label


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
	_build_filter_bar()
	_ensure_demo_gear()
	back_btn.pressed.connect(func():
		Juice.play_sfx("tap")
		Juice.fade_transition(func(): GameState.go_lobby())
	)
	start_quiz_btn.pressed.connect(_start_quiz)
	start_quiz_btn.theme_type_variation = &"ButtonPrimary"
	_refresh_book()
	_refresh_quiz_state()
	Juice.slide_in(quiz_title, 16.0, 0.28)


func _ensure_demo_gear() -> void:
	if GameState.owns_content_pack("demo_mountain"):
		if ContentDB.gear.has("gear_demo_trail_charm"):
			GameState.unlock_gear("gear_demo_trail_charm")


func _polish_book_panel() -> void:
	var panel := get_node_or_null("VBox/BookPanel") as PanelContainer
	if panel == null:
		return
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
	var rule := ColorRect.new()
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rule.custom_minimum_size = Vector2(0, 3)
	rule.color = Color(AP.LANTERN_GOLD.r, AP.LANTERN_GOLD.g, AP.LANTERN_GOLD.b, 0.55)
	var vbox := get_node_or_null("VBox") as VBoxContainer
	if vbox:
		var idx := panel.get_index()
		vbox.add_child(rule)
		vbox.move_child(rule, idx)


func _build_filter_bar() -> void:
	var vbox := get_node_or_null("VBox") as VBoxContainer
	if vbox == null:
		return
	_pack_label = Label.new()
	_pack_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	AP.apply_label(_pack_label, 13, AP.MIST_TEAL.lightened(0.15))
	vbox.add_child(_pack_label)
	vbox.move_child(_pack_label, 1)
	_filter_bar = HBoxContainer.new()
	_filter_bar.add_theme_constant_override("separation", 6)
	for topic in ["全部", "训练", "饮食", "作息", "待复习"]:
		var b := Button.new()
		b.text = topic
		b.custom_minimum_size = Vector2(0, 40)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_set_topic_filter.bind(topic))
		_filter_bar.add_child(b)
	vbox.add_child(_filter_bar)
	vbox.move_child(_filter_bar, 2)
	_review_btn = Button.new()
	_review_btn.custom_minimum_size = Vector2(0, 48)
	_review_btn.theme_type_variation = &"ButtonPrimary"
	_review_btn.pressed.connect(_start_review_session)
	vbox.add_child(_review_btn)
	# Place review btn after start quiz — find StartQuizBtn index
	var quiz_idx := start_quiz_btn.get_index()
	vbox.move_child(_review_btn, quiz_idx + 1)


func _set_topic_filter(topic: String) -> void:
	Juice.play_sfx("tap")
	_topic_filter = topic
	_refresh_book()
	_refresh_quiz_state()


func _refresh_book() -> void:
	var total := ContentDB.knowledge_list.size()
	var seen_n := GameState.knowledge_seen.size()
	var due_n := GameState.knowledge_due_ids().size()
	var tier := GameState.knowledge_progress_tier()
	var pack_bits: PackedStringArray = PackedStringArray()
	for man in ContentDB.packs:
		var pid := str(man.get("content_pack", ""))
		var owned := ContentDB.is_pack_owned(pid)
		var name := str(man.get("display_name", pid))
		if owned:
			pack_bits.append("✓ %s" % name)
		else:
			pack_bits.append("○ %s（未挂载）" % name)
	if _pack_label:
		_pack_label.text = "内容包：%s" % " · ".join(pack_bits)
	book.clear()
	book.append_text("[color=#e6c15a][b]健身知识本[/b][/color]  ·  墨笺\n")
	book.append_text("[color=#5a9a90]进度 %d/%d · 待复习 %d · 功力档 %d[/color]\n" % [
		seen_n, total, due_n, tier
	])
	book.append_text("[color=#5a9a90][i]%s[/i][/color]\n\n" % ContentDB.knowledge_disclaimer)
	var due_set := {}
	for kid in GameState.knowledge_due_ids():
		due_set[kid] = true
	for entry in ContentDB.knowledge_list:
		var topic := str(entry.get("topic", ""))
		var kid := str(entry.get("id", ""))
		if _topic_filter == "待复习":
			if not due_set.has(kid):
				continue
		elif _topic_filter != "全部" and topic != _topic_filter:
			continue
		var seen: bool = kid in GameState.knowledge_seen
		var pack_tag := str(entry.get("content_pack", "core"))
		var pack_note := ""
		if pack_tag != "core":
			pack_note = "  [color=#6a8a7a][%s][/color]" % pack_tag
		var due_mark := " [color=#c9a227]复[/color]" if due_set.has(kid) else ""
		if seen:
			book.append_text("[color=#e6c15a]◆[/color] [b][color=#e8e0d0]%s[/color][/b]  [color=#5a9a90]%s[/color]%s%s\n" % [
				entry.get("title", ""), topic, pack_note, due_mark
			])
			book.append_text("[color=#c8d8c8]建议[/color]  %s\n" % entry.get("correct", ""))
			book.append_text("[color=#8a9a90]因果[/color]  %s\n\n" % entry.get("why", ""))
		else:
			book.append_text("[color=#4a5a52]◇[/color] [b][color=#8a9488]%s[/color][/b]  [color=#4a5a52]%s[/color]%s\n" % [
				entry.get("title", ""), topic, pack_note
			])
			book.append_text("[i][color=#4a5a52]—— 雾中未开 ——[/color][/i]\n\n")


func _refresh_quiz_state() -> void:
	var due_n := GameState.knowledge_due_ids().size()
	if _review_btn:
		_review_btn.disabled = due_n <= 0 or _in_quiz
		_review_btn.text = "间隔复习（%d 待复）" % due_n if due_n > 0 else "间隔复习（暂无）"
	if GameState.can_morning_quiz():
		start_quiz_btn.disabled = false
		start_quiz_btn.text = "晨课测验（3 题）"
		status.text = "今日尚未晨课。答对 ≥2 题获得轻量局内 buff。待复习 %d。" % due_n
	else:
		start_quiz_btn.disabled = true
		start_quiz_btn.text = "今日晨课已完成"
		var live := GameState.is_morning_buff_live()
		var bonuses: Dictionary = GameState.knowledge_meta_bonuses()
		status.text = "晨课 buff：%s · 知识功力档 %d（微小常驻加成）· 待复习 %d" % [
			"生效中" if live else "未激活", int(bonuses.get("tier", 0)), due_n
		]
	# Highlight active filter
	if _filter_bar:
		for c in _filter_bar.get_children():
			if c is Button:
				c.disabled = (c as Button).text == _topic_filter


func _start_review_session() -> void:
	Juice.play_sfx("card")
	var due := GameState.knowledge_due_ids()
	_quiz_items = []
	for kid in due:
		_quiz_items.append(ContentDB.knowledge[kid])
	_quiz_items.shuffle()
	_quiz_items = _quiz_items.slice(0, mini(5, _quiz_items.size()))
	if _quiz_items.is_empty():
		status.text = "暂无到期复习。"
		return
	_quiz_index = 0
	_quiz_score = 0
	_in_quiz = true
	start_quiz_btn.visible = false
	if _review_btn:
		_review_btn.visible = false
	_show_quiz_question(true)


func _start_quiz() -> void:
	Juice.play_sfx("card")
	_quiz_items = _pick_quiz_items(3)
	_quiz_index = 0
	_quiz_score = 0
	_in_quiz = true
	start_quiz_btn.visible = false
	if _review_btn:
		_review_btn.visible = false
	_show_quiz_question(false)


func _pick_quiz_items(n: int) -> Array:
	var pool: Array = []
	var due := GameState.knowledge_due_ids()
	for kid in due:
		if ContentDB.knowledge.has(kid):
			pool.append(ContentDB.knowledge[kid])
	for kid in GameState.knowledge_review_queue:
		if ContentDB.knowledge.has(kid) and ContentDB.knowledge[kid] not in pool:
			pool.append(ContentDB.knowledge[kid])
	for entry in ContentDB.knowledge_list:
		if entry not in pool:
			pool.append(entry)
	pool.shuffle()
	# Prefer due items first half
	var preferred: Array = []
	for kid in due:
		if ContentDB.knowledge.has(kid):
			preferred.append(ContentDB.knowledge[kid])
	preferred.shuffle()
	var out: Array = []
	for e in preferred:
		if out.size() >= n:
			break
		out.append(e)
	pool.shuffle()
	for e in pool:
		if out.size() >= n:
			break
		if e not in out:
			out.append(e)
	return out


func _show_quiz_question(is_review: bool = false) -> void:
	for c in quiz_box.get_children():
		if c != quiz_title:
			c.queue_free()
	if _quiz_index >= _quiz_items.size():
		_finish_quiz(is_review)
		return
	var entry: Dictionary = _quiz_items[_quiz_index]
	var quiz: Array = entry.get("quiz", [])
	if quiz.is_empty():
		_quiz_index += 1
		_show_quiz_question(is_review)
		return
	var q: Dictionary = quiz[0]
	var kind := "复习" if is_review else "晨课"
	quiz_title.text = "%s %d/%d · %s" % [kind, _quiz_index + 1, _quiz_items.size(), entry.get("title", "")]
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
		b.pressed.connect(_answer.bind(i == answer, entry["id"], is_review))
		quiz_box.add_child(b)
	Juice.slide_in(qlabel, 10.0, 0.2)


func _answer(correct: bool, kid: String, is_review: bool = false) -> void:
	if correct:
		_quiz_score += 1
		Juice.play_sfx("quiz_ok")
		Juice.pulse(quiz_title, 1.08, 0.14)
		Juice.float_number(quiz_box.global_position + Vector2(quiz_box.size.x * 0.5, 24), "正", Color(0.6, 0.9, 0.65))
	else:
		Juice.play_sfx("quiz_bad")
		Juice.flash_modulate(quiz_title, Color(1.3, 0.7, 0.6, 1.0), 0.18)
		Juice.float_number(quiz_box.global_position + Vector2(quiz_box.size.x * 0.5, 24), "误", Color(0.95, 0.5, 0.4))
	GameState.mark_knowledge_delivered(kid, correct)
	_quiz_index += 1
	_show_quiz_question(is_review)


func _finish_quiz(is_review: bool = false) -> void:
	_in_quiz = false
	if not is_review:
		GameState.complete_morning_quiz(_quiz_score)
	else:
		GameState.persist_meta_keep_checkpoints()
	quiz_title.text = ("%s结束：%d/%d" % ["复习" if is_review else "晨课", _quiz_score, _quiz_items.size()])
	for c in quiz_box.get_children():
		if c != quiz_title:
			c.queue_free()
	var tip := Label.new()
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if is_review:
		tip.text = "间隔复习已写入。答对会推迟下次到期；错题立即回队列。"
	else:
		tip.text = "答对 ≥2 获得轻量 buff（TD 开局银两 / 探索护盾）。错题进间隔复习。" if _quiz_score >= 2 else "明日再来。错题已进复习队列。"
	AP.apply_label(tip, 15, AP.MIST_TEAL.lightened(0.2))
	quiz_box.add_child(tip)
	Juice.slide_in(tip, 12.0, 0.22)
	if _quiz_score >= 2:
		Juice.play_sfx("win")
		Juice.pulse(quiz_title, 1.1, 0.2)
	else:
		Juice.play_sfx("card")
	start_quiz_btn.visible = true
	if _review_btn:
		_review_btn.visible = true
	_refresh_book()
	_refresh_quiz_state()
