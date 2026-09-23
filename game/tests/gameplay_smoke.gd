extends SceneTree
## Headless gameplay smoke: Idle + TD + Explore + Arena + Tower + Knowledge/DLC (M1–M6).

var _td: Node = null


func _initialize() -> void:
	call_deferred("_start")


func _start() -> void:
	if not await _smoke_idle():
		quit(1)
		return
	if not await _smoke_td():
		quit(1)
		return
	if not await _smoke_explore():
		quit(1)
		return
	if not await _smoke_arena():
		quit(1)
		return
	if not await _smoke_tower():
		quit(1)
		return
	if not await _smoke_knowledge_packs():
		quit(1)
		return
	print("GAMEPLAY_SMOKE_OK")
	quit(0)


func _smoke_idle() -> bool:
	var gs = root.get_node_or_null("GameState")
	if gs == null:
		push_error("GameState missing")
		return false
	gs.idle_last_unix = Time.get_unix_time_from_system() - 3600.0
	gs.idle_pending_silver = 0.0
	gs.idle_pending_xiuwei = 0.0
	gs.idle_pending_materials = 0.0
	gs.refresh_idle_accrual()
	var pending: Dictionary = gs.pending_claim_totals()
	if int(pending.silver) <= 0 and int(pending.xiuwei) <= 0:
		push_error("idle accrual failed pending=%s" % pending)
		return false
	var before_silver: int = int(gs.silver_bank)
	var got: Dictionary = gs.claim_idle()
	if int(gs.silver_bank) < before_silver + int(got.silver):
		push_error("claim did not bank silver")
		return false
	gs.silver_bank = maxi(int(gs.silver_bank), 200)
	if not gs.assign_training(0, "unit_tiebi"):
		push_error("assign training failed")
		return false
	var lvl_before: int = int(gs.training_level.get("unit_tiebi", 0))
	gs.force_finish_training()
	var lvl_after: int = int(gs.training_level.get("unit_tiebi", 0))
	if lvl_after <= lvl_before:
		push_error("training level did not rise")
		return false
	if gs.effective_mastery("unit_tiebi") <= 0:
		push_error("effective mastery missing")
		return false
	var packed = load("res://scenes/idle/idle_hub.tscn")
	if packed == null:
		push_error("idle hub missing")
		return false
	var hub = packed.instantiate()
	root.add_child(hub)
	await create_timer(0.5).timeout
	hub.queue_free()
	await create_timer(0.1).timeout
	print("idle_ok pending_claimed=", got, " train_lvl=", lvl_after)
	return true


func _smoke_td() -> bool:
	var packed = load("res://scenes/td/td_battle.tscn")
	if packed == null:
		push_error("td scene missing")
		return false
	_td = packed.instantiate()
	root.add_child(_td)
	await create_timer(0.6).timeout
	_td.selected_unit_id = "unit_tiebi"
	_td._on_slot_pressed(0)
	_td.selected_unit_id = "unit_feidao"
	_td._on_slot_pressed(1)
	if _td.deployed.size() < 2:
		push_error("place failed deployed=%d" % _td.deployed.size())
		return false
	print("placed=", _td.deployed.size(), " silver=", _td.silver)
	if _td.wave_director == null:
		push_error("wave_director missing")
		return false
	if _td.flank_path_points.size() < 2:
		push_error("flank path missing")
		return false
	var juice = root.get_node_or_null("Juice")
	if juice == null or str(juice.get("_bgm_kind")) != "td":
		push_error("td should play td BGM got %s" % (str(juice.get("_bgm_kind")) if juice else "nojuice"))
		return false
	_td._on_start_wave()
	await create_timer(2.5).timeout
	print("wave_running=", _td.wave_running, " enemies=", _td.enemies_alive, " lives=", _td.lives)
	if not FileAccess.file_exists("user://kongfu_save_v0.json"):
		push_error("expected checkpoint save")
		return false
	print("td_ok flank_pts=", _td.flank_path_points.size())
	_td.queue_free()
	return true


func _smoke_explore() -> bool:
	var gs = root.get_node_or_null("GameState")
	if gs == null:
		push_error("GameState missing")
		return false
	gs.explore_checkpoint = {}
	gs.explore_hero_id = "unit_feidao"
	var packed = load("res://scenes/explore/explore_run.tscn")
	if packed == null:
		push_error("explore scene missing")
		return false
	var ex = packed.instantiate()
	root.add_child(ex)
	await create_timer(0.6).timeout
	if str(ex.node_id) != "settle":
		push_error("explore should start at settle, got %s" % ex.node_id)
		return false
	ex._travel_to("herb_slope")
	await create_timer(0.55).timeout
	if ex.bag.total_count() <= 0:
		push_error("gather did not fill bag")
		return false
	var bag_before: int = int(ex.bag.total_count())
	ex._travel_to("bandit_pass")
	await create_timer(0.5).timeout
	if not ex.ring.combat_active:
		push_error("combat did not start")
		return false
	for e in ex.ring.enemies.duplicate():
		e.hp = 0
		if e.node:
			e.node.queue_free()
	ex.ring.enemies.clear()
	ex.ring.combat_active = false
	ex._on_combat_cleared()
	await create_timer(0.25).timeout
	if not ex.node_completed:
		push_error("combat clear failed")
		return false
	if ex.ring == null:
		push_error("explore should use AutoCombatRing")
		return false
	ex._persist()
	if gs.explore_checkpoint.is_empty():
		push_error("explore checkpoint missing")
		return false
	if not gs.explore_checkpoint.has("bag"):
		push_error("checkpoint missing bag")
		return false
	ex._settle_run(1.0, "测试撤离", "smoke", false)
	await create_timer(0.2).timeout
	if gs.materials_inv.is_empty() and bag_before > 0:
		push_error("withdraw did not deposit materials")
		return false
	var kept: Dictionary = gs.deposit_run_bag({"mat_iron": 10}, 0.4)
	if int(kept.get("mat_iron", 0)) != 4:
		push_error("fail keep ratio expected 4 got %s" % kept)
		return false
	gs.add_material("mat_silk", 5)
	gs.add_material("mat_herb", 5)
	if not gs.can_craft("craft_linen_wrap") and "gear_linen_wrap" not in gs.gear_unlocked:
		push_error("craft setup failed")
		return false
	print("explore_ok bag_was=", bag_before, " inv=", gs.materials_summary())
	ex.queue_free()
	return true


func _smoke_arena() -> bool:
	var gs = root.get_node_or_null("GameState")
	if gs == null:
		push_error("GameState missing")
		return false
	gs.arena_checkpoint = {}
	gs.explore_hero_id = "unit_feidao"
	var mastery_before: int = int(gs.hero_mastery.get("unit_feidao", 0))
	var xiu_before: int = int(gs.xiuwei_bank)
	var packed = load("res://scenes/arena/arena_run.tscn")
	if packed == null:
		push_error("arena scene missing")
		return false
	var ar = packed.instantiate()
	root.add_child(ar)
	await create_timer(0.8).timeout
	if ar.ring == null:
		push_error("arena ring missing")
		return false
	# Force a kill + survival ticks.
	ar.survival_sec = 12.0
	ar.mastery_earned = 0
	ar.xiuwei_earned = 0
	ar._on_kill("enemy_bandit")
	ar.kills = 1
	ar.mastery_earned = 2
	ar.xiuwei_earned = 3
	if gs.arena_checkpoint.is_empty():
		push_error("arena soft checkpoint missing")
		return false
	ar._settle(true, "smoke", "test")
	await create_timer(0.25).timeout
	var mastery_after: int = int(gs.hero_mastery.get("unit_feidao", 0))
	if mastery_after < mastery_before + 2:
		push_error("arena mastery not applied %d→%d" % [mastery_before, mastery_after])
		return false
	if int(gs.xiuwei_bank) < xiu_before + 3:
		push_error("arena xiuwei not applied")
		return false
	if int(gs.total_arena_runs) < 1:
		push_error("arena run counter not bumped")
		return false
	print("arena_ok mastery=", mastery_after, " xiu=", gs.xiuwei_bank, " best=", gs.arena_best_sec)
	ar.queue_free()
	await create_timer(0.1).timeout
	return true


func _smoke_tower() -> bool:
	var gs = root.get_node_or_null("GameState")
	if gs == null:
		push_error("GameState missing")
		return false
	gs.tower_checkpoint = {}
	gs.tower_floor_cleared = 0
	gs.explore_hero_id = "unit_feidao"
	# Ensure exclusive not already unlocked for drop test.
	var cleaned: Array = []
	for g in gs.gear_unlocked:
		if str(g) != "gear_tower_blade":
			cleaned.append(g)
	gs.gear_unlocked = cleaned
	var packed = load("res://scenes/tower/tower_run.tscn")
	if packed == null:
		push_error("tower scene missing")
		return false
	var tw = packed.instantiate()
	root.add_child(tw)
	await create_timer(0.7).timeout
	if tw.floor_index != 1:
		push_error("tower should start floor 1 got %d" % tw.floor_index)
		return false
	if not tw.ring.combat_active:
		push_error("tower combat did not start")
		return false
	var juice = root.get_node_or_null("Juice")
	if juice == null or str(juice.get("_bgm_kind")) != "tower":
		push_error("tower should play tower BGM got %s" % (str(juice.get("_bgm_kind")) if juice else "nojuice"))
		return false
	# Clear floor 1.
	for e in tw.ring.enemies.duplicate():
		e.hp = 0
		if e.node:
			e.node.queue_free()
	tw.ring.enemies.clear()
	tw.ring.combat_active = false
	tw._on_floor_cleared()
	await create_timer(0.2).timeout
	if not tw.between_floors:
		push_error("tower not between floors after clear")
		return false
	if int(gs.tower_floor_cleared) < 1:
		push_error("tower_floor_cleared not set")
		return false
	if gs.tower_checkpoint.is_empty():
		push_error("tower checkpoint missing at floor boundary")
		return false
	# Jump to floor 5 exclusive roll (chance 1.0).
	tw.floor_index = 5
	tw.between_floors = false
	tw.ring.clear_enemies()
	tw.ring.spawn_enemies(["enemy_bandit"], 0.1, 0.1)
	for e2 in tw.ring.enemies.duplicate():
		e2.hp = 0
		if e2.node:
			e2.node.queue_free()
	tw.ring.enemies.clear()
	tw.ring.combat_active = false
	tw._on_floor_cleared()
	await create_timer(0.2).timeout
	if "gear_tower_blade" not in gs.gear_unlocked:
		push_error("tower exclusive gear not unlocked")
		return false
	var cdb = root.get_node_or_null("ContentDB")
	if cdb == null:
		push_error("ContentDB missing")
		return false
	var g: Dictionary = cdb.get_gear("gear_tower_blade")
	if not bool(g.get("exclusive", false)):
		push_error("exclusive flag missing on tower blade")
		return false
	print("tower_ok floor_cleared=", gs.tower_floor_cleared, " exclusive=", gs.gear_unlocked)
	tw.queue_free()
	return true


func _smoke_knowledge_packs() -> bool:
	var cdb = root.get_node_or_null("ContentDB")
	var gs = root.get_node_or_null("GameState")
	if cdb == null or gs == null:
		push_error("ContentDB/GameState missing")
		return false
	if cdb.knowledge_list.size() < 30:
		push_error("merged knowledge < 30 got %d" % cdb.knowledge_list.size())
		return false
	if not cdb.units.has("unit_mulan"):
		push_error("demo pack unit_mulan not merged")
		return false
	if not cdb.knowledge.has("k_demo_trail_pace"):
		push_error("demo knowledge not merged")
		return false
	if not cdb.gear.has("gear_demo_trail_charm"):
		push_error("demo gear not merged")
		return false
	if "demo_mountain" not in cdb.loaded_pack_ids:
		push_error("demo_mountain not in loaded_pack_ids %s" % str(cdb.loaded_pack_ids))
		return false
	gs.mark_knowledge_delivered("k_warmup", false)
	if "k_warmup" not in gs.knowledge_review_queue:
		push_error("wrong answer should enqueue review")
		return false
	gs.mark_knowledge_delivered("k_warmup", true)
	if not gs.knowledge_due.has("k_warmup"):
		push_error("correct answer should schedule spaced due")
		return false
	gs.complete_morning_quiz(3)
	if not gs.is_morning_buff_live():
		push_error("morning buff should be live after score>=2")
		return false
	var hub_packed = load("res://scenes/knowledge/knowledge_hub.tscn")
	if hub_packed == null:
		push_error("knowledge hub missing")
		return false
	var hub = hub_packed.instantiate()
	root.add_child(hub)
	await create_timer(0.45).timeout
	var juice = root.get_node_or_null("Juice")
	if juice == null or str(juice.get("_bgm_kind")) != "knowledge":
		push_error("knowledge hub should play knowledge BGM got %s" % (str(juice.get("_bgm_kind")) if juice else "nojuice"))
		hub.queue_free()
		return false
	hub.queue_free()
	await create_timer(0.1).timeout
	print("knowledge_packs_ok entries=", cdb.knowledge_list.size(), " packs=", cdb.loaded_pack_ids)
	return true
