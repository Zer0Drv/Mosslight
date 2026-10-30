extends SceneTree
## Godot --headless --path . --script res://tests/migration_test.gd
## M0 四条迁移测试：v1 全量迁移 / v1 部分损坏 / v2 往返 / 未来版本拒绝。
## 全部在内存里跑，不写任何文件。

const Garden = preload("res://scripts/game/garden_state.gd")
var _failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_check_full_v1_migration()
	_check_broken_v1_is_rejected()
	_check_v2_round_trip()
	_check_future_version_is_rejected()
	if _failures == 0:
		print("MIGRATION PASS: v1 全量迁移、v1 损坏拒绝、v2 往返、未来版本拒绝。")
	else:
		printerr("MIGRATION FAIL: %d 项检查失败。" % _failures)
	quit(0 if _failures == 0 else 1)


## 与真实存档同构的 v1 文档：按 v1 的四块苗床铺满格子，其中 4 株非空，
## 只有 (27,19) 落在新布局里，其余三株必须被折算成资源。
func _v1_fixture() -> Dictionary:
	var plots: Array[Dictionary] = []
	var planted := {
		Vector2i(28, 20): {"crop": "glow_bell", "growth": 1.0},
		Vector2i(24, 27): {"crop": "moon_moss", "growth": 1.0},
		Vector2i(23, 28): {"crop": "moon_moss", "growth": 1.0},
		# 一株落在新布局里，必须被原样保留。
		Vector2i(27, 19): {"crop": "glow_bell", "growth": 0.4},
	}
	var old_areas: Array[Rect2i] = [
		Rect2i(26, 18, 4, 4), Rect2i(32, 21, 5, 4),
		Rect2i(36, 15, 3, 3), Rect2i(22, 26, 3, 3),
	]
	for area: Rect2i in old_areas:
		for y in range(area.position.y, area.end.y):
			for x in range(area.position.x, area.end.x):
				var cell := Vector2i(x, y)
				var entry := {"x": x, "y": y, "crop": "", "growth": 0.0}
				if planted.has(cell):
					entry["crop"] = planted[cell]["crop"]
					entry["growth"] = planted[cell]["growth"]
				plots.append(entry)
	return {
		"version": 1,
		"selected_crop": "moon_moss",
		"resources": {"dew": 1, "spores": 0},
		"total_harvests": 1,
		"plots": plots,
		"lanterns": [
			{"restored": true, "lit": true},
			{"restored": false, "lit": false},
			{"restored": false, "lit": false},
		],
	}


func _check_full_v1_migration() -> void:
	var garden := Garden.new()
	var ok := garden.restore(_v1_fixture())
	_check(ok, "v1 全量档应迁移成功。")
	if not ok:
		return
	_check(int(garden.snapshot()["version"]) == Garden.SAVE_VERSION, "迁移后版本应为 2。")
	var layout := {}
	for area: Rect2i in Garden.PLOT_AREAS:
		for y in range(area.position.y, area.end.y):
			for x in range(area.position.x, area.end.x):
				layout[Vector2i(x, y)] = true
	var crops: Array = garden.snapshot()["crops"]
	var outside := 0
	for entry: Variant in crops:
		var data: Dictionary = entry
		if not layout.has(Vector2i(int(data["x"]), int(data["y"]))):
			outside += 1
	_check(outside == 0, "迁移后所有作物都必须落在新苗床布局内，越界 %d 株。" % outside)
	_check(crops.size() == 1, "只有落在新布局里的那一株被保留，实际 %d。" % crops.size())
	if crops.size() == 1:
		_check(int(crops[0]["x"]) == 27 and int(crops[0]["y"]) == 19, "保留的应是 (27,19)。")
		_check(is_equal_approx(float(crops[0]["growth"]), 0.4), "保留株的生长进度应原样带过来。")
	# 3 株落在旧布局之外：2 月苔 → 2 露滴，1 灯铃 → 1 灯孢，叠加在原资源上。
	var res: Dictionary = garden.snapshot()["resources"]
	_check(int(res["dew"]) == 3, "露滴应为 1 + 2 折算 = 3，实际 %d。" % int(res["dew"]))
	_check(int(res["spores"]) == 1, "灯孢应为 0 + 1 折算 = 1，实际 %d。" % int(res["spores"]))
	_check(int(res["nightdew"]) == 0, "夜露默认应为 0。")
	_check(not garden.migration_note.is_empty(), "折算发生时 migration_note 必须非空，便于提示玩家。")
	_check(garden.lanterns.size() == 3, "迁移后应补齐三盏灯。")
	_check(String(garden.lanterns[0]["id"]) == "plum_0" and bool(garden.lanterns[0]["restored"]), "第 0 盏灯应保留并带 id。")
	_check(int(garden.snapshot()["summary"]["total_harvests"]) == 1, "总收获数应保留。")
	_check(String(garden.snapshot()["calendar"]["season"]) == "spring", "日历应补成春·第 1 天。")
	_check(int(garden.snapshot()["calendar"]["day"]) == 1, "日历天数应为 1。")


func _check_broken_v1_is_rejected() -> void:
	var cases := {
		"苗床条目缺字段": func(d: Dictionary) -> void: (d["plots"][0] as Dictionary).erase("growth"),
		"未知作物": func(d: Dictionary) -> void: (d["plots"][0] as Dictionary)["crop"] = "turnip",
		"生长越界": func(d: Dictionary) -> void: (d["plots"][0] as Dictionary)["growth"] = 1.5,
		"资源缺键": func(d: Dictionary) -> void: (d["resources"] as Dictionary).erase("spores"),
		"第 0 盏灯未修复": func(d: Dictionary) -> void: (d["lanterns"][0] as Dictionary)["restored"] = false,
		"损坏却点亮": func(d: Dictionary) -> void: (d["lanterns"][1] as Dictionary)["lit"] = true,
	}
	for label: String in cases:
		var data: Dictionary = _v1_fixture()
		var mutate: Callable = cases[label]
		mutate.call(data)
		var garden := Garden.new()
		var before := garden.snapshot().duplicate(true)
		_check(not garden.restore(data), "v1 损坏档应被拒绝：" + label)
		_check(garden.snapshot() == before, "v1 拒绝时不得修改状态：" + label)
		_check(garden.migration_note.is_empty(), "v1 拒绝时 migration_note 应为空：" + label)


func _check_v2_round_trip() -> void:
	var source := Garden.new()
	source.advance(12.5)
	source.interact_lantern(0)
	source.select_crop("glow_bell")
	var first := source.snapshot().duplicate(true)
	first["future_field"] = {"anything": true}
	var loaded := Garden.new()
	_check(loaded.restore(first), "v2 档应被接受（未知字段忽略）。")
	_check(loaded.snapshot() == source.snapshot(), "v2 往返后状态应逐字段一致。")
	_check(loaded.migration_note.is_empty(), "v2 正常读取时不应产生迁移备注。")
	var again := loaded.snapshot()
	var second := Garden.new()
	_check(second.restore(again), "v2 二次往返应成功。")
	_check(second.snapshot() == again, "v2 二次往返应保持不变。")


func _check_future_version_is_rejected() -> void:
	var data := Garden.new().snapshot()
	data["version"] = 3
	var garden := Garden.new()
	var before := garden.snapshot().duplicate(true)
	_check(not garden.restore(data), "未来版本（3）应被拒绝。")
	_check(garden.snapshot() == before, "拒绝未来版本时不得修改状态。")
	data = Garden.new().snapshot()
	data["version"] = 0
	_check(not garden.restore(data), "版本 0 应被拒绝。")
	data = Garden.new().snapshot()
	data["version"] = "2"
	_check(not garden.restore(data), "字符串版本号应被拒绝。")


func _check(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)


func _fail(message: String) -> void:
	_failures += 1
	printerr("MIGRATION FAIL: " + message)
