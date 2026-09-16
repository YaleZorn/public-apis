extends Node
## Lightweight juice: procedural SFX, float numbers, screen shake, scene fades.

const FloatingNumberScene := preload("res://scenes/ui/floating_number.tscn")

var _sfx_root: Node
var _players: Array[AudioStreamPlayer] = []
var _streams: Dictionary = {}
var _shake_target: Node = null
var _shake_strength: float = 0.0
var _shake_decay: float = 8.0
var _shake_offset: Vector2 = Vector2.ZERO
var _fade_layer: CanvasLayer
var _fade_rect: ColorRect


func _ready() -> void:
	_sfx_root = Node.new()
	_sfx_root.name = "SfxRoot"
	add_child(_sfx_root)
	_build_streams()
	_setup_fade()


func _process(delta: float) -> void:
	if _shake_strength > 0.01 and _shake_target != null and is_instance_valid(_shake_target):
		_shake_strength = maxf(0.0, _shake_strength - _shake_decay * delta)
		_shake_offset = Vector2(
			randf_range(-_shake_strength, _shake_strength),
			randf_range(-_shake_strength, _shake_strength)
		)
		if _shake_target is Control:
			(_shake_target as Control).position = (_shake_target as Control).get_meta("_base_pos", (_shake_target as Control).position) + _shake_offset
	else:
		_shake_strength = 0.0
		if _shake_target != null and is_instance_valid(_shake_target) and _shake_target is Control:
			var c := _shake_target as Control
			if c.has_meta("_base_pos"):
				c.position = c.get_meta("_base_pos")


func play_sfx(kind: String) -> void:
	if not SettingsManager.sfx_enabled():
		return
	var stream: AudioStream = _streams.get(kind, _streams.get("tap"))
	var player := _borrow_player()
	player.stream = stream
	player.volume_db = linear_to_db(SettingsManager.sfx_volume)
	player.play()


func float_number(at: Vector2, text: String, color: Color = Color(1, 0.92, 0.55)) -> void:
	var layer := get_tree().current_scene
	if layer == null:
		return
	var n: Control = FloatingNumberScene.instantiate()
	layer.add_child(n)
	n.global_position = at
	if n.has_method("setup"):
		n.setup(text, color)


func screen_shake(target: Node, strength: float = 6.0) -> void:
	if target == null:
		return
	_shake_target = target
	if target is Control and not target.has_meta("_base_pos"):
		target.set_meta("_base_pos", (target as Control).position)
	_shake_strength = maxf(_shake_strength, strength)


func fade_transition(callback: Callable, color: Color = Color(0.03, 0.09, 0.08, 1.0), duration: float = 0.32) -> void:
	if _fade_rect == null:
		callback.call()
		return
	_fade_layer.visible = true
	var tw := create_tween()
	tw.tween_property(_fade_rect, "color:a", 1.0, duration * 0.45)
	tw.tween_callback(callback)
	tw.tween_property(_fade_rect, "color:a", 0.0, duration * 0.55)
	tw.tween_callback(func(): _fade_layer.visible = false)


func pulse(node: CanvasItem, scale_up: float = 1.12, duration: float = 0.12) -> void:
	if node == null:
		return
	var base: Vector2 = node.scale
	var tw := create_tween()
	tw.tween_property(node, "scale", base * scale_up, duration * 0.45)
	tw.tween_property(node, "scale", base, duration * 0.55)


func _setup_fade() -> void:
	_fade_layer = CanvasLayer.new()
	_fade_layer.layer = 100
	_fade_layer.visible = false
	add_child(_fade_layer)
	_fade_rect = ColorRect.new()
	_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_rect.color = Color(0.03, 0.09, 0.08, 0.0)
	_fade_layer.add_child(_fade_rect)


func _borrow_player() -> AudioStreamPlayer:
	for p in _players:
		if not p.playing:
			return p
	var player := AudioStreamPlayer.new()
	player.bus = "Master"
	_sfx_root.add_child(player)
	_players.append(player)
	return player


func _build_streams() -> void:
	_streams = {
		"tap": _make_beep(520, 0.05, 0.18),
		"place": _make_beep(330, 0.08, 0.22),
		"recall": _make_beep(260, 0.07, 0.18),
		"hit": _make_beep(180, 0.04, 0.16),
		"kill": _make_beep(440, 0.06, 0.2),
		"wave": _make_beep(220, 0.14, 0.24),
		"win": _make_beep(660, 0.18, 0.26),
		"lose": _make_beep(120, 0.22, 0.24),
		"skill": _make_beep(380, 0.1, 0.22),
		"card": _make_beep(500, 0.07, 0.16),
	}


func _make_beep(hz: float, dur: float, vol: float) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 22050
	wav.stereo = false
	var count := int(wav.mix_rate * dur)
	var data := PackedByteArray()
	data.resize(count * 2)
	for i in count:
		var t := float(i) / float(wav.mix_rate)
		var env := 1.0 - t / dur
		var s := sin(TAU * hz * t) * vol * env
		var v := int(clamp(s * 32767.0, -32768.0, 32767.0))
		data[i * 2] = v & 0xFF
		data[i * 2 + 1] = (v >> 8) & 0xFF
	wav.data = data
	return wav


func slide_in(node: Control, from_y: float = 24.0, duration: float = 0.28) -> void:
	if node == null:
		return
	var target := node.modulate
	node.modulate.a = 0.0
	var base := node.position
	node.position = base + Vector2(0, from_y)
	var tw := create_tween()
	tw.tween_property(node, "modulate:a", target.a, duration)
	tw.parallel().tween_property(node, "position", base, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
