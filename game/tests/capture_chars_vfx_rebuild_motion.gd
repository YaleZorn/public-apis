extends SceneTree
## Motion frames for v0.10.0 VFX rebuild (24 frames @ 10fps).

const OUT := "/cursor/stores/bc-71787b67-91e4-456d-b541-da2778721eaf/media/chars-vfx-rebuild"
const VF := preload("res://scripts/util/visual_factory.gd")
const SV := preload("res://scripts/util/state_vfx.gd")
const AP := preload("res://scripts/util/art_palette.gd")


func _initialize() -> void:
	DisplayServer.window_set_size(Vector2i(720, 1280))
	DirAccess.make_dir_recursive_absolute(OUT)
	call_deferred("_run")


func _run() -> void:
	var host := Control.new()
	host.size = Vector2(720, 1280)
	var bg := ColorRect.new()
	bg.size = Vector2(720, 1280)
	bg.color = Color(0.03, 0.08, 0.07, 1.0)
	host.add_child(bg)
	for i in 3:
		var veil := ColorRect.new()
		veil.size = Vector2(720, 260)
		veil.position = Vector2(0, 200 + i * 280)
		veil.color = Color(0.09, 0.16, 0.14, 0.2)
		host.add_child(veil)
	var title := Label.new()
	title.text = "v0.10 特效动态 · aura / skill / 爆衣"
	title.position = Vector2(40, 44)
	title.size = Vector2(640, 36)
	AP.apply_label(title, 22, AP.PAPER_INK)
	host.add_child(title)
	root.add_child(host)
	var cdb = root.get_node_or_null("ContentDB")
	var ids := ["unit_qinggong", "unit_mulan", "unit_feidao"]
	var figs: Array = []
	for i in ids.size():
		var u: Dictionary = cdb.get_unit(ids[i]) if cdb else {"id": ids[i], "name": "?", "role": "dps", "color": "#6a8f71"}
		var fig := VF.unit_node(u, Vector2(160, 210))
		fig.position = Vector2(40.0 + i * 230.0, 400.0)
		host.add_child(fig)
		VF.idle_bob(fig, 3.0, 1.8 + i * 0.2)
		figs.append(fig)
	await create_timer(0.25).timeout
	SV.show_idle_aura(figs[0], true, Color(0.42, 0.78, 0.68, 0.85))
	SV.show_buff_ring(figs[0], true, Color(0.92, 0.74, 0.32, 0.9))
	for f in 24:
		if f == 4:
			SV.trigger_skill(figs[1], host, "aoe_damage")
		if f == 6:
			SV.trigger_reveal(figs[1], "motion", true)
		if f == 11:
			SV.trigger_skill(figs[2], host, "blade")
		if f == 13:
			SV.trigger_reveal(figs[2], "motion", true)
		if f == 18:
			SV.trigger_skill(figs[0], host, "heal")
		await create_timer(0.1).timeout
		var img := root.get_viewport().get_texture().get_image()
		img.save_png("%s/motion-%02d.png" % [OUT, f])
	print("MOTION_FRAMES_OK")
	quit(0)
