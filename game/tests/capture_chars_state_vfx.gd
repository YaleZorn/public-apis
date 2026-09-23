extends SceneTree
## Capture v0.9.9 state VFX media: aura / skill burst / 爆衣 / lobby / TD / explore.

const OUT := "/cursor/stores/bc-71787b67-91e4-456d-b541-da2778721eaf/media/chars-state-vfx"
const VF := preload("res://scripts/util/visual_factory.gd")
const SV := preload("res://scripts/util/state_vfx.gd")


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
	await _shot_td_aura()
	await _shot_td_skill_reveal()
	await _shot("res://scenes/explore/explore_run.tscn", "06-explore.png", 1.0)
	await _shot_explore_skill()
	await _shot("res://scenes/arena/arena_run.tscn", "08-arena.png", 1.0)
	await _shot("res://scenes/tower/tower_run.tscn", "09-tower.png", 1.0)
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


func _shot_vfx_board() -> void:
	## Studio board: idle aura · skill burst · 爆衣 reveal side-by-side.
	var board := Control.new()
	board.size = Vector2(720, 1280)
	board.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.04, 0.09, 0.08, 1.0)
	board.add_child(bg)
	var title := Label.new()
	title.text = "状态特效 · 光环 / 技能激发 / 爆衣"
	title.position = Vector2(40, 36)
	title.size = Vector2(640, 40)
	board.add_child(title)
	root.add_child(board)
	var cdb = root.get_node_or_null("ContentDB")
	var ids := ["unit_qinggong", "unit_mulan", "unit_feidao"]
	var labels := ["光环 Idle", "技能激发", "爆衣 Reveal"]
	for i in ids.size():
		var u: Dictionary = {}
		if cdb:
			u = cdb.get_unit(ids[i])
		var fig := VF.unit_node(u if not u.is_empty() else {"id": ids[i], "name": "?", "role": "dps", "color": "#6a8f71"}, Vector2(160, 210))
		fig.position = Vector2(40 + i * 220, 420)
		board.add_child(fig)
		await create_timer(0.12).timeout
		match i:
			0:
				SV.show_idle_aura(fig, true, Color(0.45, 0.72, 0.95, 0.7))
				SV.show_buff_ring(fig, true, Color(0.85, 0.7, 0.3, 0.85))
			1:
				SV.trigger_skill(fig, board, "aoe_damage")
			2:
				SV.trigger_reveal(fig, "showcase", true)
		var cap := Label.new()
		cap.text = labels[i]
		cap.position = Vector2(40 + i * 220, 660)
		cap.size = Vector2(160, 28)
		board.add_child(cap)
	await create_timer(0.55).timeout
	_save("03-vfx-board.png")
	board.queue_free()
	await create_timer(0.15).timeout


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
	await create_timer(0.6).timeout
	_save("04-td-aura.png")
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
	# Force skill + reveal on deployed figures
	for slot in td.deployed.keys():
		var info: Dictionary = td.deployed[slot]
		var node: Control = info.node
		if node:
			SV.trigger_skill(node, td.units_layer, "aoe_damage")
			SV.trigger_reveal(node, "demo", true)
	await create_timer(0.45).timeout
	_save("05-td-skill-reveal.png")
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
	await create_timer(0.45).timeout
	_save("07-explore-skill-reveal.png")
	ex.queue_free()
	await create_timer(0.15).timeout


func _save(file: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	var path := OUT.path_join(file)
	img.save_png(path)
	print("saved ", path)
