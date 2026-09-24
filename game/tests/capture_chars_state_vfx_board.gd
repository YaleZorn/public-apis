extends SceneTree
## Capture only the VFX studio board (aura / skill / 爆衣).

const OUT := "/cursor/stores/bc-71787b67-91e4-456d-b541-da2778721eaf/media/chars-state-vfx"
const VF := preload("res://scripts/util/visual_factory.gd")
const SV := preload("res://scripts/util/state_vfx.gd")


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
	var title := Label.new()
	title.text = "状态特效 · 光环 / 技能激发 / 爆衣"
	title.position = Vector2(40, 36)
	title.size = Vector2(640, 40)
	host.add_child(title)
	root.add_child(host)
	var cdb = root.get_node_or_null("ContentDB")
	var ids := ["unit_qinggong", "unit_mulan", "unit_feidao"]
	var labels := ["光环 Idle", "技能激发", "爆衣 Reveal"]
	var figs: Array = []
	for i in ids.size():
		var u: Dictionary = cdb.get_unit(ids[i]) if cdb else {}
		if u.is_empty():
			u = {"id": ids[i], "name": "?", "role": "dps", "color": "#6a8f71", "vfx": {"idle_aura": true, "reveal": "cloth_burst", "reveal_on": ["skill"], "skill_burst": "jade"}}
		var fig := VF.unit_node(u, Vector2(160, 210))
		fig.position = Vector2(50.0 + i * 220.0, 400.0)
		host.add_child(fig)
		VF.idle_bob(fig, 3.0, 2.0)
		figs.append(fig)
		var cap := Label.new()
		cap.text = labels[i]
		cap.position = Vector2(50.0 + i * 220.0, 640.0)
		cap.size = Vector2(180, 28)
		host.add_child(cap)
	await create_timer(0.35).timeout
	SV.show_idle_aura(figs[0], true, Color(0.45, 0.72, 0.95, 0.7))
	SV.show_buff_ring(figs[0], true, Color(0.85, 0.7, 0.3, 0.85))
	SV.trigger_skill(figs[1], host, "aoe_damage")
	SV.trigger_reveal(figs[2], "showcase", true)
	await create_timer(0.55).timeout
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(OUT.path_join("03-vfx-board.png"))
	print("BOARD_OK")
	quit(0)
