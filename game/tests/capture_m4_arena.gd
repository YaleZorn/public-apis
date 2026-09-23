extends SceneTree
## Capture M4 演武场: lobby entry, survival combat, settle.

const OUT := "/cursor/stores/bc-71787b67-91e4-456d-b541-da2778721eaf/media/m4-arena"


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
	await _shot_arena_mid()
	await _shot_settle()
	print("M4_SCREENSHOTS_OK ", OUT)
	quit(0)


func _shot_lobby() -> void:
	var packed = load("res://scenes/lobby/lobby.tscn")
	var node = packed.instantiate()
	root.add_child(node)
	await create_timer(0.85).timeout
	_save("01-lobby-arena.png")
	node.queue_free()
	await create_timer(0.12).timeout


func _shot_arena_mid() -> void:
	var packed = load("res://scenes/arena/arena_run.tscn")
	var ar = packed.instantiate()
	root.add_child(ar)
	await create_timer(1.2).timeout
	_save("02-arena-start.png")
	await create_timer(2.5).timeout
	if ar.has_method("_cast_skill") == false and ar.ring:
		ar.ring.cast_skill()
	_save("03-arena-ramp.png")
	ar.queue_free()
	await create_timer(0.12).timeout


func _shot_settle() -> void:
	var packed = load("res://scenes/arena/arena_run.tscn")
	var ar = packed.instantiate()
	root.add_child(ar)
	await create_timer(1.0).timeout
	ar.survival_sec = 45.0
	ar.kills = 8
	ar.mastery_earned = 10
	ar.xiuwei_earned = 12
	ar._settle(true, "演武结算", "截图演示下场结算。")
	await create_timer(0.7).timeout
	_save("04-arena-settle.png")
	ar.queue_free()
	await create_timer(0.12).timeout


func _save(name: String) -> void:
	var img := get_root().get_viewport().get_texture().get_image()
	img.save_png("%s/%s" % [OUT, name])
	print("saved ", name)
