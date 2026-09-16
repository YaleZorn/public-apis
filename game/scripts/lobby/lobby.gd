extends Control
## Main hub: mode select, roster/gear meta, continue shortcut.

@onready var title_label: Label = %TitleLabel
@onready var subtitle: Label = %Subtitle
@onready var continue_btn: Button = %ContinueBtn
@onready var new_td_btn: Button = %NewTdBtn
@onready var new_explore_btn: Button = %NewExploreBtn
@onready var knowledge_btn: Button = %KnowledgeBtn
@onready var roster_panel: RichTextLabel = %RosterPanel
@onready var gear_panel: RichTextLabel = %GearPanel
@onready var status_label: Label = %StatusLabel
@onready var hero_bar: HBoxContainer = %HeroBar
@onready var settings_btn: Button = %SettingsBtn
@onready var settings_panel: PanelContainer = %SettingsPanel


func _ready() -> void:
	title_label.text = "剑阁大厅"
	subtitle.text = ContentDB.waves_cfg.get("chapter_title", "守卫剑阁 · 栈道夜行")
	continue_btn.pressed.connect(_on_continue)
	new_td_btn.pressed.connect(func(): _start_mode("td"))
	new_explore_btn.pressed.connect(func(): _start_mode("explore"))
	knowledge_btn.pressed.connect(func(): GameState.go_knowledge())
	settings_btn.pressed.connect(_toggle_settings)
	settings_panel.visible = false
	_build_settings()
	_refresh()
	GameState.meta_changed.connect(_refresh)
	GameState.checkpoint_changed.connect(_refresh)


func _refresh() -> void:
	var has_resume := GameState.has_resume()
	continue_btn.visible = has_resume
	continue_btn.text = "续关 · %s" % ("塔防" if GameState.resume_target() == "td" else "探索")
	var unlocked := GameState.unlocked_units.size()
	var seen := GameState.knowledge_seen.size()
	var review := GameState.knowledge_review_queue.size()
	if seen >= 5 and "gear_jade_token" not in GameState.gear_unlocked:
		GameState.unlock_gear("gear_jade_token")
	roster_panel.clear()
	roster_panel.append_text("[b]阵容[/b]  %d/6 已解锁\n" % unlocked)
	for uid in GameState.unlocked_units:
		var u: Dictionary = ContentDB.get_unit(uid)
		var frags := int(GameState.unit_fragments.get(uid, 0))
		var mastery := int(GameState.hero_mastery.get(uid, 0))
		var mark := "★" if uid == GameState.explore_hero_id else "·"
		var bar := _frag_bar(frags)
		roster_panel.append_text("%s [color=#d4c48a]%s[/color] %s  熟练%d  %s\n" % [
			mark, u.get("name", uid), u.get("role", "?"), mastery, bar
		])
	gear_panel.clear()
	gear_panel.append_text("[b]装备[/b]  器 / 衣 / 饰\n")
	var slot_names := ["器", "衣", "饰"]
	for i in 3:
		var gid: String = GameState.gear_equipped[i] if i < GameState.gear_equipped.size() else ""
		var label := "空"
		if gid != "":
			label = ContentDB.get_gear(gid).get("name", gid)
		elif i < GameState.gear_unlocked.size():
			pass
		gear_panel.append_text("%s：%s\n" % [slot_names[i], label])
	if not GameState.gear_unlocked.is_empty():
		gear_panel.append_text("\n[color=#8ab88a]可装备：[/color]\n")
		for gid in GameState.gear_unlocked:
			var g: Dictionary = ContentDB.get_gear(gid)
			var equipped: bool = gid in GameState.gear_equipped
			gear_panel.append_text("%s %s — %s\n" % [
				"✓" if equipped else "○", g.get("name", gid), g.get("bonus", "")
			])
	status_label.text = "知识 %d/15 · 待复习 %d · 银两仓 %d · TD通关 %d · 探索 %d%s" % [
		seen, review, GameState.silver_bank,
		GameState.total_td_clears, GameState.total_explore_clears,
		" · 晨课 buff" if GameState.morning_buff_active else "",
	]
	knowledge_btn.text = "知识本 / 晨课" + (" ✦" if GameState.can_morning_quiz() else "")
	_rebuild_hero_bar()
	_rebuild_gear_buttons()


func _frag_bar(frags: int) -> String:
	var filled := mini(frags, 3)
	return "◆".repeat(filled) + "◇".repeat(3 - filled)


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
			Juice.play_sfx("tap")
			_refresh()
		)
		hero_bar.add_child(b)


func _rebuild_gear_buttons() -> void:
	var bar: HBoxContainer = %GearBar
	for c in bar.get_children():
		c.queue_free()
	for gid in GameState.gear_unlocked:
		var g: Dictionary = ContentDB.get_gear(gid)
		var b := Button.new()
		b.text = str(g.get("name", gid))
		b.custom_minimum_size = Vector2(0, 36)
		if gid in GameState.gear_equipped:
			b.disabled = true
		b.pressed.connect(func():
			var slot := int(g.get("slot", 0))
			GameState.equip_gear(slot, gid)
			Juice.play_sfx("place")
			_refresh()
		)
		bar.add_child(b)


func _on_continue() -> void:
	Juice.play_sfx("tap")
	if GameState.resume_target() == "td":
		GameState.go_td(true)
	elif GameState.resume_target() == "explore":
		GameState.go_explore(true)


func _start_mode(mode: String) -> void:
	Juice.play_sfx("tap")
	if mode == "td":
		GameState.go_td(false)
	else:
		GameState.go_explore(false)


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
