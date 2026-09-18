extends SceneTree
## Headless gameplay smoke: place units, start wave, tick briefly, save checkpoint.

var _td: Node = null
var _frames := 0


func _initialize() -> void:
	call_deferred("_start")


func _start() -> void:
	var packed = load("res://scenes/td/td_battle.tscn")
	if packed == null:
		push_error("td scene missing")
		quit(1)
		return
	_td = packed.instantiate()
	root.add_child(_td)
	await create_timer(0.6).timeout
	_td.selected_unit_id = "unit_tiebi"
	_td._on_slot_pressed(0)
	_td.selected_unit_id = "unit_feidao"
	_td._on_slot_pressed(1)
	if _td.deployed.size() < 2:
		push_error("place failed deployed=%d" % _td.deployed.size())
		quit(1)
		return
	print("placed=", _td.deployed.size(), " silver=", _td.silver)
	_td._on_start_wave()
	await create_timer(2.5).timeout
	print("wave_running=", _td.wave_running, " enemies=", _td.enemies_alive, " lives=", _td.lives)
	if not FileAccess.file_exists("user://kongfu_save_v0.json"):
		push_error("expected checkpoint save")
		quit(1)
		return
	if int(_td.enemies_alive) <= 0 and _td.wave_running:
		# still spawning ok
		pass
	print("GAMEPLAY_SMOKE_OK")
	quit(0)
