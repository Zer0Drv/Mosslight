extends SceneTree
## 先导入项目，再运行：Godot --headless --path . --script res://tests/smoke_test.gd
## 覆盖种光规则、存档边界，以及真实场景的输入、暂停和物理碰撞。
## M0：数值改为 A1 定稿（月苔 90s / 灯铃 120s / 收获 1 / 修灯 12+8·24+16·36+24 / 12 格苗床）。

const Garden = preload("res://scripts/game/garden_state.gd")
var _failures: int = 0
var _harvest_events: Array[Dictionary] = []
var _restored_events: Array[int] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_check_state_machine()
	_check_snapshot_validation()
	_check_inputs()
	await _check_main_scene()
	paused = false
	if _failures == 0:
		print("SMOKE PASS: 种光规则、资源经营、修灯、宽松存档恢复、场景输入、暂停与碰撞均通过。")
	else:
		printerr("SMOKE FAIL: %d 项检查失败。" % _failures)
	quit(0 if _failures == 0 else 1)


func _check_state_machine() -> void:
	var garden := Garden.new()
	garden.harvest_collected.connect(func(kind: String, amount: int) -> void: _harvest_events.append({"kind": kind, "amount": amount}))
	garden.lantern_restored.connect(func(index: int) -> void: _restored_events.append(index))
	_check(garden.get_restored_count() == 1, "开局应修好一盏灯。")
	_check(garden.resources == {"dew": 2, "spores": 0, "nightdew": 0}, "开局资源应为 2 露滴、0 灯孢、0 夜露。")
	_check(garden.plots.size() == 12, "灯圃应有 12 格苗床。")
	_check(garden.calendar.get("season") == "spring" and int(garden.calendar.get("day")) == 1, "开局应为春·第 1 天。")
	_check(garden.growth_condition(Vector2i(14, 26)) and garden.growth_condition(Vector2i(26, 18)), "预种植物应处于适宜光照。")
	for cell: Vector2i in garden.plots:
		for lamp: Dictionary in garden.lanterns:
			_check(_center(cell).distance_to(lamp["position"]) > Garden.LANTERN_BASE_RADIUS, "苗床不应与灯脚交互范围重叠。")
	var lit := _empty_cell(garden, true)
	var dark := _empty_cell(garden, false)
	_check(lit.x >= 0 and dark.x >= 0, "开局应同时存在空闲暖光格和阴影格。")
	if lit.x < 0 or dark.x < 0:
		return
	var before := garden.snapshot()
	garden.plant_or_harvest(Vector2i(-1, -1))
	garden.nourish(Vector2i(-1, -1))
	garden.clear_crop(Vector2i(-1, -1))
	garden.interact_lantern(-1)
	garden.interact_lantern(3)
	garden.select_crop("unknown")
	garden.advance(NAN)
	garden.advance(INF)
	garden.advance(-1.0)
	_check(garden.snapshot() == before, "无效操作不应修改经营状态。")
	_check(garden.get_plot_info(lit)["progress"] == -1.0, "空苗床应没有生长进度。")
	# 月苔在暖光中等待，熄灯后才生长（90 秒成熟，45 秒到 50%）。
	garden.plant_or_harvest(lit)
	garden.advance(45.0)
	_check(is_zero_approx(garden.plots[lit]["growth"]), "月苔不应在暖光中生长。")
	var dew_before := int(garden.resources["dew"])
	garden.nourish(lit)
	_check(garden.resources["dew"] == dew_before, "光照不合适的露养不应扣资源。")
	garden.interact_lantern(0)
	garden.advance(45.0)
	_check(is_equal_approx(garden.plots[lit]["growth"], 0.5), "熄灯后月苔应在 45 秒长到 50%。")
	garden.interact_lantern(0)
	garden.advance(45.0)
	_check(is_equal_approx(garden.plots[lit]["growth"], 0.5), "重新点灯应暂停月苔生长。")
	garden.clear_crop(lit)
	_check(garden.plots[lit] == {"crop": "", "growth": 0.0}, "移除未熟植物应归还可重种空格。")
	# 灯铃只在暖光中生长，成熟收获只支付一次（120 秒成熟，60 秒到 50%）。
	garden.select_crop("glow_bell")
	garden.plant_or_harvest(dark)
	garden.advance(120.0)
	_check(is_zero_approx(garden.plots[dark]["growth"]), "灯铃不应在阴影中生长。")
	garden.plant_or_harvest(lit)
	garden.advance(60.0)
	_check(is_equal_approx(garden.plots[lit]["growth"], 0.5), "灯铃应在 60 秒长到 50%。")
	garden.nourish(lit)
	_check(is_equal_approx(garden.plots[lit]["growth"], 0.85) and garden.resources["dew"] == dew_before - 1, "露养应花 1 露滴并增加 35% 进度。")
	garden.advance(120.0)
	_check(garden.plots[lit]["growth"] == 1.0, "生长进度应封顶为 1。")
	dew_before = int(garden.resources["dew"])
	garden.nourish(lit)
	garden.clear_crop(lit)
	_check(garden.resources["dew"] == dew_before and garden.plots[lit]["crop"] == "glow_bell", "成熟植物不应被露养扣费或被 R 误删。")
	garden.plant_or_harvest(lit)
	_check(garden.resources["spores"] == 1 and garden.total_harvests == 1, "收获灯铃应得到 1 灯孢并累计一次收获。")
	_check(_harvest_events.size() == 1 and _harvest_events[0] == {"kind": "glow_bell", "amount": 1}, "收获信号应包含作物与资源产量。")
	garden.plant_or_harvest(lit)
	_check(garden.resources["spores"] == 1 and garden.total_harvests == 1, "成熟作物不能被重复领取。")
	garden.clear_crop(dark)
	garden.select_crop("moon_moss")
	garden.plant_or_harvest(dark)
	garden.advance(90.0)
	garden.plant_or_harvest(dark)
	_check(garden.resources["dew"] == dew_before + 1, "阴影中的月苔应产出 1 露滴。")
	_check(_harvest_events.size() == 2 and _harvest_events[1]["kind"] == "moon_moss", "两种植物应发出不同收获类型。")
	# 材料不足不能扣费；修复成本逐盏递增。
	before = garden.snapshot()
	garden.interact_lantern(1)
	_check(garden.snapshot() == before, "材料不足不能修复或扣资源。")
	_check(int(garden.get_restore_cost(0)["spores"]) == 12 and int(garden.get_restore_cost(1)["spores"]) == 24 and int(garden.get_restore_cost(2)["spores"]) == 36, "修复成本应按盏递增 12/24/36 灯孢。")
	garden.resources = {"dew": 40, "spores": 60, "nightdew": 0}
	garden.interact_lantern(1)
	_check(garden.get_restored_count() == 2 and garden.resources == {"dew": 24, "spores": 36, "nightdew": 0}, "修复第二灯应花 16 露滴与 24 灯孢。")
	_check(garden.lanterns[1]["lit"], "修复完成的灯应立即点亮。")
	var victory := garden.interact_lantern(2)
	_check(garden.get_restored_count() == 3 and garden.resources == {"dew": 0, "spores": 0, "nightdew": 0}, "第三灯应花 24 露滴与 36 灯孢。")
	_check(victory.contains("重新相连") and _restored_events == [1, 2], "全部修复应提示灯路相连，并只发一次修复信号。")
	garden.interact_lantern(2)
	_check(not garden.lanterns[2]["lit"] and garden.get_restored_count() == 3, "熄灯不能撤销修复进度。")
	garden.interact_lantern(2)
	garden.nourish(lit)
	_check(garden.resources == {"dew": 0, "spores": 0, "nightdew": 0}, "开关灯不耗资源，无露滴不能透支露养。")
	garden.reset()
	_check(garden.total_harvests == 0 and garden.get_restored_count() == 1, "重置应恢复开局状态。")


func _check_snapshot_validation() -> void:
	var garden := Garden.new()
	garden.select_crop("glow_bell")
	garden.advance(3.25)
	garden.interact_lantern(0)
	var valid := garden.snapshot()
	var parsed: Variant = JSON.parse_string(JSON.stringify(valid, "", true, true))
	var restored := Garden.new()
	_check(parsed is Dictionary and restored.restore(parsed), "快照应能经过 JSON 编解码后恢复。")
	_check(restored.snapshot() == valid, "JSON 恢复应完整保留资源、作物、灯与日历。")
	_check(restored.lanterns[0]["position"] == Garden.LANTERN_POSITIONS[0], "恢复应重建固定灯的位置。")
	var exported := garden.snapshot()
	exported["resources"]["dew"] = 999
	exported["crops"] = []
	_check(garden.snapshot() == valid, "外部修改快照不应影响正在游玩的状态。")
	var bad := valid.duplicate(true)
	bad["version"] = 99
	_reject_snapshot(garden, bad, "未知版本")
	bad = valid.duplicate(true)
	bad.erase("crops")
	_reject_snapshot(garden, bad, "缺失字段")
	bad = valid.duplicate(true)
	bad["calendar"]["season"] = "monsoon"
	_reject_snapshot(garden, bad, "未知季节")
	bad = valid.duplicate(true)
	bad["calendar"]["day"] = 9
	_reject_snapshot(garden, bad, "天数越界")
	for value: Variant in [-1, 0.5, Garden.MAX_RESOURCE + 1, INF, "2", true]:
		bad = valid.duplicate(true)
		bad["resources"]["dew"] = value
		_reject_snapshot(garden, bad, "非法资源值 %s" % str(value))
	bad = valid.duplicate(true)
	bad["resources"].erase("nightdew")
	_reject_snapshot(garden, bad, "缺少夜露")
	bad = valid.duplicate(true)
	bad["summary"]["total_harvests"] = -1
	_reject_snapshot(garden, bad, "负收获计数")
	bad = valid.duplicate(true)
	bad["crops"] = [{"x": 20, "y": 20, "crop": "moon_moss", "growth": 0.5}]
	_reject_snapshot(garden, bad, "苗床外地格")
	bad = valid.duplicate(true)
	bad["crops"] = [{"x": 14, "y": 26, "crop": "unknown", "growth": 0.5}]
	_reject_snapshot(garden, bad, "未知作物")
	for value: Variant in [-0.1, 1.1, NAN, INF, "0.5"]:
		bad = valid.duplicate(true)
		bad["crops"] = [{"x": 14, "y": 26, "crop": "moon_moss", "growth": value}]
		_reject_snapshot(garden, bad, "非法生长值 %s" % str(value))
	bad = valid.duplicate(true)
	bad["crops"] = [
		{"x": 14, "y": 26, "crop": "moon_moss", "growth": 0.5},
		{"x": 14, "y": 26, "crop": "glow_bell", "growth": 0.5},
	]
	_reject_snapshot(garden, bad, "重复地格")
	bad = valid.duplicate(true)
	bad["lanterns"][1]["lit"] = true
	_reject_snapshot(garden, bad, "损坏却点亮的灯")
	bad = valid.duplicate(true)
	bad["lanterns"][0]["restored"] = false
	_reject_snapshot(garden, bad, "丢失初始修复灯")
	bad = valid.duplicate(true)
	bad["lanterns"][1]["restored"] = 1
	_reject_snapshot(garden, bad, "非布尔灯状态")
	bad = valid.duplicate(true)
	bad["lanterns"][1]["charge"] = 1.5
	_reject_snapshot(garden, bad, "灯火浓度越界")
	bad = valid.duplicate(true)
	bad["lanterns"].pop_back()
	_reject_snapshot(garden, bad, "缺失灯")
	bad = valid.duplicate(true)
	bad["lanterns"][2]["id"] = "not_a_lamp"
	_reject_snapshot(garden, bad, "未知灯 id")
	# v2 起允许未知字段：旧字段与新字段混在一起也必须读得进去。
	var extra := valid.duplicate(true)
	extra["future_field"] = {"anything": true}
	var extra_garden := Garden.new()
	_check(extra_garden.restore(extra), "v2 应忽略未知字段。")
	_check(extra_garden.snapshot() == valid, "忽略未知字段后状态应与原档一致。")


func _reject_snapshot(garden: GardenState, data: Dictionary, reason: String) -> void:
	var before := garden.snapshot()
	_check(not garden.restore(data), "restore 应拒绝：" + reason)
	_check(garden.snapshot() == before, "restore 失败应保持原状态：" + reason)


func _check_inputs() -> void:
	var required := {
		"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
		"move_up": [KEY_W, KEY_UP], "move_down": [KEY_S, KEY_DOWN],
		"interact": [KEY_E, KEY_SPACE], "pause": [KEY_ESCAPE],
		"toggle_fullscreen": [KEY_F11], "select_moon": [KEY_1],
		"select_bell": [KEY_2], "nourish": [KEY_Q], "clear_crop": [KEY_R],
		"light_overlay": [KEY_TAB], "mute": [KEY_M],
	}
	for action: String in required:
		_check(InputMap.has_action(action), "缺少输入动作：" + action)
		if not InputMap.has_action(action):
			continue
		for code: int in required[action]:
			var found := false
			for event: InputEvent in InputMap.action_get_events(action):
				if event is InputEventKey and event.physical_keycode == code:
					found = true
			_check(found, "%s 未绑定 %s。" % [action, OS.get_keycode_string(code)])


func _check_main_scene() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	if packed == null:
		_fail("无法加载主场景。")
		return
	var game := packed.instantiate()
	root.add_child(game)
	current_scene = game
	await process_frame
	var farm := game.get_node_or_null("Farm") as FarmWorld
	var player := game.get_node_or_null("Player") as FarmPlayer
	var hud := game.get_node_or_null("HUD") as FarmHUD
	var garden: GardenState = game.get("garden")
	if farm == null or player == null or hud == null or garden == null:
		_fail("主场景缺少 Farm、Player、HUD 或 garden 状态。")
		game.queue_free()
		await process_frame
		return
	_check(player.global_position.is_equal_approx(farm.get_spawn_position()), "角色应在农场出生点初始化。")
	await _check_movement(player, farm)
	await _check_scene_gardening(garden, player, farm)
	paused = false
	game.queue_free()
	await process_frame


func _check_movement(player: FarmPlayer, farm: FarmWorld) -> void:
	var start := player.global_position
	await _walk("move_right", 8)
	_check(player.global_position.x > start.x + 1.0, "向右输入应使角色向右移动。")
	_check(is_equal_approx(player.global_position.y, start.y), "单轴移动不应产生纵向漂移。")
	_check(player.facing == Vector2.RIGHT, "移动应更新交互朝向。")
	Input.action_press("move_right")
	Input.action_press("move_down")
	await physics_frame
	await physics_frame
	_check(is_equal_approx(player.velocity.length(), player.move_speed), "斜向移动不应比单轴移动更快。")
	Input.action_release("move_right")
	Input.action_release("move_down")
	await physics_frame
	player.global_position = farm.to_global(Vector2(8, 64))
	await _walk("move_left", 15)
	_check(farm.to_local(player.global_position).x >= 3.0, "角色不应穿过地图左边界。")
	var house := FarmWorld.HOUSE_RECT
	player.global_position = farm.to_global(Vector2(house.get_center().x, house.end.y + 18.0))
	await _walk("move_up", 25)
	_check(farm.to_local(player.global_position).y >= house.end.y + 5.8, "角色脚部碰撞应阻止进入房屋。")
	var pond := FarmWorld.POND_RECT
	player.global_position = farm.to_global(Vector2(pond.position.x - 18.0, pond.get_center().y))
	await _walk("move_right", 25)
	_check(farm.to_local(player.global_position).x <= pond.position.x - 3.8, "角色不应走入池塘。")
	player.global_position = farm.get_spawn_position()


func _check_scene_gardening(garden: GardenState, player: FarmPlayer, farm: FarmWorld) -> void:
	garden.reset()
	var cell := _empty_cell(garden, true)
	if cell.x < 0:
		_fail("场景中没有可以检验的暖光空格。")
		return
	player.global_position = farm.to_global(_center(cell)) + Vector2(0, Garden.CELL_SIZE)
	player.facing = Vector2.UP
	await _press_action("select_bell")
	_check(garden.selected_crop == "glow_bell", "数字 2 对应动作应选择灯铃。")
	await _press_action("interact")
	_check(garden.plots[cell]["crop"] == "glow_bell", "主场景交互应在角色前方播种。")
	await _press_action("nourish")
	_check(garden.resources["dew"] == 1 and garden.plots[cell]["growth"] >= 0.35, "Q 对应动作应给前方植物露养。")
	await _press_action("clear_crop")
	_check(garden.plots[cell]["crop"] == "", "R 对应动作应移除前方未熟植物。")
	await _press_action("select_moon")
	_check(garden.selected_crop == "moon_moss", "数字 1 对应动作应选择月苔。")
	await _press_action("select_bell")
	await _press_action("interact")
	var remaining := (1.0 - float(garden.plots[cell]["growth"])) * float(Garden.GROW_SECONDS["glow_bell"])
	garden.advance(maxf(0.0, remaining - 0.3))
	await _press_action("pause")
	_check(paused, "暂停动作应暂停场景树。")
	var paused_growth := float(garden.plots[cell]["growth"])
	var paused_position := player.global_position
	Input.action_press("move_right")
	await create_timer(0.45, true, false, true).timeout
	Input.action_release("move_right")
	_check(player.global_position.is_equal_approx(paused_position), "暂停期间角色不应移动。")
	_check(is_equal_approx(float(garden.plots[cell]["growth"]), paused_growth), "暂停期间经营状态不应继续生长。")
	await _press_action("interact")
	_check(garden.total_harvests == 0, "暂停期间交互不应收获。")
	await _press_action("pause")
	_check(not paused, "再次暂停动作应恢复游戏。")
	await create_timer(0.45, false, false, true).timeout
	await process_frame
	await _press_action("interact")
	_check(garden.total_harvests == 1 and garden.resources["spores"] == 1, "恢复后成熟植物应可通过主场景输入收获。")
	_check(garden.plots[cell]["crop"] == "", "收获后前方苗床应重新为空。")


func _walk(action: StringName, frames: int) -> void:
	Input.action_press(action)
	for frame in range(frames):
		await physics_frame
	Input.action_release(action)
	await physics_frame


func _press_action(action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = InputEventAction.new()
	event.action = action
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame


func _empty_cell(garden: GardenState, lit: bool) -> Vector2i:
	for cell: Vector2i in garden.plots:
		if String(garden.plots[cell]["crop"]).is_empty() and garden.is_lit(cell) == lit:
			return cell
	return Vector2i(-1, -1)


func _center(cell: Vector2i) -> Vector2:
	return Vector2(cell * Garden.CELL_SIZE) + Vector2.ONE * Garden.CELL_SIZE / 2.0


func _check(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)


func _fail(message: String) -> void:
	_failures += 1
	printerr("SMOKE FAIL: " + message)
