extends RefCounted
class_name ExploreRunBag
## Lite run inventory for 搜打撤 — first-party, inspired by MIT inventory plugins.
## Carry materials during a raid; deposit on settle / withdraw; fail keeps a fraction.

var items: Dictionary = {} ## material_id -> int


func clear() -> void:
	items.clear()


func duplicate_bag() -> Dictionary:
	return items.duplicate()


func load_from(data: Dictionary) -> void:
	items.clear()
	for k in data.keys():
		var n := int(data[k])
		if n > 0:
			items[str(k)] = n


func add(mat_id: String, amount: int) -> void:
	if mat_id == "" or amount <= 0:
		return
	items[mat_id] = int(items.get(mat_id, 0)) + amount


func add_dict(loot: Dictionary) -> void:
	for k in loot.keys():
		add(str(k), int(loot[k]))


func total_count() -> int:
	var n := 0
	for k in items.keys():
		n += int(items[k])
	return n


func is_empty() -> bool:
	return total_count() <= 0


## Keep floor(count * ratio) per stack (failure / mid-combat flee).
func apply_keep_ratio(ratio: float) -> Dictionary:
	var kept := {}
	var r := clampf(ratio, 0.0, 1.0)
	for k in items.keys():
		var c := int(items[k])
		var keep := int(floor(float(c) * r))
		if keep > 0:
			kept[k] = keep
	items = kept
	return kept.duplicate()


func summary_text(mat_db: Dictionary = {}) -> String:
	if items.is_empty():
		return "背包空"
	var parts: PackedStringArray = []
	for k in items.keys():
		var name := str(k)
		if mat_db.has(k):
			name = str(mat_db[k].get("name", k))
		parts.append("%s×%d" % [name, int(items[k])])
	return " · ".join(parts)
