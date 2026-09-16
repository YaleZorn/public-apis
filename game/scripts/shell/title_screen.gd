extends Control
## Entry title: tap-through to lobby, settings, optional continue shortcut.

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
	title.text = "剑阁·健身"
	tagline.text = "守卫剑阁 · 栈道夜行 · 真知识"
	version_label.text = "v0.2 可玩第一章"
	continue_btn.visible = GameState.has_resume()
	continue_btn.pressed.connect(_on_continue)
	start_btn.pressed.connect(_on_start)
	settings_btn.pressed.connect(_toggle_settings)
	settings_panel.visible = false
	_build_settings_sliders()
	_build_decor()
	Juice.play_sfx("tap")


func _process(delta: float) -> void:
	_pulse_t += delta
	title.modulate = Color(1, 1, 1, 0.88 + 0.12 * sin(_pulse_t * 2.2))


func _build_decor() -> void:
	for c in decor.get_children():
		c.queue_free()
	# Stylized mountain / gate silhouette — temporary art language.
	var peaks := [
		[Vector2(40, 280), Vector2(220, 220), Color(0.1, 0.16, 0.13, 0.85)],
		[Vector2(180, 300), Vector2(280, 260), Color(0.12, 0.18, 0.14, 0.8)],
		[Vector2(420, 270), Vector2(240, 240), Color(0.09, 0.15, 0.12, 0.9)],
	]
	for p in peaks:
		var tri := ColorRect.new()
		tri.position = p[0]
		tri.size = p[1]
		tri.color = p[2]
		tri.rotation = deg_to_rad(-12)
		decor.add_child(tri)
	var gate := ColorRect.new()
	gate.position = Vector2(280, 380)
	gate.size = Vector2(160, 120)
	gate.color = Color(0.42, 0.34, 0.2, 0.75)
	decor.add_child(gate)
	var arch := ColorRect.new()
	arch.position = Vector2(320, 400)
	arch.size = Vector2(80, 90)
	arch.color = Color(0.05, 0.08, 0.07, 0.9)
	decor.add_child(arch)
	var moon := ColorRect.new()
	moon.position = Vector2(520, 90)
	moon.size = Vector2(48, 48)
	moon.color = Color(0.9, 0.82, 0.55, 0.55)
	decor.add_child(moon)


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
	var sfx_toggle := CheckButton.new()
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
