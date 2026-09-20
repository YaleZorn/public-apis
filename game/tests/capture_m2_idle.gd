extends SceneTree
## Capture M2 Idle evidence: lobby hub entry, roster detail, claim/training.

const OUT := "/cursor/stores/bc-71787b67-91e4-456d-b541-da2778721eaf/media/m2-idle"


func _initialize() -> void:
	DisplayServer.window_set_size(Vector2i(720, 1280))
	DirAccess.make_dir_recursive_absolute(OUT)
	call_deferred("_run")


func _run() -> void:
	var save_path := "user://kongfu_save_v0.json"
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(save_path)
	var gs = root.get_node_or_null("GameState")
	if gs:
		gs.set("td_checkpoint", {})
		gs.set("explore_checkpoint", {})
		# Fresh meta with pending + silver for training demo.
		gs._init_defaults()
		gs.idle_last_unix = Time.get_unix_time_from_system() - 7200.0
		gs.idle_pending_silver = 0.0
		gs.idle_pending_xiuwei = 0.0
		gs.idle_pending_materials = 0.0
		gs.refresh_idle_accrual()
		gs.silver_bank = 200
		gs.persist_lobby()
	await _shot("res://scenes/lobby/lobby.tscn", "01-lobby-idle-hub.png", 0.9)
	await _shot_idle_roster()
	await _shot_idle_claim_train()
	print("M2_SCREENSHOTS_OK ", OUT)
	quit(0)


func _shot(scene_path: String, file: String, wait: float) -> void:
	var packed = load(scene_path)
	var node: Node = packed.instantiate()
	root.add_child(node)
	await create_timer(wait).timeout
	_save(file)
	node.queue_free()
	await create_timer(0.15).timeout


func _shot_idle_roster() -> void:
	var packed = load("res://scenes/idle/idle_hub.tscn")
	var hub = packed.instantiate()
	root.add_child(hub)
	await create_timer(0.7).timeout
	hub._selected_id = "unit_feidao"
	hub._refresh()
	await create_timer(0.35).timeout
	_save("02-roster-detail.png")
	hub.queue_free()
	await create_timer(0.15).timeout


func _shot_idle_claim_train() -> void:
	var gs = root.get_node_or_null("GameState")
	var packed = load("res://scenes/idle/idle_hub.tscn")
	var hub = packed.instantiate()
	root.add_child(hub)
	await create_timer(0.6).timeout
	if gs:
		gs.claim_idle()
		hub._selected_id = "unit_tiebi"
		gs.assign_training(0, "unit_tiebi")
		hub._selected_id = "unit_qinggong"
		gs.assign_training(1, "unit_qinggong")
		gs.force_finish_training()
		hub._refresh()
	await create_timer(0.5).timeout
	_save("03-claim-training.png")
	hub.queue_free()
	await create_timer(0.15).timeout


func _save(file: String) -> void:
	var img := get_root().get_viewport().get_texture().get_image()
	var path := "%s/%s" % [OUT, file]
	img.save_png(path)
	print("saved ", path)
