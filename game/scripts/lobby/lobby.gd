extends Control
## Main hub: Idle celebrity meta + mode select — ink-mist atmosphere.

const AP := preload("res://scripts/util/art_palette.gd")
const Atmo := preload("res://scripts/util/atmosphere.gd")
const VF := preload("res://scripts/util/visual_factory.gd")

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
@onready var decor: Control = %Decor


func _ready() -> void:
	Atmo.attach_full_bg(self, "night")
	var old_bg := get_node_or_null("Bg")
	if old_bg:
		old_bg.visible = false
	var accent := get_node_or_null("Accent")
	if accent:
		accent.visible = false
	title_label.text = "剑阁·大厅"
	AP.apply_label(title_label, 44, AP.LANTERN_GOLD)
	subtitle.text = "TD · Idle · 搜打撤 · 演武 · 爬塔"
	AP.apply_label(subtitle, 15, AP.MIST_TEAL.lightened(0.22))
	# M4/M5: Arena + Tower live (same auto-combat ring as explore).
	var idle_btn := get_node_or_null("%IdleStubBtn") as Button
	var tower_btn := get_node_or_null("%TowerStubBtn") as Button
	var arena_btn := get_node_or_null("%ArenaStubBtn") as Button
	if idle_btn:
		idle_btn.disabled = false
		idle_btn.text = "名人花名册 · Idle"
		idle_btn.theme_type_variation = &"ButtonPrimary"
		idle_btn.tooltip_text = "挂机银两/修为/材料 · 训练槽喂 TD"
		idle_btn.pressed.connect(func():
			Juice.play_sfx("tap")
			Juice.fade_transition(func(): GameState.go_idle())
		)
	if arena_btn:
		arena_btn.disabled = false
		arena_btn.text = "演武场 · 生存练功"
		arena_btn.theme_type_variation = &"ButtonPrimary"
		arena_btn.tooltip_text = "敌人 ramp · 随时下场 · 修为/熟练度"
		arena_btn.pressed.connect(func():
			Juice.play_sfx("tap")
			Juice.fade_transition(func(): GameState.go_arena(false))
		)
	if tower_btn:
		tower_btn.disabled = false
		tower_btn.text = "爬塔 · 纵向进度"
		tower_btn.theme_type_variation = &"ButtonPrimary"
		tower_btn.tooltip_text = "清层进阶 · 层间存档 · 专属装备"
		tower_btn.pressed.connect(func():
			Juice.play_sfx("tap")
			Juice.fade_transition(func(): GameState.go_tower(false))
		)
	new_explore_btn.text = "新局 · 探索搜打撤"
	new_explore_btn.tooltip_text = "荒山节点：搜材料 → 打遭遇 → 撤据点结算"
	AP.apply_richtext(roster_panel, 15)
	AP.apply_richtext(gear_panel, 14)
	AP.apply_label(status_label, 13, Color(0.65, 0.72, 0.64, 1))
	continue_btn.theme_type_variation = &"ButtonPrimary"
	new_td_btn.theme_type_variation = &"ButtonPrimary"
	new_explore_btn.theme_type_variation = &"ButtonPrimary"
	continue_btn.pressed.connect(_on_continue)
	new_td_btn.pressed.connect(func(): _start_mode("td"))
	new_explore_btn.pressed.connect(func(): _start_mode("explore"))
	knowledge_btn.pressed.connect(func():
		Juice.play_sfx("tap")
		Juice.fade_transition(func(): GameState.go_knowledge())
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


func _refresh() -> void:
	var has_resume := GameState.has_resume()
	continue_btn.visible = has_resume
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
	var unlocked := GameState.unlocked_units.size()
	var total := ContentDB.unit_list.size()
	var seen := GameState.knowledge_seen.size()
	var total_k := ContentDB.knowledge_list.size()
	var review := GameState.knowledge_due_ids().size()
	if seen >= 5 and "gear_jade_token" not in GameState.gear_unlocked:
		GameState.unlock_gear("gear_jade_token")
	if GameState.owns_content_pack("demo_mountain") and ContentDB.gear.has("gear_demo_trail_charm"):
		GameState.unlock_gear("gear_demo_trail_charm")
	var pending := GameState.pending_claim_totals()
	roster_panel.clear()
	roster_panel.append_text("[b]名人花名册[/b]  %d/%d\n" % [unlocked, total])
	if pending.silver + pending.xiuwei + pending.materials > 0:
		roster_panel.append_text("[color=#e6c15a]Idle 待领[/color] 银%d 修为%d 材料%d\n" % [
			pending.silver, pending.xiuwei, pending.materials
		])
	for u in ContentDB.unit_list:
		var uid := str(u.get("id", ""))
		var is_on: bool = uid in GameState.unlocked_units
		var frags := int(GameState.unit_fragments.get(uid, 0))
		var need := int(u.get("unlock_fragments", 3))
		var mastery := GameState.effective_mastery(uid)
		var mark := "★" if uid == GameState.explore_hero_id else "·"
		if is_on:
			var bar := _frag_bar(frags)
			roster_panel.append_text("%s [color=#e6c15a]%s[/color] %s  熟练%d  %s\n" % [
				mark, u.get("name", uid), u.get("role", "?"), mastery, bar
			])
		else:
			roster_panel.append_text("· [color=#5a6a68]%s[/color] 碎片%d/%d\n" % [
				u.get("historical_tag", u.get("name", uid)), frags, need
			])
	gear_panel.clear()
	gear_panel.append_text("[b]装备[/b]  器 / 衣 / 饰\n")
	var slot_names := ["器", "衣", "饰"]
	for i in 3:
		var gid: String = GameState.gear_equipped[i] if i < GameState.gear_equipped.size() else ""
		var label := "空"
		if gid != "":
			label = ContentDB.get_gear(gid).get("name", gid)
		gear_panel.append_text("%s：%s\n" % [slot_names[i], label])
	if not GameState.gear_unlocked.is_empty():
		gear_panel.append_text("\n[color=#5a9a90]可装备：[/color]\n")
		for gid in GameState.gear_unlocked:
			var g: Dictionary = ContentDB.get_gear(gid)
			var equipped: bool = gid in GameState.gear_equipped
			var exclusive := " [专]" if bool(g.get("exclusive", false)) else ""
			gear_panel.append_text("%s %s%s — %s\n" % [
				"✓" if equipped else "○", g.get("name", gid), exclusive, g.get("bonus", "")
			])
	status_label.text = "知识 %d/%d · 待复 %d · 银 %d · 修为 %d · 材料 %s · TD%d · 探%d · 演武%d · 塔%d · 包[%s]" % [
		seen, total_k, review, GameState.silver_bank, GameState.xiuwei_bank, GameState.materials_summary(),
		GameState.total_td_clears, GameState.total_explore_clears,
		GameState.total_arena_runs, GameState.tower_floor_cleared,
		",".join(ContentDB.loaded_pack_ids),
	]
	knowledge_btn.text = "知识本 / 晨课" + (" ✦" if GameState.can_morning_quiz() else "")
	if review > 0:
		knowledge_btn.text += " ·复%d" % review
	_rebuild_hero_bar()
	_rebuild_gear_buttons()


func _frag_bar(frags: int) -> String:
	var filled := mini(frags, 3)
	return "◆".repeat(filled) + "◇".repeat(3 - filled)


func _rebuild_hero_bar() -> void:
	for c in hero_bar.get_children():
		c.queue_free()
	# Full roster side-by-side (locked cards dimmed) so portrait set reads as one plate.
	for u in ContentDB.unit_list:
		var uid := str(u.get("id", ""))
		var unlocked: bool = uid in GameState.unlocked_units
		var selected: bool = unlocked and uid == GameState.explore_hero_id
		var wrap := Button.new()
		wrap.custom_minimum_size = Vector2(84, 118)
		wrap.focus_mode = Control.FOCUS_NONE
		wrap.clip_contents = true
		wrap.text = ""
		wrap.disabled = selected or not unlocked
		var card := VF.portrait_card(u, Vector2(88, 120), selected)
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
				_refresh()
			)
		hero_bar.add_child(wrap)


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
	Juice.fade_transition(func():
		match GameState.resume_target():
			"td":
				GameState.go_td(true)
			"explore":
				GameState.go_explore(true)
			"arena":
				GameState.go_arena(true)
			"tower":
				GameState.go_tower(true)
	)


func _start_mode(mode: String) -> void:
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
