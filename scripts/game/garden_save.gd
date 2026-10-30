class_name GardenSave
extends RefCounted
## 新档优先、拒绝静默回退；旧 v1 原文件保留。所有替换先写临时文件。

const DEFAULT_PATH := "user://mosslight_garden.json"
const LEGACY_PATH := "user://mosslight_garden_v1.json"
var path: String
var legacy_path: String
var _write_blocked := false


func _init(save_path: String = DEFAULT_PATH, old_path: String = "") -> void:
	path = save_path
	legacy_path = LEGACY_PATH if save_path == DEFAULT_PATH else old_path


func _read(candidate: String) -> Dictionary:
	var file := FileAccess.open(candidate, FileAccess.READ)
	if file == null or file.get_length() > 1048576:
		return {}
	var parser := JSON.new()
	var error := parser.parse(file.get_as_text())
	file.close()
	if error != OK or not parser.data is Dictionary:
		return {}
	var document: Dictionary = parser.data
	if not document.get("garden") is Dictionary or not document.get("muted", false) is bool:
		return {}
	return document


func load_state(garden: GardenState) -> Dictionary:
	var result := {"loaded": false, "error": "", "muted": false, "recovered": false, "migrated": false}
	var current_exists := FileAccess.file_exists(path) or FileAccess.file_exists(path + ".bak")
	var candidates: Array[String] = [path, path + ".bak"]
	if not current_exists and not legacy_path.is_empty():
		candidates = [legacy_path, legacy_path + ".bak"]
	for candidate: String in candidates:
		if not FileAccess.file_exists(candidate):
			continue
		var document := _read(candidate)
		if document.is_empty():
			continue
		var version: Variant = document.garden.get("version")
		if (version is int or version is float) and float(version) > GardenState.SAVE_VERSION:
			result.error = "这份存档来自更新的版本。原文件已保留，这次先不保存。"
			_write_blocked = true
			return result
		var normalized := GardenSchema.normalize(document.garden)
		if normalized.is_empty():
			continue
		var temporary := GardenState.new()
		if not temporary.restore(normalized):
			continue
		var migration: bool = int(version) == 1 or normalized.content_revision == "legacy_49"
		if migration:
			var write_error := save_state(temporary, document.get("muted", false))
			if write_error != OK:
				result.error = "旧本子暂时抄不下来。原存档已保留，这次先不保存。"
				_write_blocked = true
				return result
		garden.restore(temporary.snapshot())
		garden.migration_note = temporary.migration_note
		result.loaded = true
		result.muted = document.get("muted", false)
		result.recovered = candidate != candidates[0]
		result.migrated = migration
		return result
	var any_exists := current_exists
	for candidate: String in candidates:
		any_exists = any_exists or FileAccess.file_exists(candidate)
	if any_exists:
		result.error = "原存档读不出来。这次先不保存。"
		_write_blocked = true
	return result


func save_state(garden: GardenState, muted: bool) -> Error:
	if _write_blocked:
		return ERR_FILE_NO_PERMISSION
	var snapshot := garden.snapshot()
	var timestamp := int(Time.get_unix_time_from_system())
	snapshot.saved_at = timestamp
	if GardenSchema.normalize(snapshot).is_empty():
		return ERR_INVALID_DATA
	for candidate: String in [path, path + ".bak"]:
		var document := _read(candidate)
		var version: Variant = document.get("garden", {}).get("version", 0)
		if (version is int or version is float) and float(version) > GardenState.SAVE_VERSION:
			_write_blocked = true
			return ERR_FILE_NO_PERMISSION
	var temporary := path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify({"garden": snapshot, "muted": muted}, "", true, true))
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		return write_error
	var absolute := ProjectSettings.globalize_path(path)
	var backup := absolute + ".bak"
	if FileAccess.file_exists(path):
		var previous := _read(path)
		if not previous.is_empty() and not GardenSchema.normalize(previous.garden).is_empty():
			var backup_error := DirAccess.copy_absolute(absolute, backup)
			if backup_error != OK:
				return backup_error
	var rename_error := DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), absolute)
	if rename_error == OK:
		garden.saved_at = timestamp
	return rename_error
