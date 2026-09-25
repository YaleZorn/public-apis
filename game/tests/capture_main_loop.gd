extends SceneTree
## Capture v0.12 main-loop first session: title → TD → roster → next choice.

const OUT := "/cursor/stores/bc-71787b67-91e4-456d-b541-da2778721eaf/media/main-loop"


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
		gs.set("td_best_wave", 0)
		gs.set("total_td_clears", 0)
		gs.set("total_explore_clears", 0)
		gs.set("tower_floor_cleared", 0)
		gs.set("total_arena_runs", 0)
		gs.set("intro_stage", 0)
		gs.set("last_mvp_unit_id", "")
		gs._init_defaults()
		gs.meta_changed.emit()
		gs.checkpoint_changed.emit()
	await _shot("res://scenes/shell/title_screen.tscn", "01-title.png", 0.9)
	await _shot_td_prep()
	if gs:
		gs.set("td_checkpoint", {})
		gs.set("intro_stage", 1)
		gs.set("td_best_wave", 3)
		gs.set("last_mvp_unit_id", "unit_tiebi")
		gs.meta_changed.emit()
	await _shot("res://scenes/idle/idle_hub.tscn", "03-roster-mvp.png", 1.0)
	if gs:
		gs.set("intro_stage", 2)
		gs.meta_changed.emit()
	await _shot("res://scenes/lobby/lobby.tscn", "04-next-choice.png", 1.0)
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


func _shot_td_prep() -> void:
	var packed = load("res://scenes/td/td_battle.tscn")
	var td = packed.instantiate()
	root.add_child(td)
	await create_timer(0.8).timeout
	td.selected_unit_id = "unit_tiebi"
	td._on_slot_pressed(1)
	td.selected_unit_id = "unit_feidao"
	td._on_slot_pressed(3)
	await create_timer(0.5).timeout
	_save("02-td-place.png")
	if td.has_method("_on_start_wave"):
		td._on_start_wave()
		var waited := 0.0
		while waited < 12.0 and td.wave_running:
			await create_timer(0.4).timeout
			waited += 0.4
		await create_timer(0.6).timeout
		_save("02b-td-wave.png")
	td.queue_free()
	await create_timer(0.15).timeout


func _save(file: String) -> void:
	var img: Image = get_root().get_viewport().get_texture().get_image()
	var path := OUT.path_join(file)
	img.save_png(path)
	print("wrote ", path)
