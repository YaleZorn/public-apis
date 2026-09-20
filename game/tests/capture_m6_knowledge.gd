extends SceneTree
## Capture M6 knowledge hub + quiz + content pack proof.

const OUT := "/cursor/stores/bc-71787b67-91e4-456d-b541-da2778721eaf/media/m6-knowledge-dlc"


func _initialize() -> void:
	DisplayServer.window_set_size(Vector2i(720, 1280))
	DirAccess.make_dir_recursive_absolute(OUT)
	call_deferred("_run")


func _run() -> void:
	var save_path := "user://kongfu_save_v0.json"
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(save_path)
	var gs = root.get_node_or_null("GameState")
	var cdb = root.get_node_or_null("ContentDB")
	if gs:
		gs.set("td_checkpoint", {})
		gs.set("explore_checkpoint", {})
		gs.set("arena_checkpoint", {})
		gs.set("tower_checkpoint", {})
		gs._init_defaults()
		gs.explore_hero_id = "unit_feidao"
		gs.silver_bank = 200
		gs.morning_quiz_done_day = -1
		gs.morning_buff_active = false
		gs.morning_buff_day = -1
		gs.knowledge_seen = []
		gs.knowledge_review_queue = []
		gs.knowledge_correct = {}
		gs.knowledge_due = {}
		# Seed some seen + one due review for UI
		gs.mark_knowledge_delivered("k_warmup", true)
		gs.mark_knowledge_delivered("k_hydration", true)
		gs.mark_knowledge_delivered("k_protein", false)
		gs.mark_knowledge_delivered("k_demo_trail_pace", true)
		gs.persist_lobby()
	await _shot_lobby(cdb)
	await _shot_journal()
	await _shot_quiz()
	await _shot_pack_proof(cdb)
	print("M6_SCREENSHOTS_OK ", OUT)
	quit(0)


func _shot_lobby(cdb) -> void:
	var packed = load("res://scenes/lobby/lobby.tscn")
	var node = packed.instantiate()
	root.add_child(node)
	await create_timer(0.9).timeout
	_save("01-lobby-packs.png")
	node.queue_free()
	await create_timer(0.12).timeout
	print("packs_loaded=", cdb.loaded_pack_ids if cdb else [])


func _shot_journal() -> void:
	var packed = load("res://scenes/knowledge/knowledge_hub.tscn")
	var hub = packed.instantiate()
	root.add_child(hub)
	await create_timer(0.85).timeout
	_save("02-knowledge-journal.png")
	hub._set_topic_filter("待复习")
	await create_timer(0.45).timeout
	_save("03-review-queue.png")
	hub.queue_free()
	await create_timer(0.12).timeout


func _shot_quiz() -> void:
	var packed = load("res://scenes/knowledge/knowledge_hub.tscn")
	var hub = packed.instantiate()
	root.add_child(hub)
	await create_timer(0.5).timeout
	hub._start_quiz()
	await create_timer(0.55).timeout
	_save("04-morning-quiz.png")
	hub.queue_free()
	await create_timer(0.12).timeout


func _shot_pack_proof(cdb) -> void:
	var packed = load("res://scenes/knowledge/knowledge_hub.tscn")
	var hub = packed.instantiate()
	root.add_child(hub)
	await create_timer(0.5).timeout
	# Force book to show demo pack entries by marking filter 全部 and scrolling via text rebuild
	hub._set_topic_filter("全部")
	await create_timer(0.4).timeout
	_save("05-pack-loaded-proof.png")
	# Also capture TD wave card briefly
	hub.queue_free()
	await create_timer(0.12).timeout
	var card_packed = load("res://scenes/knowledge/knowledge_card.tscn")
	var layer = card_packed.instantiate()
	root.add_child(layer)
	layer.present("k_demo_trail_pace")
	await create_timer(0.7).timeout
	_save("06-inrun-card-demo.png")
	layer.queue_free()
	print("demo_unit=", cdb.get_unit("unit_mulan").get("name", "?") if cdb else "?")
	print("demo_gear=", cdb.get_gear("gear_demo_trail_charm").get("name", "?") if cdb else "?")
	print("knowledge_count=", cdb.knowledge_list.size() if cdb else 0)


func _save(name: String) -> void:
	var img := get_root().get_viewport().get_texture().get_image()
	img.save_png("%s/%s" % [OUT, name])
	print("saved ", name)
