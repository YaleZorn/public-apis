extends SceneTree
## Multi-frame capture of v0.9.8 limb/pose + larger TD figures for motion video.

const OUT := "/cursor/stores/bc-71787b67-91e4-456d-b541-da2778721eaf/media/chars-refine"
const VF := preload("res://scripts/util/visual_factory.gd")


func _initialize() -> void:
	DisplayServer.window_set_size(Vector2i(720, 1280))
	DirAccess.make_dir_recursive_absolute(OUT)
	call_deferred("_run")


func _run() -> void:
	var host := Control.new()
	host.size = Vector2(720, 1280)
	var bg := ColorRect.new()
	bg.size = Vector2(720, 1280)
	bg.color = Color(0.04, 0.09, 0.08, 1.0)
	host.add_child(bg)
	root.add_child(host)
	var cdb = root.get_node_or_null("ContentDB")
	var unit_ids := ["unit_qinggong", "unit_mulan", "unit_feidao", "unit_tiebi"]
	var enemy_ids := ["enemy_bandit", "enemy_runner"]
	var figs: Array = []
	for i in unit_ids.size():
		var u: Dictionary = cdb.get_unit(unit_ids[i]) if cdb else {}
		if u.is_empty():
			u = {"id": unit_ids[i], "name": "?", "role": "dps", "color": "#6a8f71"}
		var fig := VF.unit_node(u, Vector2(160, 210))
		fig.position = Vector2(50.0 + (i % 2) * 300.0, 80.0 + int(i / 2) * 320.0)
		host.add_child(fig)
		VF.idle_bob(fig, 3.0, 1.8)
		figs.append(fig)
	for i in enemy_ids.size():
		var e: Dictionary = cdb.get_enemy(enemy_ids[i]) if cdb else {}
		if e.is_empty():
			e = {"id": enemy_ids[i], "name": "?", "color": "#a0522d", "tags": ["fast"] if i == 1 else []}
		var fig := VF.enemy_node(e, Vector2(140, 180))
		fig.position = Vector2(80.0 + i * 280.0, 780.0)
		host.add_child(fig)
		VF.idle_bob(fig, 2.5, 1.4)
		figs.append(fig)
	for f in 20:
		if f == 5 or f == 12:
			for fig in figs:
				if is_instance_valid(fig):
					VF.figure_attack_pose(fig, Vector2(1 if f == 5 else -1, -0.3))
		await create_timer(0.1).timeout
		var img := root.get_viewport().get_texture().get_image()
		img.save_png("%s/motion-%02d.png" % [OUT, f])
	print("MOTION_FRAMES_OK")
	quit(0)
