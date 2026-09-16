extends Node
## Audio/settings persisted in save meta.

signal settings_changed

var master_volume: float = 1.0
var sfx_volume: float = 1.0
var music_volume: float = 0.65
var sfx_on: bool = true


func _ready() -> void:
	_apply_bus()


func load_from_meta(meta: Dictionary) -> void:
	var s: Dictionary = meta.get("settings", {})
	master_volume = float(s.get("master", master_volume))
	sfx_volume = float(s.get("sfx", sfx_volume))
	music_volume = float(s.get("music", music_volume))
	sfx_on = bool(s.get("sfx_on", sfx_on))
	_apply_bus()
	settings_changed.emit()


func export_settings() -> Dictionary:
	return {
		"master": master_volume,
		"sfx": sfx_volume,
		"music": music_volume,
		"sfx_on": sfx_on,
	}


func set_master(v: float) -> void:
	master_volume = clampf(v, 0.0, 1.0)
	_apply_bus()
	settings_changed.emit()


func set_sfx(v: float) -> void:
	sfx_volume = clampf(v, 0.0, 1.0)
	settings_changed.emit()


func set_music(v: float) -> void:
	music_volume = clampf(v, 0.0, 1.0)
	settings_changed.emit()


func set_sfx_enabled(on: bool) -> void:
	sfx_on = on
	settings_changed.emit()


func sfx_enabled() -> bool:
	return sfx_on


func _apply_bus() -> void:
	var idx := AudioServer.get_bus_index("Master")
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(master_volume))
