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


func start_arena_music() -> void:
	play_bgm("arena")


func start_tower_music() -> void:
	play_bgm("tower")


func start_knowledge_music() -> void:
	play_bgm("knowledge")


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
	# Identifiable theme beds — title / lobby / TD / explore / arena / tower / knowledge.
	_bgm_streams = {
		"title": _compose_theme("title"),
		"lobby": _compose_theme("lobby"),
		"td": _compose_theme("td"),
		"explore": _compose_theme("explore"),
		"arena": _compose_theme("arena"),
		"tower": _compose_theme("tower"),
		"knowledge": _compose_theme("knowledge"),
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
		"tap": _make_chime([620.0, 780.0, 930.0], 0.055, 0.15),
		"place": _make_layered([
			{"freqs": [180.0, 240.0], "dur": 0.08, "vol": 0.16, "noise": 0.08},
			{"freqs": [420.0, 560.0, 700.0], "dur": 0.12, "vol": 0.14, "noise": 0.0},
		]),
		"recall": _make_chime([360.0, 280.0, 220.0], 0.1, 0.15),
		"hit": _make_layered([
			{"freqs": [90.0], "dur": 0.05, "vol": 0.2, "noise": 0.28},
			{"freqs": [520.0, 680.0], "dur": 0.04, "vol": 0.1, "noise": 0.0},
		]),
		"kill": _make_chime([440.0, 554.0, 660.0, 880.0], 0.14, 0.2),
		"wave": _make_chime([196.0, 247.0, 294.0, 370.0, 440.0], 0.26, 0.2),
		"win": _make_chime([392.0, 494.0, 587.0, 784.0, 988.0], 0.32, 0.22),
		"lose": _make_chime([220.0, 185.0, 147.0, 110.0], 0.3, 0.2),
		"skill": _make_chime([330.0, 415.0, 523.0, 659.0], 0.16, 0.2),
		"card": _make_chime([523.0, 659.0, 784.0], 0.09, 0.13),
		"room": _make_chime([247.0, 311.0, 370.0, 415.0], 0.18, 0.15),
		"lantern": _make_chime([523.0, 784.0, 988.0], 0.11, 0.12),
		"claim": _make_chime([392.0, 523.0, 659.0, 784.0, 1046.0], 0.22, 0.2),
		"train": _make_chime([311.0, 392.0, 466.0, 523.0], 0.15, 0.17),
		"quiz_ok": _make_chime([523.0, 659.0, 784.0, 988.0], 0.15, 0.18),
		"quiz_bad": _make_chime([247.0, 196.0, 165.0], 0.14, 0.17),
		"threat": _make_layered([
			{"freqs": [70.0, 95.0], "dur": 0.09, "vol": 0.22, "noise": 0.35},
			{"freqs": [185.0, 233.0], "dur": 0.08, "vol": 0.12, "noise": 0.0},
		]),
		"flank": _make_chime([185.0, 233.0, 311.0, 370.0], 0.22, 0.22),
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


func _make_layered(layers: Array) -> AudioStreamWAV:
	## Mix short partials (+ optional noise) into one punchier one-shot.
	var max_dur := 0.05
	for layer in layers:
		max_dur = maxf(max_dur, float(layer.get("dur", 0.08)))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 22050
	wav.stereo = false
	var count := int(wav.mix_rate * max_dur)
	var data := PackedByteArray()
	data.resize(count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 91
	for i in count:
		var t := float(i) / float(wav.mix_rate)
		var s := 0.0
		for layer in layers:
			var dur: float = float(layer.get("dur", 0.08))
			if t > dur:
				continue
			var env := pow(1.0 - t / dur, 1.5)
			var vol: float = float(layer.get("vol", 0.15))
			var freqs: Array = layer.get("freqs", [])
			var partial := 0.0
			for fi in freqs.size():
				var hz: float = float(freqs[fi])
				var w := 1.0 / float(maxi(freqs.size(), 1))
				partial += sin(TAU * hz * t) * w
				partial += sin(TAU * hz * 2.0 * t) * w * 0.2
			var noise_amt: float = float(layer.get("noise", 0.0))
			if noise_amt > 0.0:
				partial += rng.randf_range(-1.0, 1.0) * noise_amt
			s += partial * vol * env
		var v := int(clamp(s * 32767.0, -32768.0, 32767.0))
		data[i * 2] = v & 0xFF
		data[i * 2 + 1] = (v >> 8) & 0xFF
	wav.data = data
	return wav


func _compose_theme(kind: String) -> AudioStreamWAV:
	## Musical looping beds with clear motifs (title / lobby / td / explore / arena / tower / knowledge).
	## Phrase-based AABA-ish contours + harmony + counter voice; volume still via Settings 音乐.
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 22050
	wav.stereo = false
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	var dur := 32.0
	var count := int(wav.mix_rate * dur)
	wav.loop_end = count
	var data := PackedByteArray()
	data.resize(count * 2)
	# Motifs in Hz — pentatonic / minor wuxia flavor, distinct per scene
	var title_lead := [
		392.0, 440.0, 523.25, 587.33, 659.25, 587.33, 523.25, 440.0,
		392.0, 349.23, 329.63, 349.23, 392.0, 440.0, 493.88, 523.25,
		587.33, 523.25, 440.0, 392.0, 349.23, 329.63, 293.66, 329.63,
		349.23, 392.0, 440.0, 523.25, 587.33, 523.25, 440.0, 392.0,
	]
	var title_harm := [
		261.63, 293.66, 329.63, 349.23, 392.0, 349.23, 329.63, 293.66,
		261.63, 246.94, 220.0, 246.94, 261.63, 293.66, 329.63, 349.23,
		392.0, 349.23, 293.66, 261.63, 246.94, 220.0, 196.0, 220.0,
		233.08, 261.63, 293.66, 329.63, 349.23, 329.63, 293.66, 261.63,
	]
	var lobby_lead := [
		293.66, 329.63, 349.23, 392.0, 440.0, 392.0, 349.23, 329.63,
		293.66, 261.63, 246.94, 261.63, 293.66, 349.23, 392.0, 440.0,
		493.88, 440.0, 392.0, 349.23, 329.63, 293.66, 261.63, 246.94,
		220.0, 246.94, 261.63, 293.66, 349.23, 392.0, 349.23, 293.66,
	]
	var lobby_harm := [
		146.83, 164.81, 174.61, 196.0, 220.0, 196.0, 174.61, 164.81,
		146.83, 130.81, 123.47, 130.81, 146.83, 174.61, 196.0, 220.0,
		246.94, 220.0, 196.0, 174.61, 164.81, 146.83, 130.81, 123.47,
		110.0, 123.47, 130.81, 146.83, 174.61, 196.0, 174.61, 146.83,
	]
	var td_lead := [
		220.0, 246.94, 261.63, 293.66, 329.63, 293.66, 261.63, 246.94,
		220.0, 196.0, 185.0, 196.0, 220.0, 246.94, 293.66, 329.63,
		349.23, 329.63, 293.66, 246.94, 220.0, 196.0, 164.81, 185.0,
		196.0, 220.0, 246.94, 261.63, 293.66, 261.63, 220.0, 185.0,
	]
	var td_bass := [
		110.0, 110.0, 98.0, 98.0, 82.41, 82.41, 73.42, 73.42,
		110.0, 110.0, 92.5, 92.5, 82.41, 82.41, 73.42, 73.42,
		98.0, 98.0, 82.41, 82.41, 73.42, 73.42, 65.41, 65.41,
		82.41, 82.41, 98.0, 98.0, 110.0, 110.0, 92.5, 92.5,
	]
	var explore_lead := [
		261.63, 293.66, 329.63, 349.23, 392.0, 440.0, 392.0, 349.23,
		329.63, 293.66, 261.63, 246.94, 261.63, 293.66, 329.63, 349.23,
		392.0, 349.23, 311.13, 293.66, 261.63, 233.08, 246.94, 261.63,
		293.66, 329.63, 349.23, 392.0, 349.23, 329.63, 293.66, 261.63,
	]
	var explore_harm := [
		130.81, 146.83, 164.81, 174.61, 196.0, 220.0, 196.0, 174.61,
		164.81, 146.83, 130.81, 123.47, 130.81, 146.83, 164.81, 174.61,
		196.0, 174.61, 155.56, 146.83, 130.81, 116.54, 123.47, 130.81,
		146.83, 164.81, 174.61, 196.0, 174.61, 164.81, 146.83, 130.81,
	]
	# Arena: tighter minor drive — survival grind identity vs explore walk
	var arena_lead := [
		233.08, 261.63, 277.18, 311.13, 349.23, 311.13, 277.18, 261.63,
		233.08, 207.65, 196.0, 207.65, 233.08, 261.63, 311.13, 349.23,
		369.99, 349.23, 311.13, 261.63, 233.08, 207.65, 185.0, 196.0,
		207.65, 233.08, 261.63, 277.18, 311.13, 277.18, 233.08, 207.65,
	]
	var arena_bass := [
		116.54, 116.54, 103.83, 103.83, 92.5, 92.5, 87.31, 87.31,
		116.54, 116.54, 98.0, 98.0, 92.5, 92.5, 77.78, 77.78,
		103.83, 103.83, 92.5, 92.5, 77.78, 77.78, 69.3, 69.3,
		92.5, 92.5, 103.83, 103.83, 116.54, 116.54, 98.0, 98.0,
	]
	# Tower climb: ascending pentatonic steps — vertical progress vs explore walk
	var tower_lead := [
		196.0, 220.0, 246.94, 261.63, 293.66, 329.63, 349.23, 392.0,
		349.23, 329.63, 293.66, 261.63, 246.94, 261.63, 293.66, 349.23,
		392.0, 440.0, 493.88, 523.25, 493.88, 440.0, 392.0, 349.23,
		329.63, 293.66, 261.63, 246.94, 220.0, 246.94, 293.66, 349.23,
	]
	var tower_bass := [
		98.0, 98.0, 110.0, 110.0, 130.81, 130.81, 146.83, 146.83,
		123.47, 123.47, 130.81, 130.81, 146.83, 146.83, 164.81, 164.81,
		98.0, 98.0, 110.0, 110.0, 130.81, 130.81, 146.83, 146.83,
		87.31, 87.31, 98.0, 98.0, 110.0, 110.0, 130.81, 130.81,
	]
	# Knowledge journal: soft descending answer phrases — calm vs TD/arena drive
	var knowledge_lead := [
		349.23, 329.63, 293.66, 261.63, 246.94, 261.63, 293.66, 329.63,
		349.23, 392.0, 349.23, 329.63, 293.66, 261.63, 246.94, 220.0,
		246.94, 261.63, 293.66, 329.63, 349.23, 392.0, 440.0, 392.0,
		349.23, 329.63, 293.66, 261.63, 246.94, 261.63, 293.66, 329.63,
	]
	var knowledge_harm := [
		174.61, 164.81, 146.83, 130.81, 123.47, 130.81, 146.83, 164.81,
		174.61, 196.0, 174.61, 164.81, 146.83, 130.81, 123.47, 110.0,
		123.47, 130.81, 146.83, 164.81, 174.61, 196.0, 220.0, 196.0,
		174.61, 164.81, 146.83, 130.81, 123.47, 130.81, 146.83, 164.81,
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
		"arena":
			lead = arena_lead
			harm = arena_bass
		"tower":
			lead = tower_lead
			harm = tower_bass
		"knowledge":
			lead = knowledge_lead
			harm = knowledge_harm
		_:
			lead = lobby_lead
			harm = lobby_harm
	var step := dur / float(lead.size())
	var is_td := kind == "td" or kind == "battle"
	var is_title := kind == "title"
	var is_explore := kind == "explore"
	var is_arena := kind == "arena"
	var is_tower := kind == "tower"
	var is_knowledge := kind == "knowledge"
	var is_lobby := not is_td and not is_title and not is_explore and not is_arena and not is_tower and not is_knowledge
	for i in count:
		var t := float(i) / float(wav.mix_rate)
		var note_i := int(floor(t / step)) % lead.size()
		var note_t := fmod(t, step)
		var hz: float = float(lead[note_i])
		var hz_h: float = float(harm[note_i])
		# Counter voice: fifth above, delayed by half-step for call/response body
		var counter_i := (note_i + 4) % lead.size()
		var hz_c: float = float(lead[counter_i]) * 1.498
		# Phrase envelope: longer sustain on even bars for singable contour
		var phrase_boost := 1.12 if (note_i % 8) < 4 else 0.92
		var atk_len := 0.14 if is_knowledge else (0.12 if is_title else (0.07 if is_arena else (0.08 if is_tower else 0.09)))
		var rel_len := 0.48 if is_knowledge else (0.4 if is_title else (0.18 if is_arena else (0.22 if is_tower else 0.26)))
		var atk := clampf(note_t / atk_len, 0.0, 1.0)
		var rel := clampf((step - note_t) / rel_len, 0.0, 1.0)
		var note_env := atk * rel * phrase_boost
		var pad_base := 58.0 if is_knowledge else (65.0 if is_title else (78.0 if is_explore else (48.0 if is_td else (58.0 if is_arena else (54.0 if is_tower else 70.0)))))
		var pad := (
			sin(TAU * pad_base * t) * 0.052
			+ sin(TAU * pad_base * 1.498 * t + 0.3) * 0.036
			+ sin(TAU * pad_base * 2.01 * t + 0.7) * 0.024
			+ sin(TAU * pad_base * 0.5 * t) * 0.03
		)
		pad *= 0.82 + 0.18 * sin(TAU * (0.08 if is_knowledge else (0.1 if is_title else 0.18)) * t)
		var drone_base := 52.0 if is_knowledge else (48.0 if is_title else (62.0 if is_explore else (40.0 if is_td else (52.0 if is_arena else (44.0 if is_tower else 55.0)))))
		var drone := (
			sin(TAU * drone_base * t) * 0.064
			+ sin(TAU * drone_base * 1.5 * t + 0.2) * 0.038
			+ sin(TAU * drone_base * 2.0 * t + 0.5) * 0.026
		)
		drone *= 0.85 + 0.15 * sin(TAU * (0.12 if is_knowledge else (0.15 if is_title else 0.22)) * t)
		# Melodic lead with soft fifth harmony under tone
		var lead_s := (
			sin(TAU * hz * t) * (0.072 if is_title or is_knowledge else 0.058)
			+ sin(TAU * hz * 2.01 * t) * 0.022
			+ sin(TAU * hz * 3.0 * t) * 0.011
			+ sin(TAU * hz * 1.498 * t) * 0.014
			+ sin(TAU * hz * 0.5 * t) * 0.012
		) * note_env
		var harm_s := (
			sin(TAU * hz_h * t) * 0.048
			+ sin(TAU * hz_h * 1.5 * t) * 0.018
			+ sin(TAU * hz_h * 2.0 * t) * 0.01
		) * note_env
		# Soft counter / answering phrase
		var counter_env := note_env * (0.55 if (note_i % 8) >= 4 else 0.22)
		var counter_s := (
			sin(TAU * hz_c * t) * 0.028
			+ sin(TAU * hz_c * 2.0 * t) * 0.01
		) * counter_env
		var bell := 0.0
		if note_i % 4 == 0:
			bell = sin(TAU * hz * 2.0 * t) * 0.03 * note_env * sin(PI * clampf(note_t / step, 0.0, 1.0))
		# Call-and-response echo on odd phrases
		if note_i % 8 >= 4 and note_i % 2 == 0:
			var echo_hz := float(lead[(note_i + 2) % lead.size()])
			bell += sin(TAU * echo_hz * t) * 0.018 * note_env * 0.7
		var pulse := 0.0
		if is_td:
			var beat := fmod(t * 2.8, 1.0)
			pulse = exp(-beat * 11.0) * 0.082 * sin(TAU * 68.0 * t)
			var off := fmod(t * 2.8 + 0.5, 1.0)
			pulse += exp(-off * 18.0) * 0.032 * sin(TAU * 170.0 * t)
			pulse += sin(TAU * hz_h * 0.5 * t) * 0.022 * note_env
			drone *= 1.22
			lead_s *= 1.3
			pad *= 1.12
			counter_s *= 1.15
		elif is_arena:
			var beat2 := fmod(t * 3.2, 1.0)
			pulse = exp(-beat2 * 10.0) * 0.07 * sin(TAU * 78.0 * t)
			var snare := fmod(t * 3.2 + 0.5, 1.0)
			pulse += exp(-snare * 22.0) * 0.028 * sin(TAU * 210.0 * t)
			# Rising tension every 8 notes
			var tension := 0.85 + 0.15 * float(note_i % 8) / 7.0
			lead_s *= 1.25 * tension
			drone *= 1.15
			pad *= 1.08
			counter_s *= 1.2
			if note_i % 4 == 0:
				bell += sin(TAU * hz * 3.0 * t) * 0.02 * note_env
		elif is_tower:
			# Steady climb pulse — slower than arena, ascending vs explore stroll
			var step_beat := fmod(t * 2.1, 1.0)
			pulse = exp(-step_beat * 8.5) * 0.055 * sin(TAU * 72.0 * t)
			var echo_step := fmod(t * 2.1 + 0.33, 1.0)
			pulse += exp(-echo_step * 14.0) * 0.024 * sin(TAU * 144.0 * t)
			# Floor-rise swell: higher over each 8-note phrase
			var climb := 0.9 + 0.22 * float(note_i % 8) / 7.0
			lead_s *= 1.28 * climb
			harm_s *= 1.12
			drone *= 1.18
			pad *= 1.1
			counter_s *= 1.18 * climb
			if note_i % 8 == 0:
				bell += sin(TAU * hz * 2.0 * t) * 0.028 * note_env
			if note_i % 4 == 2:
				bell += sin(TAU * hz * 1.498 * t) * 0.016 * note_env
		elif is_explore:
			var walk := fmod(t * 1.45, 1.0)
			pulse = exp(-walk * 9.0) * 0.036 * sin(TAU * 92.0 * t)
			var wood := fmod(t * 2.9, 1.0)
			pulse += exp(-wood * 26.0) * 0.018 * sin(TAU * 420.0 * t)
			var arp_hz := float(explore_lead[int(floor(t * 1.05)) % explore_lead.size()])
			bell += sin(TAU * arp_hz * 2.0 * t) * 0.016 * (0.5 + 0.5 * sin(TAU * 0.28 * t))
			# Plucked ostinato on every other beat
			if note_i % 2 == 0:
				bell += sin(TAU * hz * 3.01 * t) * 0.014 * note_env
			lead_s *= 1.15
			pad *= 1.1
			counter_s *= 1.1
		elif is_knowledge:
			# Soft page-turn pulse + flute-like fifths — journal calm
			var page := fmod(t * 0.85, 1.0)
			pulse = exp(-page * 7.0) * 0.022 * sin(TAU * 110.0 * t)
			if note_i % 8 == 0:
				bell += sin(TAU * hz * 1.5 * t) * 0.032 * note_env
			if note_i % 4 == 2:
				bell += sin(TAU * hz * 2.0 * t) * 0.018 * note_env * 0.8
			drone *= 1.2
			pad *= 1.22
			lead_s *= 1.18
			harm_s *= 1.15
			counter_s *= 0.9
		elif is_title:
			if note_i % 8 == 0:
				bell += sin(TAU * hz * 1.5 * t) * 0.038 * note_env
			bell += sin(TAU * hz * 1.498 * t) * 0.014 * note_env * sin(TAU * 0.07 * t)
			# Opening fanfare swell every 16
			if note_i % 16 < 2:
				lead_s *= 1.35
				bell += sin(TAU * hz * 2.0 * t) * 0.025 * note_env
			drone *= 1.15
			lead_s *= 1.22
			pad *= 1.18
			counter_s *= 1.25
		elif is_lobby:
			var arp_hz2 := float(lobby_lead[int(floor(t * 1.35)) % lobby_lead.size()])
			bell += sin(TAU * arp_hz2 * 2.0 * t) * 0.014 * (0.5 + 0.5 * sin(TAU * 0.35 * t))
			if note_i % 2 == 0:
				bell += sin(TAU * hz * 3.0 * t) * 0.012 * note_env
			# Soft cadence resolve at phrase end
			if note_i % 8 == 7:
				harm_s *= 1.25
			pad *= 1.08
			lead_s *= 1.08
			counter_s *= 1.05
		var s := pad + drone + lead_s + harm_s + counter_s + bell + pulse
		var edge := minf(t, dur - t)
		var env := clampf(edge / 0.9, 0.0, 1.0)
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
