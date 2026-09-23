extends SceneTree
## Motion capture for state VFX: aura pulse · skill burst · 爆衣 swap.

const OUT := "/cursor/stores/bc-71787b67-91e4-456d-b541-da2778721eaf/media/chars-state-vfx"
const VF := preload("res://scripts/util/visual_factory.gd")
const SV := preload("res://scripts/util/state_vfx.gd")
const FRAMES := 36
const FPS := 12


func _initialize() -> void:
	DisplayServer.window_set_size(Vector2i(720, 1280))
	DirAccess.make_dir_recursive_absolute(OUT)
	call_deferred("_run")


func _run() -> void:
	var board := Control.new()
	board.size = Vector2(720, 1280)
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.035, 0.08, 0.07, 1.0)
	board.add_child(bg)
	var title := Label.new()
	title.text = "状态特效动态 · aura / skill / 爆衣"
	title.position = Vector2(48, 48)
	title.size = Vector2(620, 36)
	board.add_child(title)
	root.add_child(board)

	var u_aura: Dictionary = ContentDB.get_unit("unit_qinggong")
	var u_skill: Dictionary = ContentDB.get_unit("unit_feidao")
	var u_reveal: Dictionary = ContentDB.get_unit("unit_mulan")
	var fig_a := VF.unit_node(u_aura, Vector2(150, 195))
	var fig_s := VF.unit_node(u_skill, Vector2(150, 195))
	var fig_r := VF.unit_node(u_reveal, Vector2(150, 195))
	fig_a.position = Vector2(50, 420)
	fig_s.position = Vector2(280, 420)
	fig_r.position = Vector2(510, 420)
	board.add_child(fig_a)
	board.add_child(fig_s)
	board.add_child(fig_r)
	await create_timer(0.2).timeout
	SV.show_idle_aura(fig_a, true, Color(0.45, 0.7, 0.95, 0.75))
	SV.show_buff_ring(fig_a, true, Color(0.9, 0.75, 0.35, 0.85))
	VF.idle_bob(fig_a, 3.0, 2.0)
	VF.idle_bob(fig_s, 3.0, 2.2)
	VF.idle_bob(fig_r, 3.0, 2.4)

	var frame_dir := OUT.path_join("_frames")
	DirAccess.make_dir_recursive_absolute(frame_dir)
	for i in FRAMES:
		# Skill burst mid sequence
		if i == 8:
			SV.trigger_skill(fig_s, board, "aoe_damage")
		if i == 10:
			SV.trigger_crit(fig_s, board)
		# Reveal mid-late
		if i == 16:
			SV.trigger_reveal(fig_r, "motion", true)
		if i == 22:
			SV.trigger_skill(fig_r, board, "aoe_damage")
		await create_timer(1.0 / float(FPS)).timeout
		var img := root.get_viewport().get_texture().get_image()
		img.save_png(frame_dir.path_join("%03d.png" % i))
	print("MOTION_FRAMES_OK ", frame_dir)
	board.queue_free()
	quit(0)
