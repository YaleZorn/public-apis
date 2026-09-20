extends SceneTree
## Headless gameplay smoke: Idle claim/train + TD place/wave (M1+M2).

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
	print("GAMEPLAY_SMOKE_OK")
	quit(0)


func _smoke_idle() -> bool:
	var gs = root.get_node_or_null("GameState")
	if gs == null:
		push_error("GameState missing")
		return false
	# Simulate offline time so claim has something to do.
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
	_td._on_start_wave()
	await create_timer(2.5).timeout
	print("wave_running=", _td.wave_running, " enemies=", _td.enemies_alive, " lives=", _td.lives)
	if not FileAccess.file_exists("user://kongfu_save_v0.json"):
		push_error("expected checkpoint save")
		return false
	print("td_ok flank_pts=", _td.flank_path_points.size())
	_td.queue_free()
	return true
