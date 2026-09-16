extends Control
## Entry title: tap-through to lobby, settings, optional continue shortcut.

@onready var title: Label = %Title
@onready var tagline: Label = %Tagline
@onready var continue_btn: Button = %ContinueBtn
@onready var start_btn: Button = %StartBtn
@onready var settings_btn: Button = %SettingsBtn
@onready var version_label: Label = %VersionLabel
@onready var settings_panel: PanelContainer = %SettingsPanel

var _pulse_t: float = 0.0


func _ready() -> void:
	title.text = "剑阁·健身"
	tagline.text = "守卫剑阁 · 栈道夜行 · 真知识"
	version_label.text = "v0.2 可玩第一章"
	continue_btn.visible = GameState.has_resume()
	continue_btn.pressed.connect(_on_continue)
	start_btn.pressed.connect(_on_start)
	settings_btn.pressed.connect(_toggle_settings)
	settings_panel.visible = false
	_build_settings_sliders()
	Juice.play_sfx("tap")


func _process(delta: float) -> void:
	_pulse_t += delta
	title.modulate = Color(1, 1, 1, 0.88 + 0.12 * sin(_pulse_t * 2.2))


func _on_continue() -> void:
	Juice.play_sfx("tap")
	Juice.fade_transition(func():
		if GameState.resume_target() == "td":
			GameState.go_td(true)
		elif GameState.resume_target() == "explore":
			GameState.go_explore(true)
		else:
			GameState.go_lobby()
	)


func _on_start() -> void:
	Juice.play_sfx("tap")
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
	var sfx_toggle := CheckBox.new()
	sfx_toggle.text = "音效开关"
	sfx_toggle.button_pressed = SettingsManager.sfx_on
	sfx_toggle.toggled.connect(func(on): SettingsManager.set_sfx_enabled(on))
	box.add_child(sfx_toggle)


func _add_slider(parent: VBoxContainer, label: String, initial: float, cb: Callable) -> void:
	var row := HBoxContainer.new()
	row.name = "Row_" + label
	var lbl := Label.new()
	lbl.text = label
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
