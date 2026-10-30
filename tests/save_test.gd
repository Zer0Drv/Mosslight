extends SceneTree
## Godot --headless --path . --script res://tests/save_test.gd
## Only this test's unique files under the current project's logs directory are touched.
## M0：改用动态寻找苗床（不再硬编码旧布局坐标），并断言迁移备注与 v2 往返。

const Garden = preload("res://scripts/game/garden_state.gd")
var _failures: int = 0
var _path: String = ""
var _logs_directory: String = ""


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_logs_directory = ProjectSettings.globalize_path("res://logs").replace("\\", "/").simplify_path()
	var project_directory := ProjectSettings.globalize_path("res://").replace("\\", "/").simplify_path()
	var expected_directory := project_directory.path_join("logs").simplify_path()
	if _logs_directory.to_lower() != expected_directory.to_lower():
		_fail("Refusing to write test files outside the project's logs directory.")
		quit(1)
		return
	var directory_error := DirAccess.make_dir_recursive_absolute(_logs_directory)
	if directory_error != OK:
		_fail("Cannot prepare the permitted logs directory: %s" % error_string(directory_error))
		quit(1)
		return
	_path = "res://logs/save_smoke_%d_%d.json" % [OS.get_process_id(), Time.get_ticks_usec()]
	var save := GardenSave.new(_path)
	_check_missing_save(save)
	var source := GardenState.new()
	var lit := _first_cell(source, true)
	source.select_crop("glow_bell")
	source.advance(600.0)
	source.plant_or_harvest(lit)
	var first_snapshot := source.snapshot().duplicate(true)
	_check(save.save_state(source, true) == OK, "First file save must succeed.")
	_check(FileAccess.file_exists(_path), "First save must create the primary JSON file.")
	_check(not FileAccess.file_exists(_path + ".tmp"), "Successful save must consume its temporary file.")
	_check_loaded(save, first_snapshot, true, false, "First round trip")

	source.interact_lantern(0)
	var dark := _first_cell(source, false)
	source.select_crop("moon_moss")
	source.plant_or_harvest(dark)
	var second_snapshot := source.snapshot().duplicate(true)
	_check(first_snapshot != second_snapshot, "Overwrite fixture must contain changed gameplay state.")
	_check(save.save_state(source, false) == OK, "Replacing an existing save must succeed on Windows.")
	_check(not FileAccess.file_exists(_path + ".tmp"), "Overwrite must consume its temporary file.")
	_check(FileAccess.file_exists(_path + ".bak"), "Overwrite must retain the previous save as a backup.")
	_check_loaded(save, second_snapshot, false, false, "Overwrite round trip")
	_check_loaded(GardenSave.new(_path + ".bak"), first_snapshot, true, false, "Previous save backup")

	if _write_text(_path, "{broken JSON"):
		_check_loaded(save, first_snapshot, true, true, "Corrupted primary backup recovery")
		_check(save.save_state(source, false) == OK, "Saving after backup recovery must replace the bad primary.")
		_check_loaded(save, second_snapshot, false, false, "Save after recovery")
		_check_loaded(GardenSave.new(_path + ".bak"), first_snapshot, true, false, "Bad primary must not replace the good backup")
	if _remove_own_file(_path):
		_check_loaded(save, first_snapshot, true, true, "Missing primary backup recovery")

	_check_rejected_documents(save, first_snapshot)
	_check_failed_write_preserves_file(source)
	_cleanup()
	if _failures == 0:
		print("SAVE PASS: disk round trips, Windows overwrite, mute, backup recovery, invalid saves, and error reporting.")
	else:
		printerr("SAVE FAIL: %d checks failed." % _failures)
	quit(0 if _failures == 0 else 1)


func _first_cell(garden: GardenState, lit: bool) -> Vector2i:
	for cell: Vector2i in garden.plots:
		if garden.is_lit(cell) == lit:
			return cell
	return Vector2i(-1, -1)


func _check_missing_save(save: GardenSave) -> void:
	var garden := GardenState.new()
	garden.select_crop("glow_bell")
	var before := garden.snapshot().duplicate(true)
	var result := save.load_state(garden)
	_check(not bool(result.get("loaded", true)), "A missing save is not loaded.")
	_check(String(result.get("error", "missing key")).is_empty(), "No save yet is not an error.")
	_check(garden.snapshot() == before, "Missing save must leave memory untouched.")


func _check_loaded(save: GardenSave, expected: Dictionary, muted: bool, recovered: bool, label: String) -> void:
	var garden := GardenState.new()
	var result := save.load_state(garden)
	_check(bool(result.get("loaded", false)), "%s: load should succeed." % label)
	_check(String(result.get("error", "missing key")).is_empty(), "%s: successful load should not report an error." % label)
	_check(bool(result.get("muted", not muted)) == muted, "%s: mute preference must round trip." % label)
	_check(bool(result.get("recovered", false)) == recovered, "%s: recovery status must be accurate." % label)
	_check(garden.snapshot() == expected, "%s: the complete snapshot must round trip." % label)


func _check_rejected_documents(save: GardenSave, valid_snapshot: Dictionary) -> void:
	# Both files are invalid, so recovery cannot conceal a validation failure.
	_reject_pair(save, "{broken JSON", "null", "Malformed JSON")
	_reject_pair(save, "[]", "[]", "Wrong document root")
	var wrong_mute := JSON.stringify({"garden": valid_snapshot, "muted": "yes"})
	_reject_pair(save, wrong_mute, wrong_mute, "Wrong mute type")
	var wrong_version := valid_snapshot.duplicate(true)
	wrong_version["version"] = 999
	var wrong_version_json := JSON.stringify({"garden": wrong_version, "muted": false})
	_reject_pair(save, wrong_version_json, wrong_version_json, "Unknown state version")
	var missing_fields := JSON.stringify({"garden": {"version": 1}, "muted": false})
	_reject_pair(save, missing_fields, missing_fields, "Incomplete state schema")
	# Fail late in GardenState.restore, after otherwise valid resources/crops/lanterns.
	# An implementation that mutates progressively would leak these changes.
	var invalid_lantern := valid_snapshot.duplicate(true)
	invalid_lantern["resources"]["dew"] = 77
	invalid_lantern["lanterns"][-1]["restored"] = false
	invalid_lantern["lanterns"][-1]["lit"] = true
	var late_failure := JSON.stringify({"garden": invalid_lantern, "muted": true})
	_reject_pair(save, late_failure, late_failure, "Invalid final lantern must be transactional")


func _reject_pair(save: GardenSave, primary: String, backup: String, label: String) -> void:
	if not _write_text(_path, primary) or not _write_text(_path + ".bak", backup):
		return
	var garden := GardenState.new()
	garden.select_crop("glow_bell")
	garden.interact_lantern(0)
	var before := garden.snapshot().duplicate(true)
	var result := save.load_state(garden)
	_check(not bool(result.get("loaded", true)), "%s: invalid files must be rejected." % label)
	_check(not String(result.get("error", "")).is_empty(), "%s: rejection must report an error." % label)
	_check(not bool(result.get("recovered", false)), "%s: two invalid files cannot count as recovery." % label)
	_check(garden.snapshot() == before, "%s: rejected data must not modify live state." % label)
	_check(FileAccess.get_file_as_string(_path) == primary, "%s: loading must preserve the rejected primary file." % label)
	_check(FileAccess.get_file_as_string(_path + ".bak") == backup, "%s: loading must preserve the rejected backup." % label)


func _check_failed_write_preserves_file(garden: GardenState) -> void:
	# The primary is a regular file, so it cannot be a parent directory.
	# This triggers a real open failure without permissions or user:// writes.
	var before := FileAccess.get_file_as_string(_path)
	var blocked := GardenSave.new(_path.path_join("blocked.json"))
	_check(blocked.save_state(garden, false) != OK, "An unwritable destination must return a non-OK Error.")
	_check(FileAccess.get_file_as_string(_path) == before, "A failed save must preserve the file blocking its parent path.")


func _write_text(path: String, contents: String) -> bool:
	if not _is_own_file(path):
		_fail("Refusing to write an unowned test path.")
		return false
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_fail("Cannot prepare test fixture: %s" % path)
		return false
	file.store_string(contents)
	file.flush()
	var error := file.get_error()
	file.close()
	_check(error == OK, "Test fixture write must succeed.")
	return error == OK


func _is_own_file(path: String) -> bool:
	if path not in [_path, _path + ".tmp", _path + ".bak"]:
		return false
	var absolute := ProjectSettings.globalize_path(path).replace("\\", "/").simplify_path()
	return absolute.get_base_dir().to_lower() == _logs_directory.to_lower()


func _remove_own_file(path: String) -> bool:
	if not _is_own_file(path):
		_fail("Refusing to remove an unowned test path.")
		return false
	if not FileAccess.file_exists(path):
		return true
	var error := DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	_check(error == OK, "Test file cleanup must succeed: %s" % path)
	return error == OK


func _cleanup() -> void:
	for suffix in ["", ".tmp", ".bak"]:
		_remove_own_file(_path + suffix)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)


func _fail(message: String) -> void:
	_failures += 1
	printerr("SAVE FAIL: " + message)
