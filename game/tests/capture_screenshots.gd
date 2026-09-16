extends SceneTree
## Capture portrait screenshots for Project store media.

const OUT := "/cursor/stores/bc-71787b67-91e4-456d-b541-da2778721eaf/media/playable-chapter"


func _initialize() -> void:
	DisplayServer.window_set_size(Vector2i(405, 720))
	call_deferred("_run")


func _run() -> void:
	await _shot("res://scenes/shell/title_screen.tscn", "01-title.png", 0.5)
	await _shot("res://scenes/lobby/lobby.tscn", "02-lobby.png", 0.4)
	await _shot_td()
	await _shot("res://scenes/explore/explore_run.tscn", "04-explore.png", 0.55)
	await _shot("res://scenes/knowledge/knowledge_hub.tscn", "05-knowledge.png", 0.4)
	print("SCREENSHOTS_OK ", OUT)
	quit(0)


func _shot(scene_path: String, file: String, wait: float) -> void:
	var packed = load(scene_path)
	var node: Node = packed.instantiate()
	root.add_child(node)
	await create_timer(wait).timeout
	_save(file)
	node.queue_free()
	await create_timer(0.1).timeout


func _shot_td() -> void:
	var packed = load("res://scenes/td/td_battle.tscn")
	var td = packed.instantiate()
	root.add_child(td)
	await create_timer(0.5).timeout
	td.selected_unit_id = "unit_tiebi"
	td._on_slot_pressed(0)
	td.selected_unit_id = "unit_feidao"
	td._on_slot_pressed(1)
	td.selected_unit_id = "unit_qinggong"
	td._on_slot_pressed(2)
	await create_timer(0.2).timeout
	td._on_start_wave()
	await create_timer(1.2).timeout
	_save("03-td-chapter.png")
	td.queue_free()
	await create_timer(0.1).timeout


func _save(file: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	var path := "%s/%s" % [OUT, file]
	img.save_png(path)
	print("saved ", path)
