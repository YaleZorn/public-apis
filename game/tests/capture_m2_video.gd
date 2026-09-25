extends SceneTree
## Short Idle demo sequence for video capture (no file save — external recorder).

func _initialize() -> void:
	DisplayServer.window_set_size(Vector2i(720, 1280))
	call_deferred("_run")

func _run() -> void:
	var save_path := "user://kongfu_save_v0.json"
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(save_path)
	var gs = root.get_node_or_null("GameState")
	if gs:
		gs._init_defaults()
		gs.idle_last_unix = Time.get_unix_time_from_system() - 7200.0
		gs.refresh_idle_accrual()
		gs.silver_bank = 250
		gs.persist_lobby()
	var lobby = load("res://scenes/lobby/lobby.tscn").instantiate()
	root.add_child(lobby)
	await create_timer(2.0).timeout
	lobby.queue_free()
	await create_timer(0.2).timeout
	var hub = load("res://scenes/idle/idle_hub.tscn").instantiate()
	root.add_child(hub)
	await create_timer(1.5).timeout
	hub._selected_id = "unit_feidao"
	hub._refresh()
	await create_timer(1.2).timeout
	gs.claim_idle()
	hub._refresh()
	await create_timer(1.0).timeout
	hub._selected_id = "unit_tiebi"
	gs.assign_training(0, "unit_tiebi")
	hub._selected_id = "unit_qinggong"
	gs.assign_training(1, "unit_qinggong")
	hub._refresh()
	await create_timer(1.5).timeout
	gs.force_finish_training()
	hub._refresh()
	await create_timer(2.0).timeout
	print("M2_VIDEO_SEQ_OK")
	quit(0)
