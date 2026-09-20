extends SceneTree
## Capture M1 TD evidence: prep, mid-wave top-down, flank ambush, lobby entry.

const OUT := "/cursor/stores/bc-71787b67-91e4-456d-b541-da2778721eaf/media/m1-td"


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
	await _shot("res://scenes/lobby/lobby.tscn", "01-lobby-entry.png", 0.8)
	await _shot_td_prep()
	await _shot_td_midwave()
	await _shot_td_flank()
	print("M1_SCREENSHOTS_OK ", OUT)
	quit(0)


func _shot(scene_path: String, file: String, wait: float) -> void:
	var packed = load(scene_path)
	var node: Node = packed.instantiate()
	root.add_child(node)
	await create_timer(wait).timeout
	_save(file)
	node.queue_free()
	await create_timer(0.15).timeout


func _shot_td_prep() -> void:
	var packed = load("res://scenes/td/td_battle.tscn")
	var td = packed.instantiate()
	root.add_child(td)
	await create_timer(0.75).timeout
	td.selected_unit_id = "unit_tiebi"
	td._on_slot_pressed(0)
	td.selected_unit_id = "unit_feidao"
	td._on_slot_pressed(1)
	td.selected_unit_id = "unit_qinggong"
	td._on_slot_pressed(2)
	await create_timer(0.4).timeout
	_save("02-prep.png")
	td.queue_free()
	await create_timer(0.15).timeout


func _shot_td_midwave() -> void:
	var packed = load("res://scenes/td/td_battle.tscn")
	var td = packed.instantiate()
	root.add_child(td)
	await create_timer(0.7).timeout
	td.selected_unit_id = "unit_tiebi"
	td._on_slot_pressed(0)
	td.selected_unit_id = "unit_feidao"
	td._on_slot_pressed(1)
	td.selected_unit_id = "unit_qinggong"
	td._on_slot_pressed(3)
	td._on_start_wave()
	await create_timer(2.4).timeout
	_save("03-mid-wave-top-down.png")
	td.queue_free()
	await create_timer(0.15).timeout


func _shot_td_flank() -> void:
	var packed = load("res://scenes/td/td_battle.tscn")
	var td = packed.instantiate()
	root.add_child(td)
	await create_timer(0.7).timeout
	# Jump to wave 3 (0-based index 2) which seeds flank ambush.
	td.wave_index = 2
	td._refresh_hud()
	td._update_wave_preview()
	td.selected_unit_id = "unit_tiebi"
	td._on_slot_pressed(0)
	td.selected_unit_id = "unit_feidao"
	td._on_slot_pressed(1)
	td.selected_unit_id = "unit_qinggong"
	td._on_slot_pressed(2)
	td.selected_unit_id = "unit_yishi"
	td._on_slot_pressed(4)
	td._on_start_wave()
	# Wait until flank pack (delay 1.5+) is on field.
	await create_timer(3.6).timeout
	_save("04-flank-ambush.png")
	td.queue_free()
	await create_timer(0.1).timeout


func _save(file: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	var path := "%s/%s" % [OUT, file]
	img.save_png(path)
	print("saved ", path, " ", img.get_width(), "x", img.get_height())
