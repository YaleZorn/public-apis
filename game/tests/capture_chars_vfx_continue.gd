extends SceneTree
## Capture v0.10.1 VFX continue media: ink aura / long skill / multi-frame 爆衣.

const OUT := "/cursor/stores/bc-71787b67-91e4-456d-b541-da2778721eaf/media/chars-vfx-continue"
const VF := preload("res://scripts/util/visual_factory.gd")
const SV := preload("res://scripts/util/state_vfx.gd")
const AP := preload("res://scripts/util/art_palette.gd")


func _initialize() -> void:
	DisplayServer.window_set_size(Vector2i(720, 1280))
	DirAccess.make_dir_recursive_absolute(OUT)
	call_deferred("_run")


func _run() -> void:
	var save_path := "user://kongfu_save_v0.json"
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(save_path)
	var gs := root.get_node_or_null("GameState")
	if gs:
		gs.set("td_checkpoint", {})
		gs.set("explore_checkpoint", {})
		gs.set("arena_checkpoint", {})
		gs.set("tower_checkpoint", {})
		gs.set("morning_buff_active", true)
		gs.set("morning_buff_day", gs.today_key())
	await _shot("res://scenes/shell/title_screen.tscn", "01-title.png", 0.85)
	await _shot("res://scenes/lobby/lobby.tscn", "02-lobby.png", 0.9)
	await _shot_vfx_board()
	await _shot_closeups()
	await _shot_td_aura()
	await _shot_td_skill_reveal()
	await _shot("res://scenes/explore/explore_run.tscn", "08-explore.png", 1.0)
	print("SCREENSHOTS_OK ", OUT)
	quit(0)


func _shot(scene_path: String, file: String, wait: float) -> void:
	var packed = load(scene_path)
	var node: Node = packed.instantiate()
	root.add_child(node)
	await create_timer(wait).timeout
	_save(file)
	node.queue_free()
	await create_timer(0.15).timeout


func _mist_bg(parent: Control) -> void:
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.03, 0.08, 0.07, 1.0)
	parent.add_child(bg)
	for i in 4:
		var veil := ColorRect.new()
		veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
		veil.size = Vector2(720, 220)
		veil.position = Vector2(0, 180 + i * 220)
		veil.color = Color(0.08 + i * 0.01, 0.16, 0.14, 0.22)
		parent.add_child(veil)


func _shot_vfx_board() -> void:
	var board := Control.new()
	board.size = Vector2(720, 1280)
	board.set_anchors_preset(Control.PRESET_FULL_RECT)
	_mist_bg(board)
	var title := Label.new()
	title.text = "v0.10.1 · 墨意光环 / 长峰技能 / 多帧爆衣"
	title.position = Vector2(28, 40)
	title.size = Vector2(660, 40)
	AP.apply_label(title, 24, AP.PAPER_INK)
	board.add_child(title)
	root.add_child(board)
	var cdb = root.get_node_or_null("ContentDB")
	var ids := ["unit_qinggong", "unit_mulan", "unit_feidao"]
	var labels := ["光环 Ink", "技能 Peak", "爆衣 Mid→Reveal"]
	for i in ids.size():
		var u: Dictionary = {}
		if cdb:
			u = cdb.get_unit(ids[i])
		var fig := VF.unit_node(u if not u.is_empty() else {"id": ids[i], "name": "?", "role": "dps", "color": "#6a8f71"}, Vector2(168, 220))
		fig.position = Vector2(36 + i * 230, 400)
		board.add_child(fig)
		SV.attach(fig, u, {"force_idle_aura": true, "buff": i == 0, "auto_buff": false})
		var lb := Label.new()
		lb.text = labels[i]
		lb.position = Vector2(36 + i * 230, 640)
		lb.size = Vector2(200, 28)
		AP.apply_label(lb, 15, AP.PAPER_DIM)
		board.add_child(lb)
		match i:
			1:
				SV.trigger_skill(fig, board, "aoe_damage")
			2:
				SV.trigger_reveal(fig, "showcase", true)
	await create_timer(0.55).timeout
	_save("03-vfx-board.png")
	board.queue_free()
	await create_timer(0.15).timeout


func _shot_closeups() -> void:
	var shots := [
		{"file": "04-aura-closeup.png", "id": "unit_mulan", "mode": "aura", "title": "光环 · Ink Wash + Wisp"},
		{"file": "05-skill-closeup.png", "id": "unit_feidao", "mode": "skill", "title": "技能 · Long Peak Trails"},
		{"file": "06-reveal-closeup.png", "id": "unit_qinggong", "mode": "reveal", "title": "爆衣 · Soft Edge Multi-frame"},
	]
	for s in shots:
		var board := Control.new()
		board.size = Vector2(720, 1280)
		_mist_bg(board)
		var title := Label.new()
		title.text = str(s.title)
		title.position = Vector2(40, 48)
		title.size = Vector2(640, 40)
		AP.apply_label(title, 22, AP.PAPER_INK)
		board.add_child(title)
		root.add_child(board)
		var cdb = root.get_node_or_null("ContentDB")
		var u: Dictionary = cdb.get_unit(str(s.id)) if cdb else {}
		var fig := VF.unit_node(u if not u.is_empty() else {"id": s.id, "name": "?", "role": "dps", "color": "#6a8f71"}, Vector2(280, 380))
		fig.position = Vector2(220, 360)
		board.add_child(fig)
		SV.attach(fig, u, {"force_idle_aura": true, "buff": true, "auto_buff": false})
		match str(s.mode):
			"skill":
				SV.trigger_skill(fig, board, "aoe_damage")
				await create_timer(0.35).timeout
			"reveal":
				SV.trigger_reveal(fig, "closeup", true)
				await create_timer(0.35).timeout
			_:
				await create_timer(0.45).timeout
		_save(str(s.file))
		board.queue_free()
		await create_timer(0.12).timeout


func _shot_td_aura() -> void:
	var packed = load("res://scenes/td/td_run.tscn")
	var node: Node = packed.instantiate()
	root.add_child(node)
	await create_timer(1.1).timeout
	_save("07-td-aura.png")
	node.queue_free()
	await create_timer(0.15).timeout


func _shot_td_skill_reveal() -> void:
	var packed = load("res://scenes/td/td_run.tscn")
	var node: Node = packed.instantiate()
	root.add_child(node)
	await create_timer(1.0).timeout
	for c in node.get_children():
		_trigger_deep(c)
	await create_timer(0.45).timeout
	_save("07b-td-skill-reveal.png")
	node.queue_free()
	await create_timer(0.15).timeout


func _trigger_deep(n: Node) -> void:
	if n is Control and (n as Control).has_meta("unit_id"):
		SV.trigger_skill(n as Control, n.get_parent(), "aoe_damage")
		SV.trigger_reveal(n as Control, "demo", true)
	for c in n.get_children():
		_trigger_deep(c)


func _save(file: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	var path := OUT + "/" + file
	img.save_png(path)
	print("SHOT ", path)
