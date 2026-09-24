extends Control
## Game hub (v0.11): one 「下一步」, soft-locked secondary modes, brand-first calm.

const AP := preload("res://scripts/util/art_palette.gd")
const Atmo := preload("res://scripts/util/atmosphere.gd")
const VF := preload("res://scripts/util/visual_factory.gd")

@onready var title_label: Label = %TitleLabel
@onready var subtitle: Label = %Subtitle
@onready var quest_title: Label = %QuestTitle
@onready var quest_detail: Label = %QuestDetail
@onready var next_btn: Button = %NextBtn
@onready var continue_btn: Button = %ContinueBtn
@onready var new_td_btn: Button = %NewTdBtn
@onready var new_explore_btn: Button = %NewExploreBtn
@onready var knowledge_btn: Button = %KnowledgeBtn
@onready var hero_name: Label = %HeroName
@onready var hero_bar: HBoxContainer = %HeroBar
@onready var status_label: Label = %StatusLabel
@onready var settings_btn: Button = %SettingsBtn
@onready var settings_panel: PanelContainer = %SettingsPanel
@onready var decor: Control = %Decor
@onready var secondary_row: HBoxContainer = %SecondaryRow

var _idle_btn: Button
var _tower_btn: Button
var _arena_btn: Button


func _ready() -> void:
	Atmo.attach_full_bg(self, "night")
	var old_bg := get_node_or_null("Bg")
	if old_bg:
		old_bg.visible = false
	var accent := get_node_or_null("Accent")
	if accent:
		accent.visible = false
	title_label.text = "剑阁·健身"
	AP.apply_label(title_label, 48, AP.LANTERN_GOLD)
	subtitle.text = "守卫剑阁"
	AP.apply_label(subtitle, 16, AP.MIST_TEAL.lightened(0.22))
	AP.apply_label(quest_title, 20, AP.PAPER_INK)
	AP.apply_label(quest_detail, 14, AP.PAPER_DIM)
	AP.apply_label(hero_name, 14, AP.MIST_TEAL.lightened(0.18))
	AP.apply_label(status_label, 13, Color(0.62, 0.70, 0.62, 1))

	_idle_btn = get_node_or_null("%IdleStubBtn") as Button
	_tower_btn = get_node_or_null("%TowerStubBtn") as Button
	_arena_btn = get_node_or_null("%ArenaStubBtn") as Button

	next_btn.theme_type_variation = &"ButtonPrimary"
	continue_btn.theme_type_variation = &"ButtonPrimary"
	new_td_btn.theme_type_variation = &"ButtonPrimary"
	# Secondary modes: normal chrome (not all Primary).
	new_explore_btn.theme_type_variation = &""
	knowledge_btn.theme_type_variation = &""

	next_btn.pressed.connect(_on_next_action)
	continue_btn.pressed.connect(_on_continue)
	new_td_btn.pressed.connect(func(): _start_mode("td"))
	new_explore_btn.pressed.connect(func(): _start_mode("explore"))
	knowledge_btn.pressed.connect(func():
		Juice.play_sfx("tap")
		Juice.fade_transition(func(): GameState.go_knowledge())
	)
	if _idle_btn:
		_idle_btn.pressed.connect(func():
			if not GameState.is_mode_unlocked("idle"):
				return
			Juice.play_sfx("tap")
			Juice.fade_transition(func(): GameState.go_idle())
		)
	if _arena_btn:
		_arena_btn.pressed.connect(func():
			if not GameState.is_mode_unlocked("arena"):
				Juice.play_sfx("tap")
				return
			Juice.play_sfx("tap")
			Juice.fade_transition(func(): GameState.go_arena(false))
		)
	if _tower_btn:
		_tower_btn.pressed.connect(func():
			if not GameState.is_mode_unlocked("tower"):
				Juice.play_sfx("tap")
				return
			Juice.play_sfx("tap")
			Juice.fade_transition(func(): GameState.go_tower(false))
		)
	settings_btn.pressed.connect(_toggle_settings)
	settings_panel.visible = false
	_build_settings()
	Atmo.build_lobby_decor(decor)
	Juice.start_lobby_music()
	GameState.refresh_idle_accrual()
	_refresh()
	GameState.meta_changed.connect(_refresh)
	GameState.checkpoint_changed.connect(_refresh)
	# Soft entrance motion for hub focus.
	Juice.slide_in(next_btn, 14, 0.32)
	var quest_wrap := get_node_or_null("%QuestCard")
	if quest_wrap:
		Juice.pulse(quest_wrap, 1.02, 0.28)


func _refresh() -> void:
	title_label.text = "剑阁·健身"
	AP.apply_label(title_label, 52, AP.LANTERN_GOLD)
	subtitle.text = "守卫剑阁"
	AP.apply_label(subtitle, 16, AP.MIST_TEAL.lightened(0.22))
	var action: Dictionary = GameState.next_action()
	quest_title.text = "下一步 · %s" % str(action.get("title", ""))
	quest_detail.text = str(action.get("detail", ""))
	next_btn.text = str(action.get("cta", "下一步"))

	var has_resume := GameState.has_resume()
	continue_btn.visible = has_resume
	if has_resume:
		var resume := GameState.resume_target()
		var resume_label := resume
		match resume:
			"td":
				resume_label = "塔防"
			"explore":
				resume_label = "探索"
			"arena":
				resume_label = "演武"
			"tower":
				resume_label = "爬塔"
		continue_btn.text = "续关 · %s" % resume_label
		# When resume exists, primary next is also resume — hide duplicate continue.
		next_btn.visible = str(action.get("id", "")) != "resume"
	else:
		next_btn.visible = true

	# TD always available as secondary path when next isn't TD.
	new_td_btn.visible = str(action.get("mode", "")) != "td" or has_resume
	new_td_btn.text = "新局 · 塔防"

	_apply_mode_gate(new_explore_btn, "explore", "探索 · 搜打撤")
	_apply_mode_gate(knowledge_btn, "knowledge", "知识本" + (" ✦" if GameState.can_morning_quiz() else ""))
	_apply_mode_gate(_idle_btn, "idle", "花名册")
	_apply_mode_gate(_tower_btn, "tower", "爬塔")
	_apply_mode_gate(_arena_btn, "arena", "演武")
	# Hide MoreRow entirely when both tower/arena locked — less toolbox chrome.
	var more := get_node_or_null("VBox/MoreRow") as Control
	if more and _tower_btn and _arena_btn:
		more.visible = GameState.is_mode_unlocked("tower") or GameState.is_mode_unlocked("arena")

	var hero_id := GameState.recommended_hero_id()
	var hero: Dictionary = ContentDB.get_unit(hero_id)
	hero_name.text = "推荐出战 · %s · %s" % [
		str(hero.get("name", hero_id)),
		str(hero.get("role", "")),
	]
	_rebuild_hero_bar(hero_id)

	# Compact status — silver/xiuwei only; materials live in Idle.
	status_label.text = "银 %d · 修为 %d" % [GameState.silver_bank, GameState.xiuwei_bank]


func _apply_mode_gate(btn: Button, mode_id: String, label: String) -> void:
	if btn == null:
		return
	var unlocked := GameState.is_mode_unlocked(mode_id)
	# Soft-lock: hide locked secondary modes (knowledge/idle always on).
	if mode_id in ["explore", "tower", "arena"] and not unlocked:
		btn.visible = false
		return
	btn.visible = true
	btn.disabled = not unlocked
	if unlocked:
		btn.text = label
		btn.modulate = Color.WHITE
		btn.tooltip_text = ""
	else:
		btn.text = label
		btn.modulate = Color(0.55, 0.58, 0.56, 0.85)
		btn.tooltip_text = GameState.mode_lock_reason(mode_id)


func _rebuild_hero_bar(highlight_id: String) -> void:
	for c in hero_bar.get_children():
		c.queue_free()
	# Show unlocked heroes (+ one locked teaser) — calmer than full spreadsheet.
	var unlocked_shown := 0
	var locked_teaser_done := false
	for u in ContentDB.unit_list:
		var uid := str(u.get("id", ""))
		var unlocked: bool = uid in GameState.unlocked_units
		if unlocked:
			if unlocked_shown >= 4:
				continue
			unlocked_shown += 1
		else:
			if locked_teaser_done or unlocked_shown == 0:
				continue
			locked_teaser_done = true
		var selected: bool = unlocked and uid == highlight_id
		var wrap := Button.new()
		wrap.custom_minimum_size = Vector2(78, 108)
		wrap.focus_mode = Control.FOCUS_NONE
		wrap.clip_contents = true
		wrap.text = ""
		wrap.disabled = selected or not unlocked
		var card := VF.portrait_card(u, Vector2(82, 110), selected, not unlocked)
		card.position = Vector2(2, 2)
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if not unlocked:
			card.modulate = Color(0.55, 0.58, 0.56, 0.78)
		wrap.add_child(card)
		if unlocked:
			wrap.pressed.connect(func():
				GameState.explore_hero_id = uid
				GameState.persist_meta_keep_checkpoints()
				Juice.play_sfx("tap")
				Juice.pulse(wrap, 1.06, 0.12)
				_refresh()
			)
		hero_bar.add_child(wrap)


func _on_next_action() -> void:
	var action: Dictionary = GameState.next_action()
	var mode := str(action.get("mode", "td"))
	Juice.play_sfx("tap")
	Juice.fade_transition(func():
		if str(action.get("id", "")) == "resume":
			_resume_now()
			return
		match mode:
			"td":
				GameState.go_td(false)
			"explore":
				if GameState.is_mode_unlocked("explore"):
					GameState.go_explore(false)
				else:
					GameState.go_td(false)
			"idle":
				GameState.go_idle()
			"knowledge":
				GameState.go_knowledge()
			"arena":
				if GameState.is_mode_unlocked("arena"):
					GameState.go_arena(false)
				else:
					GameState.go_td(false)
			"tower":
				if GameState.is_mode_unlocked("tower"):
					GameState.go_tower(false)
				else:
					GameState.go_td(false)
			_:
				GameState.go_td(false)
	)


func _resume_now() -> void:
	match GameState.resume_target():
		"td":
			GameState.go_td(true)
		"explore":
			GameState.go_explore(true)
		"arena":
			GameState.go_arena(true)
		"tower":
			GameState.go_tower(true)
		_:
			GameState.go_lobby()


func _on_continue() -> void:
	Juice.play_sfx("tap")
	Juice.fade_transition(func(): _resume_now())


func _start_mode(mode: String) -> void:
	if mode != "td" and not GameState.is_mode_unlocked(mode):
		Juice.play_sfx("tap")
		quest_detail.text = GameState.mode_lock_reason(mode)
		Juice.pulse(quest_detail, 1.04, 0.15)
		return
	Juice.play_sfx("tap")
	Juice.fade_transition(func():
		if mode == "td":
			GameState.go_td(false)
		else:
			GameState.go_explore(false)
	)


func _toggle_settings() -> void:
	settings_panel.visible = not settings_panel.visible


func _build_settings() -> void:
	var box: VBoxContainer = %SettingsBox
	for c in box.get_children():
		if c.name.begins_with("Row"):
			c.queue_free()
	_add_slider(box, "主音量", SettingsManager.master_volume, func(v):
		SettingsManager.set_master(v)
		GameState.persist_meta_keep_checkpoints()
	)
	_add_slider(box, "音效", SettingsManager.sfx_volume, func(v):
		SettingsManager.set_sfx(v)
		GameState.persist_meta_keep_checkpoints()
	)
	_add_slider(box, "音乐", SettingsManager.music_volume, func(v):
		SettingsManager.set_music(v)
		GameState.persist_meta_keep_checkpoints()
	)
	var rating := Label.new()
	rating.name = "Row_Rating"
	rating.text = "内容分级：17+（明确成年造型）"
	AP.apply_label(rating, 14, Color(0.72, 0.58, 0.42, 1))
	box.add_child(rating)


func _add_slider(parent: VBoxContainer, label: String, initial: float, cb: Callable) -> void:
	var row := HBoxContainer.new()
	row.name = "Row_" + label
	var lbl := Label.new()
	lbl.text = label
	lbl.custom_minimum_size = Vector2(88, 0)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value = initial
	slider.value_changed.connect(func(v): cb.call(float(v)))
	row.add_child(lbl)
	row.add_child(slider)
	parent.add_child(row)
