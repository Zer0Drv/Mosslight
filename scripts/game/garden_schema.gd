class_name GardenSchema
extends RefCounted
## M0 格式迁移与校验；不改变布局或玩法。M1 内容升级由 GardenState 单独执行。

const LEGACY_AREAS := [[26, 18, 4, 4], [32, 21, 5, 4], [36, 15, 3, 3], [22, 26, 3, 3]]
const SLICE_AREAS := [[26, 18, 3, 2], [36, 20, 1, 1], [24, 26, 1, 1], [14, 26, 2, 2]]
const IDS := ["plum_0", "plum_1", "plum_2"]
const POSITIONS := [Vector2(472, 344), Vector2(616, 296), Vector2(360, 408)]
const SEASONS := ["spring", "summer", "autumn", "winter"]
const TUTORIAL_IDS := ["garden_intro", "light_changed", "companion_intro"]


static func defaults() -> Dictionary:
	return {
		"version": 2, "content_revision": "legacy_49", "selected_crop": "moon_moss",
		"calendar": {"year": 1, "season": "spring", "day": 1, "phase": "day", "play_seconds": 0.0, "day_elapsed_seconds": 0.0, "phase_elapsed_seconds": 0.0, "dawn_reached": false},
		"player": {"pos": [488.0, 418.0], "zone": "plum_garden", "discovered_zones": ["plum_garden"], "visited_sites": []},
		"resources": {"dew": 2, "spores": 0, "nightdew": 0},
		"summary": {"total_harvests": 0, "nights_survived": 0},
		"crops": [], "lanterns": [], "plots_by_zone": {"plum_garden": LEGACY_AREAS.duplicate(true)},
		"loadout": {"element": null, "forms": {"shade": "dirk", "ember": "axe", "sun": "spear", "rime": "whip"}, "marks_by_weapon": {}},
		"fusion": {"discovered": [], "inventory": []},
		"dust": {"active": null, "stock": {"ember": 0, "rime": 0, "shade": 0, "sun": 0}, "afterglow": null},
		"wick_dust": 0,
		"seals": {"codex": false, "hand_lantern": false, "fusion_table": false, "borrow_lamp": false, "light_branch": false, "quern": false, "night_bell": false, "lamp_rack": false},
		"routes": {"recorded": [], "active": null}, "notes": [], "tree": {"nodes": [], "points": 0},
		"npcs": {}, "story_seen": [], "story_variants": {}, "claimed_story_items": [], "tutorial_seen": [],
		"world_effects": [], "loose_dew": [], "pending_battle": null, "last_settlement": null,
		"decor": [], "outfit": null, "consumables": {"fog": 0, "wick": 0, "ripe": 0, "moss": 0, "letter": 0}, "tales": [], "saved_at": 0,
	}


static func layout(areas: Array) -> Dictionary:
	var cells := {}
	for area: Array in areas:
		for y in range(int(area[1]), int(area[1] + area[3])):
			for x in range(int(area[0]), int(area[0] + area[2])):
				var cell := Vector2i(x, y)
				var reserved := false
				for point: Vector2 in POSITIONS:
					if (Vector2(cell * 16) + Vector2(8, 8)).distance_to(point) <= 22.0:
						reserved = true
				if not reserved:
					cells[cell] = {"crop": "", "growth": 0.0}
	return cells


static func normalize(raw: Dictionary) -> Dictionary:
	if not integer(raw.get("version"), 1, 2):
		return {}
	var candidate := raw
	if int(raw.version) == 1:
		candidate = migrate_v1(raw)
		if candidate.is_empty():
			return {}
	for key in ["version", "selected_crop", "resources", "summary", "crops", "lanterns", "plots_by_zone"]:
		if not candidate.has(key):
			return {}
	var result := defaults()
	for key: String in result:
		if candidate.has(key):
			result[key] = candidate[key]
	result = result.duplicate(true)
	if result.content_revision not in ["legacy_49", "slice_a_12_v1"] or result.selected_crop not in ["moon_moss", "glow_bell"]:
		return {}
	var expected: Array = LEGACY_AREAS if result.content_revision == "legacy_49" else SLICE_AREAS
	if not same(result.plots_by_zone, {"plum_garden": expected}):
		return {}
	if not result.resources is Dictionary or not result.summary is Dictionary:
		return {}
	for key in ["dew", "spores", "nightdew"]:
		if not integer(result.resources.get(key), 0, 999999):
			return {}
		result.resources[key] = int(result.resources[key])
	for key in ["total_harvests", "nights_survived"]:
		if not integer(result.summary.get(key), 0, 999999999):
			return {}
		result.summary[key] = int(result.summary[key])
	if not result.crops is Array or not result.lanterns is Array or result.lanterns.size() != 3:
		return {}
	var cells := layout(expected)
	var seen := {}
	for entry: Variant in result.crops:
		if not entry is Dictionary or not integer(entry.get("x"), 0, 59) or not integer(entry.get("y"), 0, 39):
			return {}
		var cell := Vector2i(int(entry.x), int(entry.y))
		if entry.get("zone") != "plum_garden" or not cells.has(cell) or seen.has(cell):
			return {}
		if entry.get("crop") not in ["moon_moss", "glow_bell"] or not number(entry.get("growth"), 0.0, 1.0):
			return {}
		entry.x = cell.x
		entry.y = cell.y
		entry.growth = float(entry.growth)
		seen[cell] = true
	var by_id := {}
	for entry: Variant in result.lanterns:
		if not entry is Dictionary or entry.get("id") not in IDS or by_id.has(entry.id):
			return {}
		if not entry.get("restored") is bool or not entry.get("lit") is bool or not number(entry.get("charge"), 0.0, 1.0):
			return {}
		if entry.lit and not entry.restored:
			return {}
		entry.charge = float(entry.charge)
		by_id[entry.id] = entry
	if not by_id.plum_0.restored or (result.content_revision == "slice_a_12_v1" and not by_id.plum_0.lit):
		return {}
	result.lanterns = [by_id.plum_0, by_id.plum_1, by_id.plum_2]
	if not _calendar(result.calendar) or not _player(result.player) or not integer(result.saved_at, 0, 999999999999):
		return {}
	result.saved_at = int(result.saved_at)
	if not result.tutorial_seen is Array:
		return {}
	seen.clear()
	for id: Variant in result.tutorial_seen:
		if id not in TUTORIAL_IDS or seen.has(id):
			return {}
		seen[id] = true
	# 尚未实现的非空玩法不能被旧程序读入再清空写回。
	var safe := defaults()
	for key in ["loadout", "fusion", "dust", "wick_dust", "seals", "routes", "notes", "tree", "npcs", "story_seen", "story_variants", "claimed_story_items", "world_effects", "loose_dew", "pending_battle", "last_settlement", "decor", "outfit", "consumables", "tales"]:
		if not same(result[key], safe[key]):
			return {}
		result[key] = safe[key]
	result.version = 2
	result.plots_by_zone = {"plum_garden": expected.duplicate(true)}
	return result


static func migrate_v1(raw: Dictionary) -> Dictionary:
	for key in ["version", "selected_crop", "resources", "total_harvests", "plots", "lanterns"]:
		if not raw.has(key):
			return {}
	if raw.selected_crop not in ["moon_moss", "glow_bell"] or not integer(raw.total_harvests, 0, 999999999):
		return {}
	if not raw.resources is Dictionary or not integer(raw.resources.get("dew"), 0, 999999) or not integer(raw.resources.get("spores"), 0, 999999):
		return {}
	var cells := layout(LEGACY_AREAS)
	if not raw.plots is Array or raw.plots.size() != cells.size() or not raw.lanterns is Array or raw.lanterns.size() != 3:
		return {}
	var result := defaults()
	var seen := {}
	for entry: Variant in raw.plots:
		if not entry is Dictionary or not integer(entry.get("x"), 0, 59) or not integer(entry.get("y"), 0, 39):
			return {}
		var cell := Vector2i(int(entry.x), int(entry.y))
		if not cells.has(cell) or seen.has(cell) or entry.get("crop") not in ["", "moon_moss", "glow_bell"] or not number(entry.get("growth"), 0.0, 1.0):
			return {}
		seen[cell] = true
		if entry.crop == "" and float(entry.growth) != 0.0:
			return {}
		if entry.crop != "":
			result.crops.append({"zone": "plum_garden", "x": cell.x, "y": cell.y, "crop": entry.crop, "growth": float(entry.growth)})
	for i in range(3):
		var entry: Variant = raw.lanterns[i]
		if not entry is Dictionary or not entry.get("restored") is bool or not entry.get("lit") is bool:
			return {}
		if (entry.lit and not entry.restored) or (i == 0 and not entry.restored):
			return {}
		result.lanterns.append({"id": IDS[i], "restored": entry.restored, "lit": entry.lit, "charge": 1.0 if entry.lit else 0.0})
	result.resources.dew = int(raw.resources.dew)
	result.resources.spores = int(raw.resources.spores)
	result.summary.total_harvests = int(raw.total_harvests)
	result.selected_crop = raw.selected_crop
	return result


static func _calendar(raw: Variant) -> bool:
	if not raw is Dictionary or not same(raw.keys().size(), defaults().calendar.size()):
		return false
	if not integer(raw.get("year"), 1, 999999) or not integer(raw.get("day"), 1, 8) or raw.get("season") not in SEASONS or raw.get("phase") not in ["day", "dusk"]:
		return false
	if not number(raw.get("play_seconds"), 0.0, 1.0e15) or not number(raw.get("day_elapsed_seconds"), 0.0, 720.0) or not number(raw.get("phase_elapsed_seconds"), 0.0, 30.0) or not raw.get("dawn_reached") is bool:
		return false
	if raw.phase == "day" and (raw.day_elapsed_seconds >= 720.0 or raw.phase_elapsed_seconds != 0.0):
		return false
	if raw.phase == "dusk" and raw.day_elapsed_seconds != 720.0:
		return false
	raw.year = int(raw.year)
	raw.day = int(raw.day)
	for key in ["play_seconds", "day_elapsed_seconds", "phase_elapsed_seconds"]:
		raw[key] = float(raw[key])
	return true


static func _player(raw: Variant) -> bool:
	if not raw is Dictionary or raw.get("zone") != "plum_garden" or not same(raw.get("discovered_zones"), ["plum_garden"]) or not same(raw.get("visited_sites"), []):
		return false
	var pos: Variant = raw.get("pos")
	if not pos is Array or pos.size() != 2 or not number(pos[0], -1.0e10, 1.0e10) or not number(pos[1], -1.0e10, 1.0e10):
		return false
	# 切片仍从安全出生点进入；不恢复未经物理世界验证的历史坐标。
	raw.pos = [488.0, 418.0]
	return true


static func same(a: Variant, b: Variant) -> bool:
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size():
			return false
		for key: Variant in b:
			if not a.has(key) or not same(a[key], b[key]):
				return false
		return true
	if a is Array and b is Array:
		if a.size() != b.size():
			return false
		for i in range(b.size()):
			if not same(a[i], b[i]):
				return false
		return true
	if (a is int or a is float) and (b is int or b is float):
		return is_finite(float(a)) and float(a) == float(b)
	return typeof(a) == typeof(b) and a == b


static func number(value: Variant, low: float, high: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= low and float(value) <= high


static func integer(value: Variant, low: int, high: int) -> bool:
	return number(value, low, high) and float(value) == floorf(float(value))
