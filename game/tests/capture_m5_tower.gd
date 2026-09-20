extends SceneTree
## Capture M5 爬塔: lobby, floor combat, clear / exclusive.

const OUT := "/cursor/stores/bc-71787b67-91e4-456d-b541-da2778721eaf/media/m5-tower"


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
		gs.set("arena_checkpoint", {})
		gs.set("tower_checkpoint", {})
		gs._init_defaults()
		gs.explore_hero_id = "unit_feidao"
		gs.silver_bank = 200
		gs.persist_lobby()
	await _shot_lobby()
	await _shot_floor1()
	await _shot_exclusive()
	print("M5_SCREENSHOTS_OK ", OUT)
	quit(0)


func _shot_lobby() -> void:
	var packed = load("res://scenes/lobby/lobby.tscn")
	var node = packed.instantiate()
	root.add_child(node)
	await create_timer(0.85).timeout
	_save("01-lobby-tower.png")
	node.queue_free()
	await create_timer(0.12).timeout


func _shot_floor1() -> void:
	var packed = load("res://scenes/tower/tower_run.tscn")
	var tw = packed.instantiate()
	root.add_child(tw)
	await create_timer(1.0).timeout
	_save("02-tower-floor1.png")
	await create_timer(1.5).timeout
	if tw.ring:
		tw.ring.cast_skill()
	await create_timer(0.8).timeout
	_save("03-tower-combat.png")
	# Clear for between-floor UI.
	for e in tw.ring.enemies.duplicate():
		e.hp = 0
		if e.node:
			e.node.queue_free()
	tw.ring.enemies.clear()
	tw.ring.combat_active = false
	tw._on_floor_cleared()
	await create_timer(0.6).timeout
	_save("04-tower-cleared.png")
	tw.queue_free()
	await create_timer(0.12).timeout


func _shot_exclusive() -> void:
	var packed = load("res://scenes/tower/tower_run.tscn")
	var tw = packed.instantiate()
	root.add_child(tw)
	await create_timer(0.5).timeout
	tw.floor_index = 5
	tw.between_floors = false
	tw.ring.clear_enemies()
	tw._enter_floor(false)
	await create_timer(1.0).timeout
	_save("05-tower-floor5.png")
	for e in tw.ring.enemies.duplicate():
		e.hp = 0
		if e.node:
			e.node.queue_free()
	tw.ring.enemies.clear()
	tw.ring.combat_active = false
	tw._on_floor_cleared()
	await create_timer(0.7).timeout
	_save("06-tower-exclusive.png")
	tw.queue_free()
	await create_timer(0.12).timeout


func _save(name: String) -> void:
	var img := get_root().get_viewport().get_texture().get_image()
	img.save_png("%s/%s" % [OUT, name])
	print("saved ", name)
