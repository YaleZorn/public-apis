extends SceneTree
## Capture portrait screenshots for Project store media.

const OUT := "/cursor/stores/bc-71787b67-91e4-456d-b541-da2778721eaf/media/playable-chapter"
const SHOTS := [
	{"scene": "res://scenes/shell/title_screen.tscn", "file": "01-title.png", "wait": 0.5},
	{"scene": "res://scenes/lobby/lobby.tscn", "file": "02-lobby.png", "wait": 0.4},
	{"scene": "res://scenes/td/td_battle.tscn", "file": "03-td-chapter.png", "wait": 0.6},
	{"scene": "res://scenes/explore/explore_run.tscn", "file": "04-explore.png", "wait": 0.5},
	{"scene": "res://scenes/knowledge/knowledge_hub.tscn", "file": "05-knowledge.png", "wait": 0.4},
]
var _i := 0
var _node: Node = null


func _initialize() -> void:
	DisplayServer.window_set_size(Vector2i(405, 720))
	call_deferred("_step")


func _step() -> void:
	if _node:
		_node.queue_free()
		_node = null
	if _i >= SHOTS.size():
		print("SCREENSHOTS_OK ", OUT)
		quit(0)
		return
	var job: Dictionary = SHOTS[_i]
	_i += 1
	var packed = load(str(job.scene))
	_node = packed.instantiate()
	root.add_child(_node)
	await create_timer(float(job.wait)).timeout
	var img := root.get_viewport().get_texture().get_image()
	var path := "%s/%s" % [OUT, job.file]
	img.save_png(path)
	print("saved ", path)
	_step()
