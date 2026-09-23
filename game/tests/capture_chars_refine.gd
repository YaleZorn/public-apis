extends SceneTree
## Capture v0.9.8 character refine media (stronger art + walk/attack frames).

const OUT := "/cursor/stores/bc-71787b67-91e4-456d-b541-da2778721eaf/media/chars-refine"
const VF := preload("res://scripts/util/visual_factory.gd")


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
	await _shot("res://scenes/shell/title_screen.tscn", "01-title.png", 0.85)
	await _shot_lobby_roster()
	await _shot_td_figures()
	await _shot_td_wave_combat()
	await _shot("res://scenes/explore/explore_run.tscn", "05-explore-figures.png", 1.0)
	await _shot("res://scenes/arena/arena_run.tscn", "06-arena-figures.png", 1.1)
	await _shot_closeups()
	await _shot_portrait_grid()
	await _shot_sheet_strip()
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


func _shot_lobby_roster() -> void:
	var packed = load("res://scenes/lobby/lobby.tscn")
	var node = packed.instantiate()
	root.add_child(node)
	await create_timer(0.9).timeout
	_save("02-lobby-roster.png")
	node.queue_free()
	await create_timer(0.15).timeout


func _shot_td_figures() -> void:
	var packed = load("res://scenes/td/td_battle.tscn")
	var td = packed.instantiate()
	root.add_child(td)
	await create_timer(0.7).timeout
	td.selected_unit_id = "unit_tiebi"
	td._on_slot_pressed(0)
	td.selected_unit_id = "unit_feidao"
	td._on_slot_pressed(1)
	td.selected_unit_id = "unit_qinggong"
	td._on_slot_pressed(2)
	td.selected_unit_id = "unit_yishi"
	td._on_slot_pressed(3)
	await create_timer(0.55).timeout
	_save("03-td-figures.png")
	td.queue_free()
	await create_timer(0.15).timeout


func _shot_td_wave_combat() -> void:
	var packed = load("res://scenes/td/td_battle.tscn")
	var td = packed.instantiate()
	root.add_child(td)
	await create_timer(0.6).timeout
	td.selected_unit_id = "unit_tiebi"
	td._on_slot_pressed(0)
	td.selected_unit_id = "unit_feidao"
	td._on_slot_pressed(1)
	td.selected_unit_id = "unit_qinggong"
	td._on_slot_pressed(2)
	if td.has_method("_on_start_wave"):
		td._on_start_wave()
	await create_timer(2.0).timeout
	_save("04-td-wave-figures.png")
	td.queue_free()
	await create_timer(0.15).timeout


func _shot_closeups() -> void:
	var host := Control.new()
	host.set_anchors_preset(Control.PRESET_FULL_RECT)
	host.size = Vector2(720, 1280)
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.04, 0.09, 0.08, 1.0)
	host.add_child(bg)
	root.add_child(host)
	var cdb = root.get_node_or_null("ContentDB")
	var ids := ["unit_qinggong", "unit_mulan", "unit_feidao", "unit_zhaoyun", "enemy_bandit", "enemy_runner"]
	var x0 := 40.0
	for i in ids.size():
		var u: Dictionary = {}
		if cdb:
			if str(ids[i]).begins_with("enemy_"):
				u = cdb.get_enemy(ids[i])
			else:
				u = cdb.get_unit(ids[i])
		var fig: Control
		if str(ids[i]).begins_with("enemy_"):
			fig = VF.enemy_node(u if not u.is_empty() else {"id": ids[i], "name": "?", "color": "#a0522d", "tags": []}, Vector2(150, 195))
		else:
			fig = VF.unit_node(u if not u.is_empty() else {"id": ids[i], "name": "?", "role": "dps", "color": "#6a8f71"}, Vector2(150, 195))
		fig.position = Vector2(x0 + (i % 3) * 220.0, 120.0 + int(i / 3) * 420.0)
		host.add_child(fig)
		VF.idle_bob(fig, 4.0, 2.0)
		VF.figure_attack_pose(fig, Vector2(1, -0.2))
	await create_timer(0.9).timeout
	_save("07-closeups-figures.png")
	host.queue_free()
	await create_timer(0.15).timeout


func _shot_portrait_grid() -> void:
	var host := Control.new()
	host.set_anchors_preset(Control.PRESET_FULL_RECT)
	host.size = Vector2(720, 1280)
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.04, 0.09, 0.08, 1.0)
	host.add_child(bg)
	root.add_child(host)
	var cdb = root.get_node_or_null("ContentDB")
	var ids := ["unit_qinggong", "unit_mulan", "unit_feidao", "unit_tiebi", "unit_yishi", "unit_zhaoyun", "unit_mingwang", "unit_linchong"]
	for i in ids.size():
		var u: Dictionary = cdb.get_unit(ids[i]) if cdb else {}
		if u.is_empty():
			u = {"id": ids[i], "name": "?", "role": "dps", "color": "#6a8f71", "faction": "?"}
		var card := VF.portrait_card(u, Vector2(150, 190), false, false)
		card.position = Vector2(28.0 + (i % 4) * 172.0, 80.0 + int(i / 4) * 280.0)
		host.add_child(card)
	await create_timer(0.7).timeout
	_save("08-portrait-grid.png")
	host.queue_free()
	await create_timer(0.15).timeout


func _shot_sheet_strip() -> void:
	## Show individual walk frames to prove multi-frame assets.
	var host := Control.new()
	host.set_anchors_preset(Control.PRESET_FULL_RECT)
	host.size = Vector2(720, 1280)
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.03, 0.07, 0.06, 1.0)
	host.add_child(bg)
	root.add_child(host)
	var title := Label.new()
	title.text = "Walk frames ×4  /  Attack frames ×3"
	title.position = Vector2(40, 36)
	title.size = Vector2(640, 40)
	host.add_child(title)
	var ids := ["unit_qinggong", "unit_mulan", "unit_feidao", "enemy_bandit", "enemy_runner"]
	var y := 90.0
	for id in ids:
		var path := "res://assets/textures/figures/sheets/%s_walk.png" % id
		if ResourceLoader.exists(path) or FileAccess.file_exists(path):
			var sheet: Texture2D = load(path)
			for fi in 4:
				var at := AtlasTexture.new()
				at.atlas = sheet
				at.region = Rect2(fi * 192, 0, 192, 256)
				var spr := TextureRect.new()
				spr.texture = at
				spr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				spr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				spr.size = Vector2(160, 210)
				spr.position = Vector2(40.0 + fi * 160.0, y)
				host.add_child(spr)
			y += 200.0
	await create_timer(0.55).timeout
	_save("09-sprite-sheets.png")
	host.queue_free()
	await create_timer(0.1).timeout


func _save(file: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	var path := OUT.path_join(file)
	img.save_png(path)
	print("wrote ", path)
