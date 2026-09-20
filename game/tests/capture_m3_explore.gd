extends SceneTree
## Capture M3 explore 搜打撤: map, combat, withdraw settle.

const OUT := "/cursor/stores/bc-71787b67-91e4-456d-b541-da2778721eaf/media/m3-explore"


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
		gs._init_defaults()
		gs.explore_hero_id = "unit_feidao"
		gs.silver_bank = 200
		gs.persist_lobby()
	await _shot_lobby()
	await _shot_settle_map()
	await _shot_combat()
	await _shot_withdraw()
	print("M3_SCREENSHOTS_OK ", OUT)
	quit(0)


func _shot_lobby() -> void:
	var packed = load("res://scenes/lobby/lobby.tscn")
	var node = packed.instantiate()
	root.add_child(node)
	await create_timer(0.85).timeout
	_save("01-lobby-explore.png")
	node.queue_free()
	await create_timer(0.12).timeout


func _shot_settle_map() -> void:
	var packed = load("res://scenes/explore/explore_run.tscn")
	var ex = packed.instantiate()
	root.add_child(ex)
	await create_timer(0.9).timeout
	_save("02-map-settle.png")
	# Travel to gather for material feel.
	if ex.has_method("_travel_to"):
		ex._travel_to("herb_slope")
		await create_timer(0.7).timeout
		_save("03-gather-search.png")
	ex.queue_free()
	await create_timer(0.12).timeout


func _shot_combat() -> void:
	var packed = load("res://scenes/explore/explore_run.tscn")
	var ex = packed.instantiate()
	root.add_child(ex)
	await create_timer(0.5).timeout
	ex._travel_to("bandit_pass")
	await create_timer(1.0).timeout
	_save("04-combat.png")
	# Clear via skill spam / auto for a beat.
	await create_timer(2.2).timeout
	if ex.combat_active and ex.has_method("_cast_skill"):
		ex._cast_skill()
	await create_timer(1.5).timeout
	_save("05-combat-cleared-or-mid.png")
	ex.queue_free()
	await create_timer(0.12).timeout


func _shot_withdraw() -> void:
	var packed = load("res://scenes/explore/explore_run.tscn")
	var ex = packed.instantiate()
	root.add_child(ex)
	await create_timer(0.5).timeout
	ex.bag.add("mat_herb", 3)
	ex.bag.add("mat_iron", 2)
	ex._refresh()
	ex._enter_node()
	await create_timer(0.7).timeout
	_save("06-withdraw-settle.png")
	ex.queue_free()
	await create_timer(0.12).timeout


func _save(file: String) -> void:
	var img := get_root().get_viewport().get_texture().get_image()
	var path := "%s/%s" % [OUT, file]
	img.save_png(path)
	print("saved ", path)
