extends SceneTree
## Capture v0.10.0 VFX quality rebuild media: aura / skill / 爆衣 + modes.

const OUT := "/cursor/stores/bc-71787b67-91e4-456d-b541-da2778721eaf/media/chars-vfx-rebuild"
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
	await _shot_explore_skill()
	await _shot("res://scenes/arena/arena_run.tscn", "10-arena.png", 1.0)
	await _shot("res://scenes/tower/tower_run.tscn", "11-tower.png", 1.0)
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
	## Ink-mist atmosphere instead of flat black wash.
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
	var gold := ColorRect.new()
	gold.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gold.size = Vector2(720, 3)
	gold.position = Vector2(0, 96)
	gold.color = Color(AP.LANTERN_GOLD.r, AP.LANTERN_GOLD.g, AP.LANTERN_GOLD.b, 0.35)
	parent.add_child(gold)


func _shot_vfx_board() -> void:
	var board := Control.new()
	board.size = Vector2(720, 1280)
	board.set_anchors_preset(Control.PRESET_FULL_RECT)
	_mist_bg(board)
	var title := Label.new()
	title.text = "v0.10 · 光环 / 技能激发 / 爆衣"
	title.position = Vector2(40, 40)
	title.size = Vector2(640, 40)
	AP.apply_label(title, 26, AP.PAPER_INK)
	board.add_child(title)
	var sub := Label.new()
	sub.text = "状态特效品质重建 · ink-mist"
	sub.position = Vector2(40, 78)
	sub.size = Vector2(640, 28)
	AP.apply_label(sub, 16, AP.PAPER_DIM)
	board.add_child(sub)
	root.add_child(board)
	var cdb = root.get_node_or_null("ContentDB")
	var ids := ["unit_qinggong", "unit_mulan", "unit_feidao"]
	var labels := ["光环 Idle+Buff", "技能激发", "爆衣 Reveal"]
	for i in ids.size():
		var u: Dictionary = {}
		if cdb:
			u = cdb.get_unit(ids[i])
		var fig := VF.unit_node(u if not u.is_empty() else {"id": ids[i], "name": "?", "role": "dps", "color": "#6a8f71"}, Vector2(168, 220))
		fig.position = Vector2(36 + i * 230, 400)
		board.add_child(fig)
		VF.idle_bob(fig, 2.5, 1.9)
		await create_timer(0.12).timeout
		match i:
			0:
				SV.show_idle_aura(fig, true, Color(0.42, 0.78, 0.68, 0.8))
				SV.show_buff_ring(fig, true, Color(0.9, 0.72, 0.32, 0.9))
			1:
				SV.trigger_skill(fig, board, "aoe_damage")
			2:
				SV.trigger_reveal(fig, "showcase", true)
		var cap := Label.new()
		cap.text = labels[i]
		cap.position = Vector2(36 + i * 230, 660)
		cap.size = Vector2(200, 28)
		AP.apply_label(cap, 15, AP.PAPER_INK)
		board.add_child(cap)
	await create_timer(0.6).timeout
	_save("03-vfx-board.png")
	board.queue_free()
	await create_timer(0.15).timeout


func _shot_closeups() -> void:
	## Dedicated close-ups: aura / skill / reveal for critique.
	var shots := [
		{"file": "04-aura-closeup.png", "id": "unit_qinggong", "mode": "aura", "title": "光环 · Idle + Buff"},
		{"file": "05-skill-closeup.png", "id": "unit_mulan", "mode": "skill", "title": "技能激发 · Cast Flourish"},
		{"file": "06-reveal-closeup.png", "id": "unit_qinggong", "mode": "reveal", "title": "爆衣 · Authored Reveal"},
	]
	for s in shots:
		var board := Control.new()
		board.size = Vector2(720, 1280)
		_mist_bg(board)
		var title := Label.new()
		title.text = str(s.title)
		title.position = Vector2(40, 48)
		title.size = Vector2(640, 36)
		AP.apply_label(title, 24, AP.PAPER_INK)
		board.add_child(title)
		root.add_child(board)
		var cdb = root.get_node_or_null("ContentDB")
		var u: Dictionary = cdb.get_unit(str(s.id)) if cdb else {"id": str(s.id), "name": "?", "role": "dps", "color": "#6a8f71"}
		var fig := VF.unit_node(u, Vector2(280, 360))
		fig.position = Vector2(220, 380)
		board.add_child(fig)
		await create_timer(0.2).timeout
		match str(s.mode):
			"aura":
				SV.show_idle_aura(fig, true, Color(0.42, 0.78, 0.68, 0.85))
				SV.show_buff_ring(fig, true, Color(0.92, 0.74, 0.32, 0.92))
				await create_timer(0.55).timeout
			"skill":
				SV.trigger_skill(fig, board, "aoe_damage")
				# Catch flourish near peak (flash + slash still visible)
				await create_timer(0.14).timeout
			"reveal":
				SV.trigger_reveal(fig, "closeup", true)
				await create_timer(0.45).timeout
		_save(str(s.file))
		board.queue_free()
		await create_timer(0.12).timeout


func _shot_td_aura() -> void:
	var packed = load("res://scenes/td/td_battle.tscn")
	var td = packed.instantiate()
	root.add_child(td)
	await create_timer(0.7).timeout
	td.selected_unit_id = "unit_qinggong"
	td._on_slot_pressed(0)
	td.selected_unit_id = "unit_yishi"
	td._on_slot_pressed(1)
	td.selected_unit_id = "unit_tiebi"
	td._on_slot_pressed(2)
	await create_timer(0.65).timeout
	_save("07-td-aura.png")
	td.queue_free()
	await create_timer(0.15).timeout


func _shot_td_skill_reveal() -> void:
	var packed = load("res://scenes/td/td_battle.tscn")
	var td = packed.instantiate()
	root.add_child(td)
	await create_timer(0.6).timeout
	td.selected_unit_id = "unit_mulan"
	td._on_slot_pressed(0)
	td.selected_unit_id = "unit_qinggong"
	td._on_slot_pressed(1)
	await create_timer(0.35).timeout
	for slot in td.deployed.keys():
		var info: Dictionary = td.deployed[slot]
		var node: Control = info.node
		if node:
			SV.trigger_skill(node, td.units_layer, "aoe_damage")
			SV.trigger_reveal(node, "demo", true)
	await create_timer(0.5).timeout
	_save("07b-td-skill-reveal.png")
	td.queue_free()
	await create_timer(0.15).timeout


func _shot_explore_skill() -> void:
	var packed = load("res://scenes/explore/explore_run.tscn")
	var ex = packed.instantiate()
	root.add_child(ex)
	await create_timer(0.8).timeout
	if ex.ring and ex.ring.hero_visual:
		SV.trigger_skill(ex.ring.hero_visual, ex.ring.arena, "aoe_damage")
		SV.trigger_reveal(ex.ring.hero_visual, "demo", true)
	await create_timer(0.5).timeout
	_save("09-explore-skill-reveal.png")
	ex.queue_free()
	await create_timer(0.15).timeout


func _save(file: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	var path := OUT.path_join(file)
	img.save_png(path)
	print("saved ", path)
