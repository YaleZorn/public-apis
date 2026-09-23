extends SceneTree
## Short motion capture for state VFX (20 frames @ 10fps).

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
	bg.color = Color(0.035, 0.08, 0.07, 1.0)
	host.add_child(bg)
	var title := Label.new()
	title.text = "状态特效动态 · aura / skill / 爆衣"
	title.position = Vector2(48, 48)
	title.size = Vector2(620, 36)
	host.add_child(title)
	root.add_child(host)
	var cdb = root.get_node_or_null("ContentDB")
	var ids := ["unit_qinggong", "unit_feidao", "unit_mulan"]
	var figs: Array = []
	for i in ids.size():
		var u: Dictionary = cdb.get_unit(ids[i]) if cdb else {"id": ids[i], "name": "?", "role": "dps", "color": "#6a8f71"}
		var fig := VF.unit_node(u, Vector2(150, 195))
		fig.position = Vector2(50.0 + i * 230.0, 420.0)
		host.add_child(fig)
		VF.idle_bob(fig, 3.0, 1.8 + i * 0.2)
		figs.append(fig)
	await create_timer(0.2).timeout
	SV.show_idle_aura(figs[0], true, Color(0.45, 0.7, 0.95, 0.75))
	SV.show_buff_ring(figs[0], true, Color(0.9, 0.75, 0.35, 0.85))
	for f in 20:
		if f == 5:
			SV.trigger_skill(figs[1], host, "aoe_damage")
		if f == 7:
			SV.trigger_crit(figs[1], host)
		if f == 10:
			SV.trigger_reveal(figs[2], "motion", true)
		if f == 14:
			SV.trigger_skill(figs[2], host, "aoe_damage")
		await create_timer(0.1).timeout
		var img := root.get_viewport().get_texture().get_image()
		img.save_png("%s/motion-%02d.png" % [OUT, f])
	print("MOTION_FRAMES_OK")
	quit(0)
