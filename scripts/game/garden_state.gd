class_name GardenState
extends RefCounted
## 林间种光：世界与界面共享的经营状态，不依赖节点或渲染。

signal changed
signal harvest_collected(kind: String, amount: int)
signal lantern_restored(index: int)

const CELL_SIZE := 16
const MAP_SIZE := Vector2i(60, 40)
const LANTERN_POSITIONS: Array[Vector2] = [
	Vector2(472, 344), Vector2(616, 296), Vector2(360, 408),
]
const LIGHT_RADIUS := 78.0
const LANTERN_BASE_RADIUS := 22.0
static var BALANCE: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/balance.json"))
static var GROW_SECONDS: Dictionary = {"moon_moss": BALANCE.moon_moss_seconds, "glow_bell": BALANCE.glow_bell_seconds}
static var HARVEST_AMOUNT: int = int(BALANCE.harvest_amount)
const MAX_RESOURCE := 999999
const MAX_HARVESTS := 999999999
const SAVE_VERSION := 2

var plots: Dictionary = {}
var lanterns: Array[Dictionary] = []
var resources: Dictionary = {"dew": 2, "spores": 0, "nightdew": 0}
var selected_crop: String = "moon_moss"
var total_harvests: int = 0
var calendar: Dictionary
var tutorial_seen: Array = []
var saved_at: int = 0
var migration_note := ""
var companion := false
var repair_history: Array[Dictionary] = []
var _archive: Dictionary


func _init() -> void:
	reset()


func reset() -> void:
	plots = _empty_plots()
	lanterns.clear()
	for index in range(LANTERN_POSITIONS.size()):
		lanterns.append({
			"id": GardenSchema.IDS[index],
			"charge": 1.0 if index == 0 else 0.0,
			"position": LANTERN_POSITIONS[index],
			"restored": index == 0,
			"lit": index == 0,
		})
	resources = {"dew": 2, "spores": 0, "nightdew": 0}
	selected_crop = "moon_moss"
	total_harvests = 0
	_archive = GardenSchema.defaults()
	calendar = _archive.calendar.duplicate(true)
	tutorial_seen = []
	saved_at = 0
	migration_note = ""
	companion = false
	repair_history.clear()
	# 两株已适应当地光照的植物，让玩家一开始就能观察生长。
	plots[Vector2i(14, 26)] = {"crop": "moon_moss", "growth": 0.65}
	plots[Vector2i(28, 18)] = {"crop": "glow_bell", "growth": 0.5}
	changed.emit()


func advance(delta: float) -> void:
	if not is_finite(delta) or delta <= 0.0:
		return
	var advanced := false
	if not companion:
		_advance_calendar(delta)
		advanced = true
	for cell: Vector2i in plots:
		var plot: Dictionary = plots[cell]
		var crop: String = plot["crop"]
		var growth: float = plot["growth"]
		if crop.is_empty() or growth >= 1.0 or not growth_condition(cell):
			continue
		var next_growth := growth + delta / float(GROW_SECONDS[crop])
		plot["growth"] = 1.0 if next_growth >= 1.0 - 1.0e-9 else next_growth
		advanced = true
	if advanced:
		changed.emit()


func select_crop(kind: String) -> void:
	if companion or not GROW_SECONDS.has(kind) or selected_crop == kind:
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
	if companion:
		return "先起身，再照料苗床。"
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
	if companion:
		return "先起身，再照料苗床。"
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
	if companion:
		return "先起身，再照料苗床。"
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
	if companion:
		return "先起身，再照料苔灯。"
	if index < 0 or index >= lanterns.size():
		return "这里没有苔灯。"
	var lantern: Dictionary = lanterns[index]
	if bool(lantern["restored"]):
		if index == 0:
			return "母灯会一直亮着。暖光苗床在灯的北边，阴影苗床在西南。"
		lantern["lit"] = not bool(lantern["lit"])
		changed.emit()
		return "苔灯亮起，暖光唤醒灯铃。" if bool(lantern["lit"]) else "苔灯熄灭，阴影让月苔重新生长。"
	var cost := get_restore_cost()
	if int(resources["spores"]) < int(cost.spores) or int(resources["dew"]) < int(cost.dew):
		return "还差 %d 灯孢、%d 露滴。暖光种灯铃，阴影种月苔。" % [maxi(0, int(cost.spores) - int(resources.spores)), maxi(0, int(cost.dew) - int(resources.dew))]
	resources["spores"] = int(resources["spores"]) - int(cost.spores)
	resources["dew"] = int(resources["dew"]) - int(cost.dew)
	repair_history.append({"seconds": calendar.play_seconds, "spores_spent": int(cost.spores), "dew_spent": int(cost.dew), "spores_left": int(resources.spores), "dew_left": int(resources.dew)})
	lantern["restored"] = true
	lantern["lit"] = true
	lantern["charge"] = 1.0
	lantern_restored.emit(index)
	changed.emit()
	if get_restored_count() == lanterns.size():
		return "三盏苔灯都已修复，林间灯路重新相连。"
	return "旧灯亮了，多了一格暖光。这里若种着月苔，可换种灯铃；成熟月苔仍能收获。"


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
		return _info(_crop_name(crop), "收获可得 1 %s，苗床可以重新播种。" % ("露滴" if crop == "moon_moss" else "灯孢"), "E 收获", growth, "可以收获")
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
	if index == 0:
		return _info("母灯", "始终点亮，不耗燃料。北边六格暖光苗床适合灯铃。", "F 灯下坐坐", -1.0, "守着最初的光")
	var title := "东侧旧灯" if index == 1 else "西侧旧灯"
	if bool(lantern.restored):
		return _info(title, "这盏灯改变附近一格的明暗；成熟植物仍可收获。", "E 熄灯" if lantern.lit else "E 点灯", -1.0, "暖光" if lantern.lit else "阴影")
	var cost := get_restore_cost()
	var enough := int(resources.spores) >= int(cost.spores) and int(resources.dew) >= int(cost.dew)
	return _info(title, "修复需 %d 灯孢 + %d 露滴，会多一格暖光。" % [cost.spores, cost.dew], "E 修复", -1.0, "材料齐了" if enough else "材料还不够")


func get_restored_count() -> int:
	var count := 0
	for lantern: Dictionary in lanterns:
		if bool(lantern["restored"]):
			count += 1
	return count


func get_restore_cost() -> Dictionary:
	var cost: Dictionary = BALANCE.restore_costs[mini(get_restored_count() - 1, 1)]
	return {"spores": int(cost.spores), "dew": int(cost.dew)}


func _advance_calendar(delta: float) -> void:
	# 只消费当前阶段的剩余时间，单次超长帧不连跳多个游戏日。
	if calendar.phase == "day":
		var amount := minf(delta, float(BALANCE.day_seconds) - float(calendar.day_elapsed_seconds))
		calendar.play_seconds += amount
		calendar.day_elapsed_seconds += amount
		if calendar.day_elapsed_seconds >= float(BALANCE.day_seconds):
			calendar.phase = "dusk"
			calendar.phase_elapsed_seconds = 0.0
	else:
		calendar.phase_elapsed_seconds = minf(float(BALANCE.dusk_seconds), float(calendar.phase_elapsed_seconds) + delta)
		if calendar.phase_elapsed_seconds >= float(BALANCE.dusk_seconds):
			sleep_to_next_day()


func sleep_to_next_day() -> bool:
	if companion or calendar.phase != "dusk":
		return false
	calendar.day = int(calendar.day) + 1
	if calendar.day > 8:
		calendar.day = 1
		var season_index := GardenSchema.SEASONS.find(calendar.season) + 1
		if season_index == 4:
			season_index = 0
			calendar.year = int(calendar.year) + 1
		calendar.season = GardenSchema.SEASONS[season_index]
	calendar.phase = "day"
	calendar.day_elapsed_seconds = 0.0
	calendar.phase_elapsed_seconds = 0.0
	changed.emit()
	return true


func grow_offline(now: int) -> float:
	if saved_at <= 0 or now <= saved_at:
		return 0.0
	var elapsed := minf(float(now - saved_at), float(BALANCE.offline_cap_seconds))
	# 不调用 advance：离线只长已有作物，不推进日历或产出资源。
	for cell: Vector2i in plots:
		var plot: Dictionary = plots[cell]
		if plot.crop != "" and growth_condition(cell):
			plot.growth = minf(1.0, float(plot.growth) + elapsed / float(GROW_SECONDS[plot.crop]))
	saved_at = now
	return elapsed


func snapshot() -> Dictionary:
	var result := _archive.duplicate(true)
	result.version = SAVE_VERSION
	result.content_revision = "slice_a_12_v1"
	result.selected_crop = selected_crop
	result.resources = resources.duplicate()
	result.summary.total_harvests = total_harvests
	result.calendar = calendar.duplicate(true)
	result.tutorial_seen = tutorial_seen.duplicate()
	result.saved_at = saved_at
	result.plots_by_zone = {"plum_garden": GardenSchema.SLICE_AREAS.duplicate(true)}
	result.crops = []
	for cell: Vector2i in plots:
		var plot: Dictionary = plots[cell]
		if plot.crop != "":
			result.crops.append({"zone": "plum_garden", "x": cell.x, "y": cell.y, "crop": plot.crop, "growth": plot.growth})
	result.lanterns = []
	for lantern: Dictionary in lanterns:
		result.lanterns.append({"id": lantern.id, "restored": lantern.restored, "lit": lantern.lit, "charge": lantern.charge})
	return result


func restore(data: Dictionary) -> bool:
	var candidate := GardenSchema.normalize(data)
	if candidate.is_empty():
		return false
	var next_plots := _empty_plots()
	var next_note := ""
	var refund := {"dew": 0, "spores": 0}
	# M1 内容迁移：只对 legacy_49 执行一次；不与格式迁移混合。
	var upgrading: bool = candidate.content_revision == "legacy_49"
	for entry: Dictionary in candidate.crops:
		var cell := Vector2i(int(entry.x), int(entry.y))
		if next_plots.has(cell):
			next_plots[cell] = {"crop": entry.crop, "growth": float(entry.growth)}
		elif upgrading:
			refund["dew" if entry.crop == "moon_moss" else "spores"] += 1
	if upgrading:
		candidate.resources.dew = mini(MAX_RESOURCE, int(candidate.resources.dew) + int(refund.dew))
		candidate.resources.spores = mini(MAX_RESOURCE, int(candidate.resources.spores) + int(refund.spores))
		if refund.dew + refund.spores > 0:
			next_note = "旧苗床折算为 %d 露滴、%d 灯孢。" % [refund.dew, refund.spores]
		if not candidate.lanterns[0].lit:
			next_note += "母灯现在会一直亮着。"
		candidate.lanterns[0].lit = true
		candidate.lanterns[0].charge = 1.0
	var next_lanterns: Array[Dictionary] = []
	for index in range(3):
		var entry: Dictionary = candidate.lanterns[index].duplicate()
		entry.position = LANTERN_POSITIONS[index]
		next_lanterns.append(entry)
	# 成功后一次提交，失败时不改任何活动状态。
	_archive = candidate
	plots = next_plots
	lanterns = next_lanterns
	resources = candidate.resources.duplicate()
	selected_crop = candidate.selected_crop
	total_harvests = int(candidate.summary.total_harvests)
	calendar = candidate.calendar.duplicate(true)
	tutorial_seen = candidate.tutorial_seen.duplicate()
	saved_at = int(candidate.saved_at)
	migration_note = next_note
	changed.emit()
	return true


func _empty_plots() -> Dictionary:
	return GardenSchema.layout(GardenSchema.SLICE_AREAS)


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
