extends SceneTree
## M3 搜打撤 demo sequence for external screen recorder.

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
		gs.explore_hero_id = "unit_feidao"
		gs.silver_bank = 200
		gs.materials_inv = {}
		gs.persist_lobby()
	# Lobby entry
	var lobby = load("res://scenes/lobby/lobby.tscn").instantiate()
	root.add_child(lobby)
	await create_timer(2.0).timeout
	lobby.queue_free()
	await create_timer(0.2).timeout
	# Explore settle + map
	var ex = load("res://scenes/explore/explore_run.tscn").instantiate()
	root.add_child(ex)
	await create_timer(2.0).timeout
	# Gather
	ex._travel_to("herb_slope")
	await create_timer(2.2).timeout
	# Combat
	ex._travel_to("bandit_pass")
	await create_timer(1.5).timeout
	if ex.combat_active:
		ex._cast_skill()
	await create_timer(2.0).timeout
	# Force clear for readable withdraw
	for e in ex.enemies.duplicate():
		e.hp = 0
		if e.node:
			e.node.queue_free()
	ex.enemies.clear()
	if ex.combat_active:
		ex._on_combat_cleared()
	await create_timer(1.8).timeout
	# Back to settle
	ex._travel_to("settle")
	await create_timer(2.0).timeout
	# Withdraw settle to lobby overlay
	ex._settle_run(1.0, "撤离结算", "搜打撤演示 · 背包全额入库", false)
	await create_timer(2.5).timeout
	print("M3_VIDEO_SEQ_OK")
	quit(0)
