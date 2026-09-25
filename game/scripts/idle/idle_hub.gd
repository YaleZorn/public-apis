extends Control
## Idle celebrity roster hub: claim offline accrual, train slots, collection progress.

const AP := preload("res://scripts/util/art_palette.gd")
const Atmo := preload("res://scripts/util/atmosphere.gd")
const VF := preload("res://scripts/util/visual_factory.gd")

@onready var title_label: Label = %TitleLabel
@onready var subtitle: Label = %Subtitle
@onready var rates_label: Label = %RatesLabel
@onready var pending_label: RichTextLabel = %PendingLabel
@onready var claim_btn: Button = %ClaimBtn
@onready var bank_label: Label = %BankLabel
@onready var roster_scroll: ScrollContainer = %RosterScroll
@onready var roster_list: VBoxContainer = %RosterList
@onready var detail_panel: RichTextLabel = %DetailPanel
@onready var train_box: VBoxContainer = %TrainBox
@onready var back_btn: Button = %BackBtn
@onready var status_label: Label = %StatusLabel
@onready var decor: Control = %Decor

var _selected_id: String = ""
var _assign_slot: int = -1


func _ready() -> void:
	Atmo.attach_full_bg(self, "night")
	var old_bg := get_node_or_null("Bg")
	if old_bg:
		old_bg.visible = false
	title_label.text = str(ContentDB.idle_cfg.get("title", "名人花名册"))
	AP.apply_label(title_label, 36, AP.LANTERN_GOLD)
	subtitle.text = str(ContentDB.idle_cfg.get("subtitle", "挂机练功"))
	AP.apply_label(subtitle, 14, AP.MIST_TEAL.lightened(0.22))
	AP.apply_label(rates_label, 13, Color(0.7, 0.78, 0.72, 1))
	AP.apply_richtext(pending_label, 15)
	AP.apply_label(bank_label, 14, AP.PAPER_INK.lightened(0.1))
	AP.apply_richtext(detail_panel, 14)
	AP.apply_label(status_label, 12, Color(0.62, 0.7, 0.64, 1))
	claim_btn.theme_type_variation = &"ButtonPrimary"
	claim_btn.pressed.connect(_on_claim)
	back_btn.pressed.connect(func():
		Juice.play_sfx("tap")
		if GameState.intro_stage == 1:
			GameState.advance_intro(2)
		Juice.fade_transition(func(): GameState.go_lobby())
	)
	Atmo.build_lobby_decor(decor)
	GameState.refresh_idle_accrual()
	if GameState.last_mvp_unit_id != "" and GameState.last_mvp_unit_id in GameState.unlocked_units:
		_selected_id = GameState.last_mvp_unit_id
	elif _selected_id == "" and not GameState.unlocked_units.is_empty():
		_selected_id = str(GameState.unlocked_units[0])
	_refresh()
	if GameState.intro_stage == 1:
		var mvp_name := str(ContentDB.get_unit(_selected_id).get("name", "弟子"))
		status_label.text = "%s 刚立功 — 领取微量银两，看他在修炼。" % mvp_name
		subtitle.text = "欲望对象 · 具名班子"
		Juice.pulse(claim_btn, 1.06, 0.35)
	GameState.meta_changed.connect(_refresh)


func _refresh() -> void:
	var rates := GameState.idle_rates_per_hour()
	var cap := float(ContentDB.idle_cfg.get("offline_cap_hours", 8.0))
	rates_label.text = "时速 银两 %.0f · 修为 %.0f · 材料草稿 %.0f  （离线上限 %.0f 时）" % [
		rates.silver, rates.xiuwei, rates.materials, cap
	]
	var pending := GameState.pending_claim_totals()
	pending_label.clear()
	pending_label.append_text("[b]待领取[/b]\n")
	pending_label.append_text("银两 [color=#e6c15a]%d[/color]\n" % pending.silver)
	pending_label.append_text("修为 [color=#7ec8c0]%d[/color]\n" % pending.xiuwei)
	pending_label.append_text("材料草稿 [color=#c4a574]%d[/color]\n" % pending.materials)
	var can: bool = int(pending.silver) > 0 or int(pending.xiuwei) > 0 or int(pending.materials) > 0
	claim_btn.disabled = not can
	claim_btn.text = "领取挂机收益" if can else "暂无收益（离开后再来）"
	bank_label.text = "仓：银两 %d · 修为 %d · 材料草稿 %d" % [
		GameState.silver_bank, GameState.xiuwei_bank, GameState.materials_draft
	]
	_rebuild_roster()
	_rebuild_training()
	_rebuild_detail()
	var unlocked := GameState.unlocked_units.size()
	var total := ContentDB.unit_list.size()
	status_label.text = "收集 %d/%d · 训练槽 %d · 无 IAP 离线" % [
		unlocked, total, GameState.training_slots.size()
	]


func _rebuild_roster() -> void:
	for c in roster_list.get_children():
		c.queue_free()
	for u in ContentDB.unit_list:
		var uid := str(u.get("id", ""))
		var unlocked: bool = uid in GameState.unlocked_units
		var holder := HBoxContainer.new()
		holder.add_theme_constant_override("separation", 8)
		holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var pwrap := Control.new()
		pwrap.custom_minimum_size = Vector2(56, 68)
		var card := VF.portrait_card(u, Vector2(52, 64), uid == _selected_id)
		if not unlocked:
			card.modulate = Color(0.45, 0.48, 0.46, 0.75)
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.position = Vector2(2, 2)
		pwrap.add_child(card)
		holder.add_child(pwrap)
		var row := Button.new()
		row.custom_minimum_size = Vector2(0, 68)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.focus_mode = Control.FOCUS_NONE
		var tag := str(u.get("historical_tag", u.get("faction", "")))
		var frags := int(GameState.unit_fragments.get(uid, 0))
		var need := int(u.get("unlock_fragments", 3))
		var lvl := int(GameState.training_level.get(uid, 0))
		var mast := GameState.effective_mastery(uid)
		if unlocked:
			row.text = "%s · %s\n练%d 熟练%d" % [u.get("name", uid), tag, lvl, mast]
		else:
			row.text = "？？？ · %s\n碎片 %d/%d" % [tag, frags, need]
			row.modulate = Color(0.7, 0.72, 0.7, 0.85)
		if uid == _selected_id:
			row.theme_type_variation = &"ButtonPrimary"
		row.pressed.connect(func():
			_selected_id = uid
			_assign_slot = -1
			Juice.play_sfx("tap")
			_refresh()
		)
		holder.add_child(row)
		roster_list.add_child(holder)


func _rebuild_training() -> void:
	for c in train_box.get_children():
		c.queue_free()
	var hdr := Label.new()
	hdr.text = "训练槽（耗银两指派 · 周期完成抬熟练 / 解锁权重）"
	AP.apply_label(hdr, 13, AP.MIST_TEAL.lightened(0.15))
	train_box.add_child(hdr)
	for i in GameState.training_slots.size():
		var slot: Dictionary = GameState.training_slots[i]
		var uid := str(slot.get("unit_id", ""))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var info := Label.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if uid == "":
			info.text = "槽 %d · 空" % (i + 1)
		else:
			var u: Dictionary = ContentDB.get_unit(uid)
			var pct := int(GameState.training_progress(i) * 100.0)
			info.text = "槽 %d · %s  %d%%" % [i + 1, u.get("name", uid), pct]
		AP.apply_label(info, 14, AP.PAPER_INK)
		row.add_child(info)
		var assign_btn := Button.new()
		assign_btn.text = "指派所选" if uid == "" else "更换"
		assign_btn.custom_minimum_size = Vector2(100, 40)
		assign_btn.pressed.connect(func():
			_try_assign(i)
		)
		row.add_child(assign_btn)
		if uid != "":
			var clear_btn := Button.new()
			clear_btn.text = "撤下"
			clear_btn.custom_minimum_size = Vector2(72, 40)
			clear_btn.pressed.connect(func():
				GameState.assign_training(i, "")
				Juice.play_sfx("tap")
				_refresh()
			)
			row.add_child(clear_btn)
		train_box.add_child(row)


func _try_assign(slot_index: int) -> void:
	if _selected_id == "" or _selected_id not in GameState.unlocked_units:
		status_label.text = "请先选择已解锁名人"
		Juice.play_sfx("tap")
		return
	var cost := int(ContentDB.get_unit(_selected_id).get("idle", {}).get("train_cost_silver", 40))
	if GameState.silver_bank < cost:
		status_label.text = "银两不足（需 %d）" % cost
		Juice.play_sfx("tap")
		return
	if GameState.assign_training(slot_index, _selected_id):
		Juice.play_sfx("train")
		Juice.pulse(train_box, 1.04, 0.14)
		status_label.text = "%s 入训练槽 %d（-%d 银两）" % [
			ContentDB.get_unit(_selected_id).get("name", _selected_id), slot_index + 1, cost
		]
	else:
		status_label.text = "指派失败（或已在其他槽）"
		Juice.play_sfx("tap")
	_refresh()


func _rebuild_detail() -> void:
	detail_panel.clear()
	if _selected_id == "":
		detail_panel.append_text("点选花名册中的名人查看详情。")
		return
	var u: Dictionary = ContentDB.get_unit(_selected_id)
	var unlocked: bool = _selected_id in GameState.unlocked_units
	detail_panel.append_text("[b]%s[/b]\n" % u.get("name", _selected_id))
	detail_panel.append_text("[color=#7ec8c0]%s[/color] · %s\n" % [
		u.get("historical_tag", ""), u.get("faction", "")
	])
	detail_panel.append_text("定位：%s\n" % u.get("role", "?"))
	detail_panel.append_text("%s\n\n" % u.get("blurb", ""))
	if unlocked:
		detail_panel.append_text("训练等级 %d · 有效熟练 %d\n" % [
			int(GameState.training_level.get(_selected_id, 0)),
			GameState.effective_mastery(_selected_id),
		])
		detail_panel.append_text("TD 被动权重：攻击 +%d%%（熟练）\n" % (
			GameState.effective_mastery(_selected_id) * 2
		))
		var idle: Dictionary = u.get("idle", {})
		detail_panel.append_text("挂机贡献/时：银%.0f 修为%.0f 材料%.0f\n" % [
			float(idle.get("silver_per_hour", 0)),
			float(idle.get("xiuwei_per_hour", 0)),
			float(idle.get("material_per_hour", 0)),
		])
		detail_panel.append_text("指派训练：%d 银两 / %.0f 分钟\n" % [
			int(idle.get("train_cost_silver", 40)),
			float(idle.get("train_minutes", 5)),
		])
		detail_panel.append_text("\n[color=#e6c15a]可放入剑阁 TD 编队。[/color]")
	else:
		var frags := int(GameState.unit_fragments.get(_selected_id, 0))
		var need := int(u.get("unlock_fragments", 3))
		detail_panel.append_text("未解锁 · 碎片 %d/%d\n" % [frags, need])
		detail_panel.append_text("训练其他名人有机会掉落碎片。")


func _on_claim() -> void:
	var got := GameState.claim_idle()
	Juice.play_sfx("claim")
	Juice.pulse(claim_btn, 1.12, 0.18)
	Juice.flash_modulate(claim_btn, Color(1.25, 1.15, 0.85, 1.0), 0.2)
	var anchor := claim_btn.global_position + claim_btn.size * 0.5
	if got.silver > 0:
		Juice.float_number(anchor + Vector2(-40, -20), "+银%d" % got.silver, Color(0.95, 0.82, 0.45))
	if got.xiuwei > 0:
		Juice.float_number(anchor + Vector2(20, -36), "+修为%d" % got.xiuwei, Color(0.65, 0.88, 0.75))
	if got.materials > 0:
		Juice.float_number(anchor + Vector2(-10, -52), "+材%d" % got.materials, Color(0.75, 0.82, 0.55))
	status_label.text = "领取 +银两%d · +修为%d · +材料%d" % [
		got.silver, got.xiuwei, got.materials
	]
	_refresh()
