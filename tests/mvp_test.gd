extends SceneTree
## 时间边界、灯下零后果、真实输入以及分阶段经济记录。

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_check_time()
	_check_economy()
	await _check_modes()
	paused = false
	print("MVP %s: calendar, offline growth, companion, journal and repair economy." % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)


func _check_time() -> void:
	var garden := GardenState.new()
	garden.advance(719.0)
	_check(garden.calendar.phase == "day", "Day remains active before 720 seconds.")
	garden.advance(1.0)
	_check(garden.calendar.phase == "dusk" and garden.calendar.play_seconds == 720.0, "720 seconds enters dusk exactly once.")
	var frozen := garden.calendar.duplicate(true)
	garden.companion = true
	garden.advance(1000.0)
	_check(garden.calendar == frozen, "Companion freezes all calendar fields even at dusk.")
	_check(not garden.sleep_to_next_day(), "Companion cannot advance the day by sleeping.")
	garden.companion = false
	garden.advance(30.0)
	_check(garden.calendar.day == 2 and garden.calendar.day_elapsed_seconds == 0.0 and garden.calendar.play_seconds == 720.0, "Dusk advances one day and retains lifetime day time.")
	_check(not garden.sleep_to_next_day(), "Duplicate sleep cannot advance a second day.")
	garden.calendar.day = 8
	garden.calendar.season = "winter"
	garden.calendar.phase = "dusk"
	garden.calendar.day_elapsed_seconds = 720.0
	garden.sleep_to_next_day()
	_check(garden.calendar.year == 2 and garden.calendar.season == "spring" and garden.calendar.day == 1, "Calendar rolls year/season exactly once.")
	garden.reset()
	garden.saved_at = 1000
	var before := garden.snapshot()
	_check(garden.grow_offline(900) == 0.0, "Clock rollback produces no offline time.")
	_check(garden.grow_offline(10000) == 720.0, "Offline time is capped at 720 seconds.")
	_check(garden.calendar == before.calendar and garden.resources == before.resources, "Offline time cannot change calendar or resources.")
	_check(garden.plots[Vector2i(14, 26)].growth == 1.0, "Offline only advances existing eligible crops.")
	_check(garden.grow_offline(10000) == 0.0, "Repeated offline application is idempotent.")


func _check_economy() -> void:
	var garden := GardenState.new()
	for plot: Dictionary in garden.plots.values():
		plot.crop = ""
		plot.growth = 0.0
	var total_dew := 0
	var total_spores := 0
	var repaired_at: Array[int] = []
	for second in range(1, 1501):
		for cell: Vector2i in garden.plots:
			var plot: Dictionary = garden.plots[cell]
			if plot.crop != "" and float(plot.growth) >= 1.0:
				if plot.crop == "moon_moss":
					total_dew += 1
				else:
					total_spores += 1
				garden.plant_or_harvest(cell)
			if plot.crop != "" and not garden.growth_condition(cell):
				garden.clear_crop(cell)
			if plot.crop == "":
				garden.select_crop("glow_bell" if garden.is_lit(cell) else "moon_moss")
				garden.plant_or_harvest(cell)
		var cost := garden.get_restore_cost()
		if garden.get_restored_count() < 3 and garden.resources.spores >= cost.spores and garden.resources.dew >= cost.dew:
			garden.interact_lantern(garden.get_restored_count())
			repaired_at.append(second - 1)
			print("ECONOMY t=%ds paid=(%d spores,%d dew) earned=(%d spores,%d dew) remaining=(%d spores,%d dew)" % [second - 1, cost.spores, cost.dew, total_spores, total_dew, garden.resources.spores, garden.resources.dew])
			# 理想模型的操作耗时为 0：同一时刻将新亮格改种灯铃。
			for cell: Vector2i in garden.plots:
				if garden.plots[cell].crop != "" and not garden.growth_condition(cell):
					garden.clear_crop(cell)
					garden.select_crop("glow_bell" if garden.is_lit(cell) else "moon_moss")
					garden.plant_or_harvest(cell)
		if garden.get_restored_count() == 3:
			break
		garden.advance(1.0)
	_check(repaired_at.size() == 2, "Zero-travel/no-nourish route can afford both repairs.")
	_check(repaired_at == [240, 720], "Zero-travel baseline matches the documented 240/720-second repairs.")
	_check(total_spores == 40 and total_dew == 42, "Documented ideal route yields 40 spores and 42 dew.")
	_check(total_spores - 36 == garden.resources.spores and total_dew + 2 - 24 == garden.resources.dew, "Both material ledgers balance independently.")
	_check(garden.repair_history.size() == 2, "Both repair timestamps and separate resource costs are recorded.")


func _check_modes() -> void:
	var game := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	current_scene = game
	await process_frame
	var garden: GardenState = game.garden
	var player: FarmPlayer = game.player
	var hud: FarmHUD = game.hud
	player.position = Vector2(488, 368)
	var position_before := player.position
	await _press("companion")
	_check(garden.companion and player.sitting and not hud.get_node("Root").visible, "F enters companion with sitting pose and hidden ordinary HUD.")
	var clock := garden.calendar.duplicate(true)
	var plot := Vector2i(14, 26)
	var growth: float = garden.plots[plot].growth
	await create_timer(0.15, true).timeout
	_check(garden.calendar == clock and garden.plots[plot].growth > growth, "Live companion grows crops while freezing calendar.")
	var before := garden.snapshot()
	for action in ["interact", "nourish", "clear_crop", "select_bell", "journal"]:
		await _press(action)
	for i in range(6):
		game._touch_companion(i)
	# Crop growth is allowed; resources, choice, counts and clock remain unchanged.
	_check(garden.resources == before.resources and garden.selected_crop == before.selected_crop and garden.total_harvests == before.summary.total_harvests and garden.calendar == before.calendar, "Companion blocks management and all six micro interactions have zero rewards.")
	await _press("pause")
	_check(not garden.companion and not player.sitting and player.position == position_before and not paused, "Esc exits immediately at the same position without pausing.")
	await _press("journal")
	_check(paused and hud.get_node("Root/TodayJournal").visible, "J opens modal Today journal.")
	clock = garden.calendar.duplicate(true)
	growth = garden.plots[plot].growth
	await create_timer(0.12, true).timeout
	_check(garden.calendar == clock and garden.plots[plot].growth == growth, "Modal journal pauses crops and time.")
	await _press("pause")
	_check(not paused and not hud.get_node("Root/TodayJournal").visible, "Esc closes journal and restores ordinary control.")
	await _press("companion")
	await _press("move_right")
	_check(not garden.companion, "Movement exits companion immediately.")
	player.position = Vector2(780, 510)
	await _press("companion")
	_check(not garden.companion, "F away from a fixed lit lamp does not teleport or enter.")
	game.queue_free()
	await process_frame


func _press(action: StringName) -> void:
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


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("MVP FAIL: " + message)
