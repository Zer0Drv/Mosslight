class_name GardenState
extends RefCounted
## 林间种光：世界与界面共享的经营状态，不依赖节点或渲染。

signal changed
signal harvest_collected(kind: String, amount: int)
signal lantern_restored(index: int)

const CELL_SIZE := 16
const MAP_SIZE := Vector2i(60, 40)
const PLOT_AREAS: Array[Rect2i] = [
	Rect2i(26, 18, 4, 4), Rect2i(32, 21, 5, 4),
	Rect2i(36, 15, 3, 3), Rect2i(22, 26, 3, 3),
]
const LANTERN_POSITIONS: Array[Vector2] = [
	Vector2(472, 344), Vector2(616, 296), Vector2(360, 408),
]
const LIGHT_RADIUS := 78.0
const LANTERN_BASE_RADIUS := 22.0
const GROW_SECONDS := {"moon_moss": 18.0, "glow_bell": 24.0}
const RESTORE_SPORES := 6
const RESTORE_DEW := 4
const HARVEST_AMOUNT := 3
const MAX_RESOURCE := 999999
const MAX_HARVESTS := 999999999
const SAVE_VERSION := 1

var plots: Dictionary = {}
var lanterns: Array[Dictionary] = []
var resources: Dictionary = {"dew": 2, "spores": 0}
var selected_crop: String = "moon_moss"
var total_harvests: int = 0


func _init() -> void:
	reset()


func reset() -> void:
	plots = _empty_plots()
	lanterns.clear()
	for index in range(LANTERN_POSITIONS.size()):
		lanterns.append({
			"position": LANTERN_POSITIONS[index],
			"restored": index == 0,
			"lit": index == 0,
		})
	resources = {"dew": 2, "spores": 0}
	selected_crop = "moon_moss"
	total_harvests = 0
	# 两株已适应当地光照的植物，让玩家一开始就能观察生长。
	plots[Vector2i(34, 23)] = {"crop": "moon_moss", "growth": 0.65}
	plots[Vector2i(28, 20)] = {"crop": "glow_bell", "growth": 0.5}
	changed.emit()


func advance(delta: float) -> void:
	if not is_finite(delta) or delta <= 0.0:
		return
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
	if int(resources["spores"]) < RESTORE_SPORES or int(resources["dew"]) < RESTORE_DEW:
		return "修复需要 %d 灯孢和 %d 露滴。灯铃产灯孢，月苔产露滴。" % [RESTORE_SPORES, RESTORE_DEW]
	resources["spores"] = int(resources["spores"]) - RESTORE_SPORES
	resources["dew"] = int(resources["dew"]) - RESTORE_DEW
	lantern["restored"] = true
	lantern["lit"] = true
	lantern_restored.emit(index)
	changed.emit()
	if get_restored_count() == lanterns.size():
		return "三盏苔灯都已修复，林间灯路重新相连。"
	return "修好了第 %d 盏苔灯。可以在新的暖光下栽种灯铃。" % (index + 1)


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
		return _info(_crop_name(crop), "收获可得 3 %s，苗床可以重新播种。" % ("露滴" if crop == "moon_moss" else "灯孢"), "E 收获", growth, "可以收获")
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
	var enough := int(resources["spores"]) >= RESTORE_SPORES and int(resources["dew"]) >= RESTORE_DEW
	return _info(title, "需要 6 灯孢 + 4 露滴。修复后，暖光照到附近苗床。", "E 修复", -1.0, "材料已备齐" if enough else "尚缺修复材料")


func get_restored_count() -> int:
	var count := 0
	for lantern: Dictionary in lanterns:
		if bool(lantern["restored"]):
			count += 1
	return count


func snapshot() -> Dictionary:
	var saved_plots: Array[Dictionary] = []
	for cell: Vector2i in plots:
		var plot: Dictionary = plots[cell]
		saved_plots.append({"x": cell.x, "y": cell.y, "crop": plot["crop"], "growth": plot["growth"]})
	var saved_lanterns: Array[Dictionary] = []
	for lantern: Dictionary in lanterns:
		saved_lanterns.append({"restored": lantern["restored"], "lit": lantern["lit"]})
	return {
		"version": SAVE_VERSION,
		"selected_crop": selected_crop,
		"resources": resources.duplicate(),
		"total_harvests": total_harvests,
		"plots": saved_plots,
		"lanterns": saved_lanterns,
	}


func restore(data: Dictionary) -> bool:
	# 所有校验都在临时结构完成；任何失败都不触碰正在游玩的状态。
	if not _exact_keys(data, ["version", "selected_crop", "resources", "total_harvests", "plots", "lanterns"]):
		return false
	if not _integer_in_range(data["version"], SAVE_VERSION, SAVE_VERSION):
		return false
	if not data["selected_crop"] is String or not GROW_SECONDS.has(data["selected_crop"]):
		return false
	if not _integer_in_range(data["total_harvests"], 0, MAX_HARVESTS):
		return false
	if not data["resources"] is Dictionary:
		return false
	var stored_resources: Dictionary = data["resources"]
	if not _exact_keys(stored_resources, ["dew", "spores"]):
		return false
	if not _integer_in_range(stored_resources["dew"], 0, MAX_RESOURCE) or not _integer_in_range(stored_resources["spores"], 0, MAX_RESOURCE):
		return false
	if not data["plots"] is Array or not data["lanterns"] is Array:
		return false
	var restored_plots := _empty_plots()
	var stored_plots: Array = data["plots"]
	if stored_plots.size() != restored_plots.size():
		return false
	var seen: Dictionary = {}
	for entry: Variant in stored_plots:
		if not entry is Dictionary or not _exact_keys(entry, ["x", "y", "crop", "growth"]):
			return false
		if not _integer_in_range(entry["x"], 0, MAP_SIZE.x - 1) or not _integer_in_range(entry["y"], 0, MAP_SIZE.y - 1):
			return false
		var cell := Vector2i(int(entry["x"]), int(entry["y"]))
		if not restored_plots.has(cell) or seen.has(cell):
			return false
		if not entry["crop"] is String:
			return false
		var crop: String = entry["crop"]
		if not crop.is_empty() and not GROW_SECONDS.has(crop):
			return false
		if not _number_in_range(entry["growth"], 0.0, 1.0):
			return false
		var growth := float(entry["growth"])
		if crop.is_empty() and growth != 0.0:
			return false
		seen[cell] = true
		restored_plots[cell] = {"crop": crop, "growth": growth}
	var stored_lanterns: Array = data["lanterns"]
	if stored_lanterns.size() != LANTERN_POSITIONS.size():
		return false
	var restored_lanterns: Array[Dictionary] = []
	for index in range(stored_lanterns.size()):
		var entry: Variant = stored_lanterns[index]
		if not entry is Dictionary or not _exact_keys(entry, ["restored", "lit"]):
			return false
		if not entry["restored"] is bool or not entry["lit"] is bool:
			return false
		if (bool(entry["lit"]) and not bool(entry["restored"])) or (index == 0 and not bool(entry["restored"])):
			return false
		restored_lanterns.append({"position": LANTERN_POSITIONS[index], "restored": entry["restored"], "lit": entry["lit"]})
	plots = restored_plots
	lanterns = restored_lanterns
	resources = {"dew": int(stored_resources["dew"]), "spores": int(stored_resources["spores"])}
	selected_crop = String(data["selected_crop"])
	total_harvests = int(data["total_harvests"])
	changed.emit()
	return true


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


func _exact_keys(data: Dictionary, keys: Array[String]) -> bool:
	if data.size() != keys.size():
		return false
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
