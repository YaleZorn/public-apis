extends Control
## Portrait lobby: continue > TD / explore / knowledge / roster.

@onready var title_label: Label = %TitleLabel
@onready var subtitle: Label = %Subtitle
@onready var continue_btn: Button = %ContinueBtn
@onready var td_btn: Button = %TdBtn
@onready var explore_btn: Button = %ExploreBtn
@onready var knowledge_btn: Button = %KnowledgeBtn
@onready var roster_label: RichTextLabel = %RosterLabel
@onready var status_label: Label = %StatusLabel
@onready var hero_bar: HBoxContainer = %HeroBar


func _ready() -> void:
	title_label.text = "剑阁·健身"
	subtitle.text = "守卫剑阁 · 栈道夜行 · 真知识"
	continue_btn.pressed.connect(_on_continue)
	td_btn.pressed.connect(func(): GameState.go_td(false))
	explore_btn.pressed.connect(func(): GameState.go_explore(false))
	knowledge_btn.pressed.connect(func(): GameState.go_knowledge())
	_refresh()
	GameState.meta_changed.connect(_refresh)
	GameState.checkpoint_changed.connect(_refresh)


func _refresh() -> void:
	var has_resume := GameState.has_resume()
	continue_btn.visible = has_resume
	continue_btn.text = "续关（%s）" % ("塔防" if GameState.resume_target() == "td" else "探索")
	var unlocked := GameState.unlocked_units.size()
	var seen := GameState.knowledge_seen.size()
	var review := GameState.knowledge_review_queue.size()
	roster_label.clear()
	roster_label.append_text("[b]阵容[/b] %d/6 已解锁 · 点选下方设探索主角\n" % unlocked)
	for uid in GameState.unlocked_units:
		var u: Dictionary = ContentDB.get_unit(uid)
		var mastery := int(GameState.hero_mastery.get(uid, 0))
		var mark := "★" if uid == GameState.explore_hero_id else "·"
		roster_label.append_text("%s %s（%s）熟练 %d\n" % [mark, u.get("name", uid), u.get("role", "?"), mastery])
	status_label.text = "知识已学 %d/15 · 待复习 %d · 银两仓 %d%s" % [
		seen, review, GameState.silver_bank,
		" · 晨课 buff" if GameState.morning_buff_active else ""
	]
	knowledge_btn.text = "知识本 / 晨课" + ("（可测）" if GameState.can_morning_quiz() else "")
	_rebuild_hero_bar()


func _rebuild_hero_bar() -> void:
	for c in hero_bar.get_children():
		c.queue_free()
	for uid in GameState.unlocked_units:
		var u: Dictionary = ContentDB.get_unit(uid)
		var b := Button.new()
		b.text = str(u.get("name", uid))
		b.custom_minimum_size = Vector2(0, 40)
		if uid == GameState.explore_hero_id:
			b.disabled = true
			b.text = "★ " + b.text
		b.pressed.connect(func():
			GameState.explore_hero_id = uid
			GameState.persist_meta_keep_checkpoints()
			_refresh()
		)
		hero_bar.add_child(b)


func _on_continue() -> void:
	if GameState.resume_target() == "td":
		GameState.go_td(true)
	elif GameState.resume_target() == "explore":
		GameState.go_explore(true)
