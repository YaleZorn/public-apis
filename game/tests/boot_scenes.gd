extends SceneTree

var _scenes := [
	"res://scenes/shell/title_screen.tscn",
	"res://scenes/lobby/lobby.tscn",
	"res://scenes/idle/idle_hub.tscn",
	"res://scenes/td/td_battle.tscn",
	"res://scenes/explore/explore_run.tscn",
	"res://scenes/knowledge/knowledge_hub.tscn",
]
var _i := 0
var _current: Node = null


func _initialize() -> void:
	call_deferred("_step")


func _step() -> void:
	if _current:
		_current.queue_free()
		_current = null
	if _i >= _scenes.size():
		print("SCENES_OK")
		quit(0)
		return
	var path: String = _scenes[_i]
	_i += 1
	var packed = load(path)
	if packed == null:
		push_error("LOAD_FAIL %s" % path)
		print("LOAD_FAIL ", path)
		quit(1)
		return
	_current = packed.instantiate()
	root.add_child(_current)
	print("INST_OK ", path)
	# give _ready / awaits a few frames
	await create_timer(0.4).timeout
	_step()
