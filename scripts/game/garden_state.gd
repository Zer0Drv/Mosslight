class_name GardenState
extends RefCounted
## 林间种光：世界与界面共享的经营状态，不依赖节点或渲染。
## 存档版本 2（M0）：字段宽松校验，未知键忽略；v1 存档自动迁移并按 B3 折算补偿。

signal changed
signal harvest_collected(kind: String, amount: int)
signal lantern_restored(index: int)

const CELL_SIZE := 16
const MAP_SIZE := Vector2i(60, 40)
## 12 格苗床：两块暖光（各 4 格）+ 一块阴影（4 格），逼玩家在明暗之间取舍。
const PLOT_AREAS: Array[Rect2i] = [
	Rect2i(26, 18, 2, 2), Rect2i(32, 21, 2, 2), Rect2i(14, 26, 2, 2),
]
const LANTERN_POSITIONS: Array[Vector2] = [
	Vector2(472, 344), Vector2(616, 296), Vector2(360, 408),
]
const LANTERN_IDS: Array[String] = ["plum_0", "plum_1", "plum_2"]
const LIGHT_RADIUS := 78.0
const LANTERN_BASE_RADIUS := 22.0
const GROW_SECONDS := {"moon_moss": 90.0, "glow_bell": 120.0}
## 修复成本逐盏递增：第 1 盏约 1/3 天，三盏合计约 2 天。
const RESTORE_COST: Array[Dictionary] = [
	{"spores": 12, "dew": 8},
	{"spores": 24, "dew": 16},
	{"spores": 36, "dew": 24},
]
const HARVEST_AMOUNT := 1
const MAX_RESOURCE := 999999
const MAX_HARVESTS := 999999999
const SEASONS: Array[String] = ["spring", "summer", "autumn", "winter"]
const DUST_KINDS: Array[String] = ["ember", "rime", "shade", "sun"]
const CONSUMABLE_KINDS: Array[String] = ["fog", "wick", "ripe", "moss", "letter"]
const SAVE_VERSION := 2
const DEFAULT_ZONE := "plum_garden"
const MAX_PLAY_SECONDS := 1000000000.0

var plots: Dictionary = {}
var lanterns: Array[Dictionary] = []
var resources: Dictionary = {"dew": 2, "spores": 0, "nightdew": 0}
var selected_crop: String = "moon_moss"
var total_harvests: int = 0
var nights_survived: int = 0
var calendar: Dictionary = {}
var zone: String = DEFAULT_ZONE
var discovered_zones: Array[String] = []
var visited_sites: Array[String] = []
var loadout: Dictionary = {}
var fusion_discovered: Array[String] = []
var fusion_inventory: Array[String] = []
var dust: Dictionary = {}
var wick_dust: int = 0
var seals: Dictionary = {}
var routes: Dictionary = {}
var notes: Array[Dictionary] = []
var decor: Dictionary = {}
var outfit: Dictionary = {}
var consumables: Dictionary = {}
var tales: Dictionary = {}
var tree_nodes: Array[String] = []
var tree_points: int = 0
var npcs: Dictionary = {}
## 由 restore 写入：非空表示这次读档折算补偿过旧苗床，调用方可据此提示玩家。
var migration_note: String = ""


func _init() -> void:
	reset()


func reset() -> void:
	plots = _empty_plots()
	lanterns.clear()
	for index in range(LANTERN_POSITIONS.size()):
		lanterns.append({
			"id": LANTERN_IDS[index],
			"position": LANTERN_POSITIONS[index],
			"restored": index == 0,
			"lit": index == 0,
			"charge": 1.0,
		})
	resources = {"dew": 2, "spores": 0, "nightdew": 0}
	selected_crop = "moon_moss"
	total_harvests = 0
	nights_survived = 0
	calendar = {"season": "spring", "day": 1, "play_seconds": 0.0, "dawn_reached": false}
	zone = DEFAULT_ZONE
	discovered_zones = [DEFAULT_ZONE]
	visited_sites = []
	loadout = {"weapon": "staff", "element": "", "mark": "", "mark_uses": 0}
	fusion_discovered = []
	fusion_inventory = []
	dust = {"active": "", "expires": "", "stock": {"ember": 0, "rime": 0, "shade": 0, "sun": 0}}
	wick_dust = 0
	seals = {}
	routes = {"recorded": [], "active": -1}
	notes = []
	decor = {"owned": [], "placed": []}
	outfit = {"worn": "moss", "owned": ["moss"]}
	consumables = {"fog": 0, "wick": 0, "ripe": 0, "moss": 0, "letter": 0}
	tales = {"found": [], "seen": []}
	tree_nodes = []
	tree_points = 0
	npcs = {}
	migration_note = ""
	# 两块苗床各留一株，让玩家开局就能观察到生长。
	plots[Vector2i(14, 26)] = {"crop": "moon_moss", "growth": 0.65}
	plots[Vector2i(26, 18)] = {"crop": "glow_bell", "growth": 0.5}
	changed.emit()


func advance(delta: float) -> void:
	if not is_finite(delta) or delta <= 0.0:
		return
	calendar["play_seconds"] = minf(MAX_PLAY_SECONDS, float(calendar["play_seconds"]) + delta)
	var advanced := false
	for cell: Vector2i in plots:
		var plot: Dictionary = plots[cell]
		var crop: String = plot["crop"]
		var growth: float = plot["growth"]
		if crop.is_empty() or growth >= 1.0 or not growth_condition(cell):
			continue
		plot["growth"] = minf(1.0, growth + delta / float(GROW_SECONDS[crop]))
		advanced = true
	if advanced:
		changed.emit()


func select_crop(kind: String) -> void:
	if not GROW_SECONDS.has(kind) or selected_crop == kind:
		return
	selected_crop = kind
	changed.emit()


func is_lit(cell: Vector2i) -> bool:
	var center := _cell_center(cell)
	for lantern: Dictionary in lanterns:
		if bool(lantern["restored"]) and bool(lantern["lit"]):
			var position: Vector2 = lantern["position"]
			if center.distance_squared_to(position) <= LIGHT_RADIUS * LIGHT_RADIUS:
				return true
	return false


func growth_condition(cell: Vector2i) -> bool:
	if not plots.has(cell):
		return false
	var crop: String = plots[cell]["crop"]
	return _crop_condition(crop, cell)


func plant_or_harvest(cell: Vector2i) -> String:
	if not plots.has(cell):
		return "在苔石围出的苗床上种植；灯脚旁需要留出空间。"
	var plot: Dictionary = plots[cell]
	var crop: String = plot["crop"]
	if crop.is_empty():
		plot["crop"] = selected_crop
		plot["growth"] = 0.0
		changed.emit()
		if growth_condition(cell):
			return "种下了%s。%s" % [_crop_name(selected_crop), _crop_requirement(selected_crop)]
		return "种下了%s，但这里光照不合适。可开关附近苔灯，或按 R 移除。" % _crop_name(selected_crop)
	if float(plot["growth"]) < 1.0:
		if not growth_condition(cell):
			return "%s正在等待%s；调整附近苔灯，或按 R 移除。" % [_crop_name(crop), "阴影" if crop == "moon_moss" else "暖光"]
		return "%s正在生长，可用 1 露滴露养。" % _crop_name(crop)
	var resource := "dew" if crop == "moon_moss" else "spores"
	resources[resource] = mini(MAX_RESOURCE, int(resources[resource]) + HARVEST_AMOUNT)
	total_harvests = mini(MAX_HARVESTS, total_harvests + 1)
	plot["crop"] = ""
	plot["growth"] = 0.0
	harvest_collected.emit(crop, HARVEST_AMOUNT)
	changed.emit()
	return "收获%s，得到 %d %s。苗床可以继续播种。" % [_crop_name(crop), HARVEST_AMOUNT, "露滴" if resource == "dew" else "灯孢"]


func nourish(cell: Vector2i) -> String:
	if not plots.has(cell) or String(plots[cell]["crop"]).is_empty():
		return "先在苗床种下植物，再用露滴露养。"
	var plot: Dictionary = plots[cell]
	if float(plot["growth"]) >= 1.0:
		return "这株植物已经成熟，按 E 收获即可。"
	if not growth_condition(cell):
		return "光照不合适，露滴无法露养。先调整附近苔灯。"
	if int(resources["dew"]) < 1:
		return "需要 1 露滴。先在阴影中收获月苔。"
	resources["dew"] = int(resources["dew"]) - 1
	plot["growth"] = minf(1.0, float(plot["growth"]) + 0.35)
	changed.emit()
	return "消耗 1 露滴，%s生长加快了。" % _crop_name(String(plot["crop"]))


func clear_crop(cell: Vector2i) -> String:
	if not plots.has(cell):
		return "这里没有可移除的植物。"
	var plot: Dictionary = plots[cell]
	if String(plot["crop"]).is_empty():
		return "这块苗床还是空的，可以直接播种。"
	if float(plot["growth"]) >= 1.0:
		return "植物已经成熟，按 E 收获，避免浪费。"
	plot["crop"] = ""
	plot["growth"] = 0.0
	changed.emit()
	return "已移除植物。种子免费，可以重新选择适合光照的种类。"


func interact_lantern(index: int) -> String:
	if index < 0 or index >= lanterns.size():
		return "这里没有苔灯。"
	var lantern: Dictionary = lanterns[index]
	if bool(lantern["restored"]):
		lantern["lit"] = not bool(lantern["lit"])
		changed.emit()
		return "苔灯亮起，暖光唤醒灯铃。" if bool(lantern["lit"]) else "苔灯熄灭，阴影让月苔重新生长。"
	var cost := get_restore_cost(index)
	if int(resources["spores"]) < int(cost["spores"]) or int(resources["dew"]) < int(cost["dew"]):
		return "修复需要 %d 灯孢和 %d 露滴。灯铃产灯孢，月苔产露滴。" % [int(cost["spores"]), int(cost["dew"])]
	resources["spores"] = int(resources["spores"]) - int(cost["spores"])
	resources["dew"] = int(resources["dew"]) - int(cost["dew"])
	lantern["restored"] = true
	lantern["lit"] = true
	lantern["charge"] = 1.0
	lantern_restored.emit(index)
	changed.emit()
	if get_restored_count() == lanterns.size():
		return "三盏苔灯都已修复，林间灯路重新相连。"
	return "修好了第 %d 盏苔灯。可以在新的暖光下栽种灯铃。" % (index + 1)


func get_restore_cost(index: int) -> Dictionary:
	if index < 0 or index >= RESTORE_COST.size():
		return RESTORE_COST[RESTORE_COST.size() - 1]
	return RESTORE_COST[index]


func get_plot_info(cell: Vector2i) -> Dictionary:
	if not plots.has(cell):
		return _info("林间空地", "循着苔石寻找苗床与旧灯。", "靠近苗床或苔灯", -1.0, "")
	var plot: Dictionary = plots[cell]
	var crop: String = plot["crop"]
	var light := "暖光" if is_lit(cell) else "阴影"
	if crop.is_empty():
		var suitable := _crop_condition(selected_crop, cell)
		return _info(
			"空苗床", "%s · %s 种子免费。" % [light, _crop_requirement(selected_crop)],
			"E 种%s" % _crop_name(selected_crop), -1.0,
			"光照适宜" if suitable else "需要调整光照或种类"
		)
	var growth: float = plot["growth"]
	if growth >= 1.0:
		return _info(_crop_name(crop), "收获可得 %d %s，苗床可以重新播种。" % [HARVEST_AMOUNT, "露滴" if crop == "moon_moss" else "灯孢"], "E 收获", growth, "可以收获")
	var suitable := growth_condition(cell)
	return _info(
		_crop_name(crop), "%s · %s 露养消耗 1 露滴。" % [light, _crop_requirement(crop)],
		"Q 露养 · R 移除", growth,
		"正在生长" if suitable else "等待阴影" if crop == "moon_moss" else "等待暖光"
	)


func get_lantern_info(index: int) -> Dictionary:
	if index < 0 or index >= lanterns.size():
		return _info("林间旧路", "附近没有可操作的苔灯。", "寻找旧灯", -1.0, "")
	var lantern: Dictionary = lanterns[index]
	var title := "苔灯 %d" % (index + 1)
	if bool(lantern["restored"]):
		var lit: bool = lantern["lit"]
		return _info(title, "暖光供灯铃生长；熄灯后月苔恢复生长。", "E 熄灯" if lit else "E 点灯", -1.0, "已点亮 · 不耗燃料" if lit else "已熄灭 · 可以重新点亮")
	var cost := get_restore_cost(index)
	var enough := int(resources["spores"]) >= int(cost["spores"]) and int(resources["dew"]) >= int(cost["dew"])
	return _info(
		title, "需要 %d 灯孢 + %d 露滴。修复后，暖光照到附近苗床。" % [int(cost["spores"]), int(cost["dew"])],
		"E 修复", -1.0, "材料已备齐" if enough else "尚缺修复材料"
	)


func get_restored_count() -> int:
	var count := 0
	for lantern: Dictionary in lanterns:
		if bool(lantern["restored"]):
			count += 1
	return count


func snapshot() -> Dictionary:
	var saved_crops: Array[Dictionary] = []
	for cell: Vector2i in plots:
		var plot: Dictionary = plots[cell]
		if String(plot["crop"]).is_empty():
			continue
		saved_crops.append({"x": cell.x, "y": cell.y, "crop": plot["crop"], "growth": plot["growth"]})
	var saved_lanterns: Array[Dictionary] = []
	for lantern: Dictionary in lanterns:
		saved_lanterns.append({
			"id": lantern["id"],
			"restored": lantern["restored"],
			"lit": lantern["lit"],
			"charge": lantern["charge"],
		})
	var areas: Array[Array] = []
	for area: Rect2i in PLOT_AREAS:
		areas.append([area.position.x, area.position.y, area.size.x, area.size.y])
	return {
		"version": SAVE_VERSION,
		"calendar": calendar.duplicate(true),
		"player": {
			"zone": zone,
			"discovered_zones": discovered_zones.duplicate(),
			"visited_sites": visited_sites.duplicate(),
		},
		"resources": resources.duplicate(),
		"summary": {"total_harvests": total_harvests, "nights_survived": nights_survived},
		"crops": saved_crops,
		"lanterns": saved_lanterns,
		"plots_by_zone": {DEFAULT_ZONE: areas},
		"loadout": loadout.duplicate(true),
		"fusion": {"discovered": fusion_discovered.duplicate(), "inventory": fusion_inventory.duplicate()},
		"dust": dust.duplicate(true),
		"wick_dust": wick_dust,
		"seals": seals.duplicate(true),
		"routes": routes.duplicate(true),
		"notes": notes.duplicate(true),
		"decor": decor.duplicate(true),
		"outfit": outfit.duplicate(true),
		"consumables": consumables.duplicate(true),
		"tales": tales.duplicate(true),
		"tree": {"nodes": tree_nodes.duplicate(), "points": tree_points},
		"npcs": npcs.duplicate(true),
	}


func restore(data: Dictionary) -> bool:
	# 所有校验都在临时结构完成；任何失败都不触碰正在游玩的状态。
	migration_note = ""
	if not data is Dictionary or not data.has("version"):
		return false
	var version_value: Variant = data["version"]
	if not (version_value is int or version_value is float):
		return false
	if not is_finite(float(version_value)) or float(version_value) != floorf(float(version_value)):
		return false
	var version := int(version_value)
	if version > SAVE_VERSION or version < 1:
		return false
	var candidate: Dictionary = data
	if version == 1:
		candidate = _migrate_v1(data)
		if candidate.is_empty():
			return false
	elif version != SAVE_VERSION:
		return false
	if not _restore_v2(candidate):
		migration_note = ""
		return false
	return true


func _migrate_v1(data: Dictionary) -> Dictionary:
	# v1 → v2：只保留非空苗床；新布局里没有的格子按作物折成 1 份资源（B3）。
	if not _has_keys(data, ["version", "selected_crop", "resources", "total_harvests", "plots", "lanterns"]):
		return {}
	if not data["selected_crop"] is String or not GROW_SECONDS.has(data["selected_crop"]):
		return {}
	if not _integer_in_range(data["total_harvests"], 0, MAX_HARVESTS):
		return {}
	if not data["resources"] is Dictionary:
		return {}
	var old_resources: Dictionary = data["resources"]
	if not _has_keys(old_resources, ["dew", "spores"]):
		return {}
	if not _integer_in_range(old_resources["dew"], 0, MAX_RESOURCE) or not _integer_in_range(old_resources["spores"], 0, MAX_RESOURCE):
		return {}
	if not data["plots"] is Array or not data["lanterns"] is Array:
		return {}
	var layout := _empty_plots()
	var crops: Array[Dictionary] = []
	var refund_dew := 0
	var refund_spores := 0
	for entry: Variant in data["plots"]:
		if not entry is Dictionary or not _has_keys(entry, ["x", "y", "crop", "growth"]):
			return {}
		if not entry["crop"] is String:
			return {}
		if not _integer_in_range(entry["x"], 0, MAP_SIZE.x - 1) or not _integer_in_range(entry["y"], 0, MAP_SIZE.y - 1):
			return {}
		if not _number_in_range(entry["growth"], 0.0, 1.0):
			return {}
		var crop: String = entry["crop"]
		if crop.is_empty():
			continue
		if not GROW_SECONDS.has(crop):
			return {}
		var cell := Vector2i(int(entry["x"]), int(entry["y"]))
		if layout.has(cell):
			crops.append({"x": cell.x, "y": cell.y, "crop": crop, "growth": float(entry["growth"])})
		elif crop == "moon_moss":
			refund_dew += 1
		else:
			refund_spores += 1
	var migrated_lanterns: Array[Dictionary] = []
	for index in range(mini(data["lanterns"].size(), LANTERN_IDS.size())):
		var entry: Variant = data["lanterns"][index]
		if not entry is Dictionary or not entry.has("restored") or not entry.has("lit"):
			return {}
		if not entry["restored"] is bool or not entry["lit"] is bool:
			return {}
		var restored := bool(entry["restored"])
		var lit := bool(entry["lit"])
		if lit and not restored:
			return {}
		if index == 0 and not restored:
			return {}
		migrated_lanterns.append({"id": LANTERN_IDS[index], "restored": restored, "lit": lit, "charge": 1.0})
	while migrated_lanterns.size() < LANTERN_IDS.size():
		var extra := migrated_lanterns.size()
		migrated_lanterns.append({"id": LANTERN_IDS[extra], "restored": false, "lit": false, "charge": 1.0})
	var dew := mini(int(old_resources["dew"]) + refund_dew, MAX_RESOURCE)
	var spores := mini(int(old_resources["spores"]) + refund_spores, MAX_RESOURCE)
	if refund_dew + refund_spores > 0:
		migration_note = "旧苗床换成新的了。多出来的收成已折成 %d 露滴、%d 灯孢。" % [refund_dew, refund_spores]
	var areas: Array[Array] = []
	for area: Rect2i in PLOT_AREAS:
		areas.append([area.position.x, area.position.y, area.size.x, area.size.y])
	return {
		"version": SAVE_VERSION,
		"calendar": {"season": "spring", "day": 1, "play_seconds": 0.0, "dawn_reached": false},
		"player": {"zone": DEFAULT_ZONE, "discovered_zones": [DEFAULT_ZONE], "visited_sites": []},
		"resources": {"dew": dew, "spores": spores, "nightdew": 0},
		"summary": {"total_harvests": int(data["total_harvests"]), "nights_survived": 0},
		"crops": crops,
		"lanterns": migrated_lanterns,
		"plots_by_zone": {DEFAULT_ZONE: areas},
		"loadout": {"weapon": "staff", "element": "", "mark": "", "mark_uses": 0},
		"fusion": {"discovered": [], "inventory": []},
		"dust": {"active": "", "expires": "", "stock": {"ember": 0, "rime": 0, "shade": 0, "sun": 0}},
		"wick_dust": 0,
		"seals": {},
		"routes": {"recorded": [], "active": -1},
		"notes": [],
		"decor": {"owned": [], "placed": []},
		"outfit": {"worn": "moss", "owned": ["moss"]},
		"consumables": {"fog": 0, "wick": 0, "ripe": 0, "moss": 0, "letter": 0},
		"tales": {"found": [], "seen": []},
		"tree": {"nodes": [], "points": 0},
		"npcs": {},
	}


func _restore_v2(data: Dictionary) -> bool:
	# 宽松校验：必需字段必须在；未知字段一律忽略（v2 内继续加字段不必再升版本）。
	if not _has_keys(data, [
		"version", "calendar", "player", "resources", "summary", "crops",
		"lanterns", "plots_by_zone", "loadout", "fusion", "dust", "seals",
		"routes", "notes", "tree",
	]):
		return false
	if not _integer_in_range(data["version"], SAVE_VERSION, SAVE_VERSION):
		return false
	if not data["calendar"] is Dictionary or not data["player"] is Dictionary:
		return false
	var stored_calendar: Dictionary = data["calendar"]
	if not _has_keys(stored_calendar, ["season", "day", "play_seconds", "dawn_reached"]):
		return false
	if not stored_calendar["season"] is String or not SEASONS.has(stored_calendar["season"]):
		return false
	if not _integer_in_range(stored_calendar["day"], 1, 8):
		return false
	if not _number_in_range(stored_calendar["play_seconds"], 0.0, MAX_PLAY_SECONDS):
		return false
	if not stored_calendar["dawn_reached"] is bool:
		return false
	var stored_player: Dictionary = data["player"]
	if not _has_keys(stored_player, ["zone", "discovered_zones", "visited_sites"]):
		return false
	if not stored_player["zone"] is String:
		return false
	if not stored_player["discovered_zones"] is Array or not stored_player["visited_sites"] is Array:
		return false
	if not data["resources"] is Dictionary:
		return false
	var stored_resources: Dictionary = data["resources"]
	if not _has_keys(stored_resources, ["dew", "spores", "nightdew"]):
		return false
	for key: String in ["dew", "spores", "nightdew"]:
		if not _integer_in_range(stored_resources[key], 0, MAX_RESOURCE):
			return false
	if not data["summary"] is Dictionary:
		return false
	var stored_summary: Dictionary = data["summary"]
	if not _has_keys(stored_summary, ["total_harvests", "nights_survived"]):
		return false
	if not _integer_in_range(stored_summary["total_harvests"], 0, MAX_HARVESTS):
		return false
	if not _integer_in_range(stored_summary["nights_survived"], 0, MAX_HARVESTS):
		return false
	if not data["crops"] is Array or not data["lanterns"] is Array:
		return false
	var layout := _empty_plots()
	var restored_plots: Dictionary = _empty_plots()
	var seen: Dictionary = {}
	for entry: Variant in data["crops"]:
		if not entry is Dictionary or not _has_keys(entry, ["x", "y", "crop", "growth"]):
			return false
		if not _integer_in_range(entry["x"], 0, MAP_SIZE.x - 1) or not _integer_in_range(entry["y"], 0, MAP_SIZE.y - 1):
			return false
		var cell := Vector2i(int(entry["x"]), int(entry["y"]))
		if not layout.has(cell) or seen.has(cell):
			return false
		if not entry["crop"] is String:
			return false
		var crop: String = entry["crop"]
		if crop.is_empty() or not GROW_SECONDS.has(crop):
			return false
		if not _number_in_range(entry["growth"], 0.0, 1.0):
			return false
		seen[cell] = true
		restored_plots[cell] = {"crop": crop, "growth": float(entry["growth"])}
	if not data["plots_by_zone"] is Dictionary:
		return false
	var stored_lanterns: Array = data["lanterns"]
	if stored_lanterns.size() != LANTERN_IDS.size():
		return false
	var restored_lanterns: Array[Dictionary] = []
	var by_id: Dictionary = {}
	for entry: Variant in stored_lanterns:
		if not entry is Dictionary or not _has_keys(entry, ["id", "restored", "lit", "charge"]):
			return false
		if not entry["id"] is String or not LANTERN_IDS.has(entry["id"]):
			return false
		if not entry["restored"] is bool or not entry["lit"] is bool:
			return false
		if bool(entry["lit"]) and not bool(entry["restored"]):
			return false
		if not _number_in_range(entry["charge"], 0.0, 1.0):
			return false
		by_id[String(entry["id"])] = entry
	for index in range(LANTERN_IDS.size()):
		var id: String = LANTERN_IDS[index]
		if not by_id.has(id):
			return false
		var entry: Dictionary = by_id[id]
		if index == 0 and not bool(entry["restored"]):
			return false
		restored_lanterns.append({
			"id": id,
			"position": LANTERN_POSITIONS[index],
			"restored": bool(entry["restored"]),
			"lit": bool(entry["lit"]),
			"charge": float(entry["charge"]),
		})
	if not data["loadout"] is Dictionary or not data["fusion"] is Dictionary:
		return false
	if not data["dust"] is Dictionary or not data["seals"] is Dictionary:
		return false
	if not data["routes"] is Dictionary or not data["notes"] is Array or not data["tree"] is Dictionary:
		return false
	var stored_tree: Dictionary = data["tree"]
	if not _has_keys(stored_tree, ["nodes", "points"]):
		return false
	if not stored_tree["nodes"] is Array:
		return false
	if not _integer_in_range(stored_tree["points"], 0, MAX_HARVESTS):
		return false
	# 校验全部通过，才开始写状态。
	plots = restored_plots
	lanterns = restored_lanterns
	resources = {
		"dew": int(stored_resources["dew"]),
		"spores": int(stored_resources["spores"]),
		"nightdew": int(stored_resources["nightdew"]),
	}
	total_harvests = int(stored_summary["total_harvests"])
	nights_survived = int(stored_summary["nights_survived"])
	calendar = {
		"season": String(stored_calendar["season"]),
		"day": int(stored_calendar["day"]),
		"play_seconds": float(stored_calendar["play_seconds"]),
		"dawn_reached": bool(stored_calendar["dawn_reached"]),
	}
	zone = String(stored_player["zone"])
	discovered_zones = _strings(stored_player["discovered_zones"])
	visited_sites = _strings(stored_player["visited_sites"])
	# 逐字段还原：JSON 往返会把整数变成浮点，直接 duplicate 会污染状态。
	loadout = _restore_loadout(data["loadout"])
	var stored_fusion: Dictionary = data["fusion"]
	fusion_discovered = _strings(stored_fusion.get("discovered", []))
	fusion_inventory = _strings(stored_fusion.get("inventory", []))
	dust = _restore_dust(data["dust"])
	wick_dust = maxi(0, int(data.get("wick_dust", 0)))
	seals = _restore_seals(data["seals"])
	routes = _restore_routes(data["routes"])
	notes.clear()
	for entry: Variant in data["notes"]:
		if entry is Dictionary:
			notes.append(entry.duplicate(true))
	decor = _restore_decor(data.get("decor", {}))
	outfit = _restore_outfit(data.get("outfit", {}))
	consumables = _restore_consumables(data.get("consumables", {}))
	tales = _restore_tales(data.get("tales", {}))
	tree_nodes = _strings(stored_tree["nodes"])
	tree_points = maxi(0, int(stored_tree["points"]))
	npcs = data.get("npcs", {}).duplicate(true)
	changed.emit()
	return true


func _restore_loadout(raw: Variant) -> Dictionary:
	var source: Dictionary = raw if raw is Dictionary else {}
	return {
		"weapon": String(source.get("weapon", "staff")),
		"element": String(source.get("element", "")),
		"mark": String(source.get("mark", "")),
		"mark_uses": maxi(0, int(source.get("mark_uses", 0))),
	}


func _restore_dust(raw: Variant) -> Dictionary:
	var source: Dictionary = raw if raw is Dictionary else {}
	var raw_stock: Variant = source.get("stock", {})
	var stock: Dictionary = raw_stock if raw_stock is Dictionary else {}
	var normalized := {}
	for kind: String in DUST_KINDS:
		normalized[kind] = maxi(0, int(stock.get(kind, 0)))
	return {
		"active": String(source.get("active", "")),
		"expires": String(source.get("expires", "")),
		"stock": normalized,
	}


func _restore_seals(raw: Variant) -> Dictionary:
	var source: Dictionary = raw if raw is Dictionary else {}
	var result := {}
	for key: Variant in source:
		if not key is String:
			continue
		result[String(key)] = bool(source[key])
	return result


func _restore_routes(raw: Variant) -> Dictionary:
	var source: Dictionary = raw if raw is Dictionary else {}
	var raw_recorded: Variant = source.get("recorded", [])
	return {
		"recorded": raw_recorded if raw_recorded is Array else [],
		"active": int(source.get("active", -1)),
	}


func _restore_decor(raw: Variant) -> Dictionary:
	var source: Dictionary = raw if raw is Dictionary else {}
	return {"owned": _strings(source.get("owned", [])), "placed": _strings(source.get("placed", []))}


func _restore_outfit(raw: Variant) -> Dictionary:
	var source: Dictionary = raw if raw is Dictionary else {}
	var owned := _strings(source.get("owned", []))
	if owned.is_empty():
		owned = ["moss"]
	return {"worn": String(source.get("worn", "moss")), "owned": owned}


func _restore_consumables(raw: Variant) -> Dictionary:
	var source: Dictionary = raw if raw is Dictionary else {}
	var result := {}
	for kind: String in CONSUMABLE_KINDS:
		result[kind] = maxi(0, int(source.get(kind, 0)))
	return result


func _restore_tales(raw: Variant) -> Dictionary:
	var source: Dictionary = raw if raw is Dictionary else {}
	return {"found": _strings(source.get("found", [])), "seen": _strings(source.get("seen", []))}


func _strings(values: Variant) -> Array[String]:
	var result: Array[String] = []
	if not values is Array:
		return result
	for value: Variant in values:
		if value is String:
			result.append(value)
	return result


func _empty_plots() -> Dictionary:
	var empty: Dictionary = {}
	for area: Rect2i in PLOT_AREAS:
		for y in range(area.position.y, area.end.y):
			for x in range(area.position.x, area.end.x):
				var cell := Vector2i(x, y)
				var reserved := false
				for position: Vector2 in LANTERN_POSITIONS:
					if _cell_center(cell).distance_squared_to(position) <= LANTERN_BASE_RADIUS * LANTERN_BASE_RADIUS:
						reserved = true
						break
				if not reserved:
					empty[cell] = {"crop": "", "growth": 0.0}
	return empty


func _cell_center(cell: Vector2i) -> Vector2:
	return Vector2(cell * CELL_SIZE) + Vector2.ONE * CELL_SIZE / 2.0


func _crop_condition(crop: String, cell: Vector2i) -> bool:
	if crop == "moon_moss":
		return not is_lit(cell)
	if crop == "glow_bell":
		return is_lit(cell)
	return false


func _crop_name(crop: String) -> String:
	return "月苔" if crop == "moon_moss" else "灯铃"


func _crop_requirement(crop: String) -> String:
	return "月苔在阴影中生长，收获露滴。" if crop == "moon_moss" else "灯铃在暖光中生长，收获灯孢。"


func _info(title: String, detail: String, action: String, progress: float, condition: String) -> Dictionary:
	return {"title": title, "detail": detail, "action": action, "progress": progress, "condition": condition}


func _has_keys(data: Dictionary, keys: Array) -> bool:
	for key: String in keys:
		if not data.has(key):
			return false
	return true


func _number_in_range(value: Variant, minimum: float, maximum: float) -> bool:
	if not (value is int or value is float):
		return false
	var number := float(value)
	return is_finite(number) and number >= minimum and number <= maximum


func _integer_in_range(value: Variant, minimum: int, maximum: int) -> bool:
	return _number_in_range(value, minimum, maximum) and float(value) == floorf(float(value))
