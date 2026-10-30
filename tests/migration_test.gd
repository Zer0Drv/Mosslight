extends SceneTree
## 独立路径与完整 49 格 fixture；格式迁移、内容补偿和文件选择分别验证。

var failures := 0
var prefix := ""


func _initialize() -> void:
	_run.call_deferred()


func legacy_fixture() -> Dictionary:
	var plots := []
	# 冻结的 v1 布局，不从当前 12 格游戏状态伪造旧档。
	for rect: Rect2i in [Rect2i(26, 18, 4, 4), Rect2i(32, 21, 5, 4), Rect2i(36, 15, 3, 3), Rect2i(22, 26, 3, 3)]:
		for y in range(rect.position.y, rect.end.y):
			for x in range(rect.position.x, rect.end.x):
				var center := Vector2(x * 16 + 8, y * 16 + 8)
				if center.distance_to(Vector2(472, 344)) <= 22 or center.distance_to(Vector2(616, 296)) <= 22 or center.distance_to(Vector2(360, 408)) <= 22:
					continue
				var crop := ""
				if Vector2i(x, y) == Vector2i(28, 20):
					crop = "glow_bell"
				elif Vector2i(x, y) in [Vector2i(24, 27), Vector2i(23, 28)]:
					crop = "moon_moss"
				plots.append({"x": x, "y": y, "crop": crop, "growth": 0.5 if crop != "" else 0.0})
	return {"version": 1, "selected_crop": "glow_bell", "resources": {"dew": 1, "spores": 0}, "total_harvests": 5, "plots": plots, "lanterns": [{"restored": true, "lit": false}, {"restored": false, "lit": false}, {"restored": false, "lit": false}]}


func _run() -> void:
	prefix = "res://logs/migration_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	var old := legacy_fixture()
	_check(old.plots.size() == 49, "Fixture must contain all 49 legal legacy cells.")
	var m0 := GardenSchema.normalize(old)
	_check(not m0.is_empty(), "Complete v1 fixture must pass strict validation.")
	_check(m0.content_revision == "legacy_49" and m0.crops.size() == 3 and m0.resources.dew == 1 and not m0.lanterns[0].lit, "M0 preserves layout, crops, resources and mother switch.")
	var garden := GardenState.new()
	_check(garden.restore(m0), "M1 accepts normalized M0 state.")
	_check(garden.resources.dew == 3 and garden.resources.spores == 1 and garden.lanterns[0].lit, "M1 compensates exactly two moss and one bell, and lights mother.")
	_check(garden.selected_crop == "glow_bell" and garden.total_harvests == 5, "Seed choice and harvest count survive migration.")
	var migrated := garden.snapshot()
	_check(garden.restore(migrated) and garden.snapshot() == migrated, "Reload cannot repeat compensation.")
	for entry: Dictionary in old.plots:
		if int(entry.x) == 26 and int(entry.y) == 18:
			entry.crop = "glow_bell"
			entry.growth = 0.33
	_check(garden.restore(old) and is_equal_approx(garden.plots[Vector2i(26, 18)].growth, 0.33), "Crop inside new layout retains its progress.")
	for damage in ["missing_cell", "duplicate", "illegal_cell", "missing_lamp", "wrong_bool", "missing_resource"]:
		var bad := legacy_fixture()
		match damage:
			"missing_cell": bad.plots.pop_back()
			"duplicate": bad.plots[0] = bad.plots[1].duplicate()
			"illegal_cell": bad.plots[0].x = 59
			"missing_lamp": bad.lanterns.pop_back()
			"wrong_bool": bad.lanterns[0].lit = 1
			"missing_resource": bad.resources.erase("dew")
		var before := garden.snapshot()
		_check(not garden.restore(bad) and garden.snapshot() == before, "Damaged v1 is transactional: " + damage)
	var old_path := prefix + "_old.json"
	var path := prefix + "_current.json"
	var bytes := JSON.stringify({"garden": legacy_fixture(), "muted": true})
	_write(old_path, bytes)
	var store := GardenSave.new(path, old_path)
	var loaded := GardenState.new()
	var result := store.load_state(loaded)
	_check(result.loaded and result.migrated and result.muted and FileAccess.file_exists(path), "First load migrates and writes a valid current file.")
	_check(FileAccess.get_file_as_string(old_path) == bytes, "Original v1 remains byte-for-byte unchanged.")
	_check(store.load_state(loaded).loaded and loaded.resources.dew == 3, "Current file wins over old file without repeating migration.")
	# Corrupt current files cannot silently resurrect the older v1.
	_write(path, "{broken")
	_write(path + ".bak", "{broken")
	store = GardenSave.new(path, old_path)
	var before := loaded.snapshot()
	result = store.load_state(loaded)
	_check(not result.loaded and result.error != "" and loaded.snapshot() == before, "Both broken new files stop loading even when valid v1 exists.")
	_check(store.save_state(loaded, false) != OK and FileAccess.get_file_as_string(path) == "{broken", "Corrupt load disables automatic overwrite.")
	var future := migrated.duplicate(true)
	future.version = 99
	_write(path, JSON.stringify({"garden": future}))
	_write(path + ".bak", JSON.stringify({"garden": migrated}))
	store = GardenSave.new(path, old_path)
	result = store.load_state(loaded)
	_check(not result.loaded and result.error.contains("更新"), "Future primary refuses fallback to older backup.")
	_check(store.save_state(loaded, false) != OK, "Future primary cannot be overwritten.")
	# Force migration write failure with a regular file used as parent directory.
	var blocker := prefix + "_blocker"
	_write(blocker, "keep")
	store = GardenSave.new(blocker + "/current.json", old_path)
	before = loaded.snapshot()
	result = store.load_state(loaded)
	_check(not result.loaded and result.error != "" and loaded.snapshot() == before, "Failed migration write preserves active state and reports failure.")
	_check(FileAccess.get_file_as_string(old_path) == bytes, "Failed migration preserves source.")
	for candidate: String in [old_path, path, path + ".bak", path + ".tmp", blocker]:
		if FileAccess.file_exists(candidate):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(candidate))
	print("MIGRATION %s: strict v1, independent M0/M1, compensation, precedence, future-version and failed-write protection." % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)


func _write(path: String, value: String) -> void:
	assert(path.begins_with(prefix))
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert(file != null)
	file.store_string(value)
	file.close()


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("MIGRATION FAIL: " + message)
