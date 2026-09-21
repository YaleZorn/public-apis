extends Node
## Lightweight juice: procedural SFX, looping BGM beds, float numbers, shake, fades.

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
var _ambient_player: AudioStreamPlayer
var _ambient_on: bool = false
var _bgm_kind: String = "ambient"
var _bgm_streams: Dictionary = {}


func _ready() -> void:
	_sfx_root = Node.new()
	_sfx_root.name = "SfxRoot"
	add_child(_sfx_root)
	_build_streams()
	_setup_fade()
	_setup_ambient()
	SettingsManager.settings_changed.connect(_sync_ambient_volume)
	_upgrade_theme()


func _upgrade_theme() -> void:
	var ThemeBuilderScr := preload("res://scripts/util/theme_builder.gd")
	var theme := ThemeDB.get_project_theme()
	if theme:
		ThemeBuilderScr.apply_ornate(theme)


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


func start_ambient() -> void:
	play_bgm("lobby")


func start_title_music() -> void:
	play_bgm("title")


func start_lobby_music() -> void:
	play_bgm("lobby")


func start_battle_music() -> void:
	play_bgm("td")


func start_explore_music() -> void:
	play_bgm("explore")


func play_bgm(kind: String = "lobby") -> void:
	if _ambient_player == null:
		return
	_ambient_on = true
	if kind != _bgm_kind or _ambient_player.stream != _bgm_streams.get(kind):
		_bgm_kind = kind
		var stream: AudioStream = _bgm_streams.get(kind, _bgm_streams.get("ambient"))
		var was_playing := _ambient_player.playing
		_ambient_player.stream = stream
		if was_playing or _ambient_on:
			_ambient_player.play()
	_sync_ambient_volume()
	if not _ambient_player.playing:
		_ambient_player.play()


func stop_ambient() -> void:
	_ambient_on = false
	if _ambient_player and _ambient_player.playing:
		_ambient_player.stop()


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


func flash_modulate(node: CanvasItem, to: Color = Color(1.35, 1.2, 0.95, 1.0), duration: float = 0.14) -> void:
	if node == null or not is_instance_valid(node):
		return
	var base := node.modulate
	node.modulate = to
	var tw := node.create_tween()
	tw.tween_property(node, "modulate", base, duration)


func banner_pop(label: Control, hold: float = 1.6) -> void:
	## Wave / floor banner: fade+scale in, hold, fade out.
	if label == null:
		return
	label.visible = true
	label.modulate.a = 0.0
	label.pivot_offset = label.size * 0.5
	label.scale = Vector2(0.86, 0.86)
	var tw := create_tween()
	tw.tween_property(label, "modulate:a", 1.0, 0.16)
	tw.parallel().tween_property(label, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(hold)
	tw.tween_property(label, "modulate:a", 0.0, 0.28)
	tw.tween_callback(func():
		if is_instance_valid(label):
			label.visible = false
			label.scale = Vector2.ONE
	)


func threaten(node: CanvasItem, pulses: int = 3) -> void:
	## Stronghold / low-HP attention pulse (no layout change).
	if node == null or not is_instance_valid(node):
		return
	var base := node.modulate
	var tw := create_tween()
	for i in pulses:
		tw.tween_property(node, "modulate", Color(1.35, 0.55, 0.45, 1.0), 0.1)
		tw.tween_property(node, "modulate", base, 0.14)


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


func _setup_ambient() -> void:
	# Identifiable theme beds — title / lobby / TD / explore (legacy aliases kept).
	_bgm_streams = {
		"title": _compose_theme("title"),
		"lobby": _compose_theme("lobby"),
		"td": _compose_theme("td"),
		"explore": _compose_theme("explore"),
		"ambient": null,
		"battle": null,
	}
	_bgm_streams["ambient"] = _bgm_streams["lobby"]
	_bgm_streams["battle"] = _bgm_streams["td"]
	_ambient_player = AudioStreamPlayer.new()
	_ambient_player.name = "Ambient"
	_ambient_player.bus = "Master"
	_ambient_player.stream = _bgm_streams["lobby"]
	add_child(_ambient_player)


func _sync_ambient_volume() -> void:
	if _ambient_player == null:
		return
	var vol := SettingsManager.music_volume * SettingsManager.master_volume
	_ambient_player.volume_db = linear_to_db(maxf(vol * 0.35, 0.0001))
	if _ambient_on and vol <= 0.01 and _ambient_player.playing:
		_ambient_player.stop()
	elif _ambient_on and vol > 0.01 and not _ambient_player.playing:
		_ambient_player.play()


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
		"tap": _make_chime([620.0, 780.0], 0.06, 0.16),
		"place": _make_chime([280.0, 420.0, 560.0], 0.1, 0.2),
		"recall": _make_chime([360.0, 240.0], 0.09, 0.16),
		"hit": _make_noise_hit(0.045, 0.18),
		"kill": _make_chime([440.0, 554.0, 660.0], 0.12, 0.2),
		"wave": _make_chime([196.0, 247.0, 294.0, 370.0], 0.22, 0.2),
		"win": _make_chime([392.0, 494.0, 587.0, 784.0], 0.28, 0.22),
		"lose": _make_chime([220.0, 185.0, 147.0], 0.28, 0.2),
		"skill": _make_chime([330.0, 415.0, 523.0], 0.14, 0.2),
		"card": _make_chime([523.0, 659.0], 0.08, 0.14),
		"room": _make_chime([247.0, 311.0, 370.0], 0.16, 0.16),
		"lantern": _make_chime([523.0, 784.0], 0.1, 0.12),
		"claim": _make_chime([392.0, 523.0, 659.0, 784.0], 0.2, 0.2),
		"train": _make_chime([311.0, 392.0, 466.0], 0.14, 0.18),
		"quiz_ok": _make_chime([523.0, 659.0, 784.0], 0.14, 0.18),
		"quiz_bad": _make_chime([247.0, 196.0], 0.12, 0.18),
		"threat": _make_noise_hit(0.07, 0.22),
		"flank": _make_chime([185.0, 233.0, 311.0], 0.2, 0.22),
	}


func _make_beep(hz: float, dur: float, vol: float) -> AudioStreamWAV:
	return _make_chime([hz], dur, vol)


func _make_chime(freqs: Array, dur: float, vol: float) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 22050
	wav.stereo = false
	var count := int(wav.mix_rate * dur)
	var data := PackedByteArray()
	data.resize(count * 2)
	for i in count:
		var t := float(i) / float(wav.mix_rate)
		var env := pow(1.0 - t / dur, 1.35)
		var s := 0.0
		for fi in freqs.size():
			var hz: float = float(freqs[fi])
			var w := 1.0 / float(freqs.size())
			s += sin(TAU * hz * t) * w * 0.7
			s += sin(TAU * hz * 2.0 * t) * w * 0.18
		s *= vol * env
		var v := int(clamp(s * 32767.0, -32768.0, 32767.0))
		data[i * 2] = v & 0xFF
		data[i * 2 + 1] = (v >> 8) & 0xFF
	wav.data = data
	return wav


func _make_noise_hit(dur: float, vol: float) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 22050
	wav.stereo = false
	var count := int(wav.mix_rate * dur)
	var data := PackedByteArray()
	data.resize(count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i in count:
		var t := float(i) / float(wav.mix_rate)
		var env := pow(1.0 - t / dur, 2.2)
		var n := rng.randf_range(-1.0, 1.0) * 0.35
		var thump := sin(TAU * 90.0 * t) * 0.55
		var s := (n + thump) * vol * env
		var v := int(clamp(s * 32767.0, -32768.0, 32767.0))
		data[i * 2] = v & 0xFF
		data[i * 2 + 1] = (v >> 8) & 0xFF
	wav.data = data
	return wav


func _compose_theme(kind: String) -> AudioStreamWAV:
	## Distinct musical looping beds (title / lobby / td / explore).
	## Fuller than thin beep beds: pad + drone + lead + motif bells. Volume via 音乐.
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 22050
	wav.stereo = false
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	var dur := 24.0
	var count := int(wav.mix_rate * dur)
	wav.loop_end = count
	var data := PackedByteArray()
	data.resize(count * 2)
	# Theme motifs (Hz) — identifiable without scored OST assets
	var title_lead := [
		392.0, 440.0, 523.25, 587.33, 523.25, 440.0, 392.0, 349.23,
		329.63, 349.23, 392.0, 440.0, 493.88, 440.0, 392.0, 329.63,
	]
	var title_harm := [
		196.0, 220.0, 261.63, 293.66, 261.63, 220.0, 196.0, 174.61,
		164.81, 174.61, 196.0, 220.0, 246.94, 220.0, 196.0, 164.81,
	]
	var lobby_lead := [
		293.66, 349.23, 392.0, 440.0, 392.0, 349.23, 293.66, 261.63,
		220.0, 261.63, 293.66, 349.23, 392.0, 349.23, 293.66, 220.0,
	]
	var lobby_harm := [
		146.83, 174.61, 196.0, 220.0, 196.0, 174.61, 146.83, 130.81,
		110.0, 130.81, 146.83, 174.61, 196.0, 174.61, 146.83, 110.0,
	]
	var td_lead := [
		220.0, 246.94, 293.66, 329.63, 293.66, 246.94, 220.0, 196.0,
		164.81, 196.0, 220.0, 261.63, 293.66, 261.63, 220.0, 185.0,
	]
	var td_bass := [
		110.0, 110.0, 98.0, 98.0, 82.41, 82.41, 73.42, 73.42,
		82.41, 82.41, 98.0, 98.0, 110.0, 110.0, 92.5, 92.5,
	]
	var explore_lead := [
		261.63, 293.66, 329.63, 349.23, 392.0, 349.23, 329.63, 293.66,
		246.94, 261.63, 293.66, 329.63, 349.23, 311.13, 293.66, 246.94,
	]
	var explore_harm := [
		130.81, 146.83, 164.81, 174.61, 196.0, 174.61, 164.81, 146.83,
		123.47, 130.81, 146.83, 164.81, 174.61, 155.56, 146.83, 123.47,
	]
	var lead: Array
	var harm: Array
	match kind:
		"title":
			lead = title_lead
			harm = title_harm
		"td", "battle":
			lead = td_lead
			harm = td_bass
		"explore":
			lead = explore_lead
			harm = explore_harm
		_:
			lead = lobby_lead
			harm = lobby_harm
	var step := dur / float(lead.size())
	var is_td := kind == "td" or kind == "battle"
	var is_title := kind == "title"
	var is_explore := kind == "explore"
	var is_lobby := not is_td and not is_title and not is_explore
	for i in count:
		var t := float(i) / float(wav.mix_rate)
		var note_i := int(floor(t / step)) % lead.size()
		var note_t := fmod(t, step)
		var hz: float = float(lead[note_i])
		var hz_h: float = float(harm[note_i])
		var atk := clampf(note_t / (0.14 if is_title else 0.09), 0.0, 1.0)
		var rel := clampf((step - note_t) / (0.36 if is_title else 0.22), 0.0, 1.0)
		var note_env := atk * rel
		# Warm pad bed (identifiable body, not thin beep)
		var pad_base := 65.0 if is_title else (78.0 if is_explore else (52.0 if is_td else 70.0))
		var pad := (
			sin(TAU * pad_base * t) * 0.048
			+ sin(TAU * pad_base * 1.498 * t + 0.3) * 0.034
			+ sin(TAU * pad_base * 2.01 * t + 0.7) * 0.022
			+ sin(TAU * pad_base * 0.5 * t) * 0.028
		)
		pad *= 0.82 + 0.18 * sin(TAU * (0.12 if is_title else 0.2) * t)
		var drone_base := 48.0 if is_title else (62.0 if is_explore else (44.0 if is_td else 55.0))
		var drone := (
			sin(TAU * drone_base * t) * 0.06
			+ sin(TAU * drone_base * 1.5 * t + 0.2) * 0.036
			+ sin(TAU * drone_base * 2.0 * t + 0.5) * 0.024
		)
		drone *= 0.85 + 0.15 * sin(TAU * (0.18 if is_title else 0.25) * t)
		var lead_s := (
			sin(TAU * hz * t) * (0.062 if is_title else 0.052)
			+ sin(TAU * hz * 2.01 * t) * 0.02
			+ sin(TAU * hz * 3.0 * t) * 0.01
			+ sin(TAU * hz * 0.5 * t) * 0.012
		) * note_env
		var harm_s := (
			sin(TAU * hz_h * t) * 0.044
			+ sin(TAU * hz_h * 1.5 * t) * 0.016
			+ sin(TAU * hz_h * 2.0 * t) * 0.008
		) * note_env
		var bell := 0.0
		if note_i % 4 == 0:
			bell = sin(TAU * hz * 2.0 * t) * 0.026 * note_env * sin(PI * clampf(note_t / step, 0.0, 1.0))
		var pulse := 0.0
		if is_td:
			var beat := fmod(t * 2.6, 1.0)
			pulse = exp(-beat * 12.0) * 0.078 * sin(TAU * 68.0 * t)
			var off := fmod(t * 2.6 + 0.5, 1.0)
			pulse += exp(-off * 20.0) * 0.028 * sin(TAU * 170.0 * t)
			# Marching fifths under lead
			pulse += sin(TAU * hz_h * 0.5 * t) * 0.02 * note_env
			drone *= 1.2
			lead_s *= 1.28
			pad *= 1.1
		elif is_explore:
			var walk := fmod(t * 1.55, 1.0)
			pulse = exp(-walk * 9.0) * 0.034 * sin(TAU * 92.0 * t)
			var wood := fmod(t * 3.1, 1.0)
			pulse += exp(-wood * 28.0) * 0.016 * sin(TAU * 420.0 * t)
			var arp_hz := float(explore_lead[int(floor(t * 1.15)) % explore_lead.size()])
			bell += sin(TAU * arp_hz * 2.0 * t) * 0.014 * (0.5 + 0.5 * sin(TAU * 0.32 * t))
			lead_s *= 1.12
			pad *= 1.08
		elif is_title:
			if note_i % 8 == 0:
				bell += sin(TAU * hz * 1.5 * t) * 0.034 * note_env
			# Rising fifth swell
			bell += sin(TAU * hz * 1.498 * t) * 0.012 * note_env * sin(TAU * 0.08 * t)
			drone *= 1.12
			lead_s *= 1.2
			pad *= 1.15
		elif is_lobby:
			var arp_hz2 := float(lobby_lead[int(floor(t * 1.45)) % lobby_lead.size()])
			bell += sin(TAU * arp_hz2 * 2.0 * t) * 0.012 * (0.5 + 0.5 * sin(TAU * 0.38 * t))
			# Soft plucked echo
			if note_i % 2 == 0:
				bell += sin(TAU * hz * 3.0 * t) * 0.01 * note_env
			pad *= 1.05
		var s := pad + drone + lead_s + harm_s + bell + pulse
		var edge := minf(t, dur - t)
		var env := clampf(edge / 0.8, 0.0, 1.0)
		var v := int(clamp(s * env * 32767.0, -32768.0, 32767.0))
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
