extends RefCounted
## Escalating infinite-wave planner adapted from ape1121 EnemySpawner (MIT).
## Maps turret-template difficulty curves onto Kongfu enemy ids + lane choice.

const ENEMY_DIFFICULTY := {
	"enemy_bandit": 1.0,
	"enemy_runner": 2.0,
	"enemy_shield": 3.0,
}

var seed_waves: Array = []
var infinite: bool = true
var max_wave_cap: int = 9999
var difficulty_initial: float = 1.0
var difficulty_increase: float = 1.18
var difficulty_multiplies: bool = true
var base_spawn_count: int = 6
var flank_every_n: int = 3
var silver_bonus_base: int = 35
var silver_bonus_growth: int = 5


func configure_from(waves_cfg: Dictionary) -> void:
	seed_waves = waves_cfg.get("waves", [])
	var esc: Dictionary = waves_cfg.get("escalation", {})
	infinite = bool(waves_cfg.get("infinite", esc.get("infinite", true)))
	max_wave_cap = int(esc.get("max_wave_cap", 9999))
	difficulty_initial = float(esc.get("difficulty_initial", 1.0))
	difficulty_increase = float(esc.get("difficulty_increase", 1.18))
	difficulty_multiplies = bool(esc.get("difficulty_multiplies", true))
	base_spawn_count = int(esc.get("base_spawn_count", 6))
	flank_every_n = int(esc.get("flank_every_n", 3))
	silver_bonus_base = int(esc.get("silver_bonus_base", 35))
	silver_bonus_growth = int(esc.get("silver_bonus_growth", 5))


func has_more(wave_index: int) -> bool:
	if infinite:
		return wave_index < max_wave_cap
	return wave_index < seed_waves.size()


func build_wave(wave_index: int) -> Dictionary:
	if wave_index < seed_waves.size():
		# Always deep-copy — never mutate shared ContentDB seed rows.
		var seed: Dictionary = seed_waves[wave_index].duplicate(true)
		var spawns_copy: Array = []
		for s in seed.get("spawns", []):
			spawns_copy.append((s as Dictionary).duplicate(true))
		seed["spawns"] = spawns_copy
		_ensure_lanes(seed, wave_index)
		return seed
	return _procedural_wave(wave_index)


func difficulty_at(wave_index: int) -> float:
	if difficulty_multiplies:
		return difficulty_initial * pow(difficulty_increase, float(wave_index))
	return difficulty_initial + difficulty_increase * float(wave_index)


func _procedural_wave(wave_index: int) -> Dictionary:
	var diff := difficulty_at(wave_index)
	var spawn_count := int(maxi(3, round(base_spawn_count * diff)))
	var pool := _spawnable_enemies(diff)
	var spawns: Array = []
	var main_count := spawn_count
	var flank_count := 0
	if flank_every_n > 0 and (wave_index + 1) % flank_every_n == 0:
		flank_count = maxi(2, int(round(spawn_count * 0.28)))
		main_count = spawn_count - flank_count
	_append_spawn_block(spawns, pool, main_count, "main", 0.0, maxf(0.35, 0.95 / maxf(diff * 0.55, 1.0)))
	if flank_count > 0:
		_append_spawn_block(spawns, pool, flank_count, "flank", 1.4, maxf(0.45, 0.85 / maxf(diff * 0.5, 1.0)))
	return {
		"id": wave_index + 1,
		"label": _milestone_label(wave_index, flank_count > 0),
		"hint": "难度 %.1f — 侧翼伏击将至。" % diff if flank_count > 0 else "难度 %.1f — 上↓下压迫。" % diff,
		"silver_bonus": silver_bonus_base + wave_index * silver_bonus_growth,
		"spawns": spawns,
		"knowledge_card": null,
		"difficulty": diff,
	}


func _milestone_label(wave_index: int, has_flank: bool) -> String:
	## Named emotional beats — Kingdom Defense cadence, not "wave N".
	var n := wave_index + 1
	match n % 10:
		0:
			return "第 %d 波 · 火攻总闸" % n
		5:
			return "第 %d 波 · 夜袭" % n
		3, 6, 9:
			return "第 %d 波 · 侧翼合围" % n if has_flank else "第 %d 波 · 栈道加压" % n
		_:
			if has_flank:
				return "第 %d 波 · 伏击" % n
			return "第 %d 波 · 无限栈道" % n


func _spawnable_enemies(diff: float) -> Array:
	var out: Array = []
	for eid in ENEMY_DIFFICULTY.keys():
		if diff + 0.001 >= float(ENEMY_DIFFICULTY[eid]):
			out.append(eid)
	if out.is_empty():
		out.append("enemy_bandit")
	return out


func _append_spawn_block(spawns: Array, pool: Array, count: int, lane: String, delay: float, interval: float) -> void:
	if count <= 0:
		return
	# Prefer tougher units as difficulty rises: weight toward last unlocked.
	var enemy: String = str(pool[mini(pool.size() - 1, int(floor(randf() * pool.size())))])
	if pool.size() >= 2 and randf() < 0.45:
		enemy = str(pool[pool.size() - 1])
	spawns.append({
		"enemy": enemy,
		"count": count,
		"interval": interval,
		"delay": delay,
		"lane": lane,
	})


func _ensure_lanes(wave: Dictionary, wave_index: int) -> void:
	var spawns: Array = wave.get("spawns", [])
	var has_flank := false
	for s in spawns:
		if str(s.get("lane", "main")) == "flank":
			has_flank = true
			break
	if has_flank:
		return
	# Seed waves: inject flank on configured cadence so M1 always shows ambush.
	if flank_every_n > 0 and (wave_index + 1) % flank_every_n == 0 and not spawns.is_empty():
		var last: Dictionary = spawns[spawns.size() - 1].duplicate(true)
		last["lane"] = "flank"
		last["count"] = maxi(2, int(last.get("count", 2)) / 2)
		last["delay"] = float(last.get("delay", 0.0)) + 1.2
		spawns.append(last)
		wave["spawns"] = spawns
		if not str(wave.get("hint", "")).contains("侧翼") and not str(wave.get("hint", "")).contains("伏击"):
			wave["hint"] = str(wave.get("hint", "")) + " 侧翼伏击！"
