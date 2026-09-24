extends Control
## Entry title: brand-first portrait hero, mist atmosphere, tap-through to lobby.

const AP := preload("res://scripts/util/art_palette.gd")
const Atmo := preload("res://scripts/util/atmosphere.gd")

@onready var title: Label = %Title
@onready var tagline: Label = %Tagline
@onready var continue_btn: Button = %ContinueBtn
@onready var start_btn: Button = %StartBtn
@onready var settings_btn: Button = %SettingsBtn
@onready var version_label: Label = %VersionLabel
@onready var settings_panel: PanelContainer = %SettingsPanel
@onready var decor: Control = %Decor

var _pulse_t: float = 0.0


func _ready() -> void:
	Atmo.attach_full_bg(self, "night")
	# Hide flat ColorRect backgrounds if present
	var old_bg := get_node_or_null("Bg")
	if old_bg:
		old_bg.visible = false
	var at := get_node_or_null("AccentTop")
	if at:
		at.visible = false
	var ab := get_node_or_null("AccentBottom")
	if ab:
		ab.visible = false
	title.text = "剑阁·健身"
	AP.apply_label(title, 64, AP.LANTERN_GOLD)
	tagline.text = "守卫剑阁 · 栈道夜行 · 真知识"
	AP.apply_label(tagline, 18, AP.MIST_TEAL.lightened(0.28))
	AP.apply_label(version_label, 12, Color(0.50, 0.58, 0.52, 0.85))
	var ver := str(ProjectSettings.get_setting("application/config/version", "0.11.0"))
	version_label.text = "v%s" % ver
	continue_btn.visible = GameState.has_resume()
	continue_btn.theme_type_variation = &"ButtonPrimary"
	start_btn.theme_type_variation = &"ButtonPrimary"
	# First session: brand CTA toward first TD, not a toolbox lobby dump.
	if not GameState.has_resume() and GameState.td_best_wave <= 0 and GameState.total_td_clears <= 0:
		start_btn.text = "踏上栈道"
		tagline.text = "守卫剑阁 · 先守一波"
	elif GameState.has_resume():
		start_btn.text = "进入大厅"
	else:
		start_btn.text = "进入大厅"
	continue_btn.pressed.connect(_on_continue)
	start_btn.pressed.connect(_on_start)
	settings_btn.pressed.connect(_toggle_settings)
	settings_panel.visible = false
	_build_settings_sliders()
	Atmo.build_title_decor(decor)
	await get_tree().process_frame
	title.pivot_offset = title.size * 0.5
	Juice.slide_in(start_btn, 18, 0.35)
	Juice.start_title_music()
	Juice.play_sfx("tap")


func _process(delta: float) -> void:
	_pulse_t += delta
	title.modulate = Color(1, 1, 1, 0.90 + 0.10 * sin(_pulse_t * 2.0))
	title.scale = Vector2.ONE * (1.0 + 0.016 * sin(_pulse_t * 1.3))


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
			_:
				GameState.go_lobby()
	)


func _on_start() -> void:
	Juice.play_sfx("tap")
	# Brand promise: first open lands in lobby with one clear 「下一步」 to TD.
	Juice.fade_transition(func(): GameState.go_lobby())


func _toggle_settings() -> void:
	settings_panel.visible = not settings_panel.visible
	Juice.play_sfx("tap")


func _build_settings_sliders() -> void:
	var box: VBoxContainer = %SettingsBox
	for c in box.get_children():
		if c.name.begins_with("Row"):
			c.queue_free()
	_add_slider(box, "主音量", SettingsManager.master_volume, func(v): SettingsManager.set_master(v))
	_add_slider(box, "音效", SettingsManager.sfx_volume, func(v): SettingsManager.set_sfx(v))
	_add_slider(box, "音乐", SettingsManager.music_volume, func(v): SettingsManager.set_music(v))
	var sfx_toggle := CheckButton.new()
	sfx_toggle.text = "音效开关"
	sfx_toggle.button_pressed = SettingsManager.sfx_on
	sfx_toggle.toggled.connect(func(on): SettingsManager.set_sfx_enabled(on))
	box.add_child(sfx_toggle)
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
	AP.apply_label(lbl, 16, AP.PAPER_DIM)
	lbl.custom_minimum_size = Vector2(100, 0)
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
