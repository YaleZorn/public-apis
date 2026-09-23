extends SceneTree
## Multi-frame capture of figure idle/attack for 17+ motion video.

const OUT := "/cursor/stores/bc-71787b67-91e4-456d-b541-da2778721eaf/media/chars-17plus"
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
	var ids := ["unit_qinggong", "unit_mulan", "unit_feidao", "unit_zhaoyun"]
	var figs: Array = []
	for i in ids.size():
		var u: Dictionary = cdb.get_unit(ids[i]) if cdb else {}
		if u.is_empty():
			u = {"id": ids[i], "name": "?", "role": "dps", "color": "#6a8f71"}
		var fig := VF.unit_node(u, Vector2(150, 190))
		fig.position = Vector2(70.0 + (i % 2) * 280.0, 160.0 + int(i / 2) * 440.0)
		host.add_child(fig)
		VF.idle_bob(fig, 5.0, 1.6)
		figs.append(fig)
	for f in 16:
		if f == 4 or f == 10:
			for fig in figs:
				if is_instance_valid(fig):
					VF.figure_attack_pose(fig, Vector2(1 if f == 4 else -1, -0.3))
		await create_timer(0.12).timeout
		var img := root.get_viewport().get_texture().get_image()
		img.save_png("%s/motion-%02d.png" % [OUT, f])
	print("MOTION_FRAMES_OK")
	quit(0)
