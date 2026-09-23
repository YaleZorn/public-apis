extends SceneTree
## Capture portrait screenshots for Project store media (art ship).

const OUT := "/cursor/stores/bc-71787b67-91e4-456d-b541-da2778721eaf/media/art-ship"


func _initialize() -> void:
	DisplayServer.window_set_size(Vector2i(720, 1280))
	DirAccess.make_dir_recursive_absolute(OUT)
	call_deferred("_run")


func _run() -> void:
	# Wipe save + clear in-memory checkpoints (autoload may have already loaded).
	var save_path := "user://kongfu_save_v0.json"
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(save_path)
	var gs := root.get_node_or_null("GameState")
	if gs:
		gs.set("td_checkpoint", {})
		gs.set("explore_checkpoint", {})
	await _shot("res://scenes/shell/title_screen.tscn", "01-title.png", 0.9)
	# Lobby already paints full 6-card roster (locked dimmed) for side-by-side check.
	await _shot("res://scenes/lobby/lobby.tscn", "02-lobby.png", 0.75)
	await _shot_td()
	await _shot("res://scenes/explore/explore_run.tscn", "04-explore.png", 0.9)
	await _shot("res://scenes/knowledge/knowledge_hub.tscn", "05-knowledge.png", 0.55)
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


func _shot_td() -> void:
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
	await create_timer(0.35).timeout
	td._on_start_wave()
	await create_timer(2.0).timeout
	_save("03-td.png")
	td.queue_free()
	await create_timer(0.15).timeout


func _save(file: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	var path := "%s/%s" % [OUT, file]
	img.save_png(path)
	print("saved ", path, " ", img.get_width(), "x", img.get_height())
