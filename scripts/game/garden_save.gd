class_name GardenSave
extends RefCounted
## 先写临时文件，保留上一份完整备份，再替换正式文件。

const DEFAULT_PATH := "user://mosslight_garden_v1.json"
var path: String


func _init(save_path: String = DEFAULT_PATH) -> void:
	path = save_path


func load_state(garden: GardenState) -> Dictionary:
	var result := {"loaded": false, "error": "", "muted": false, "recovered": false}
	if not FileAccess.file_exists(path) and not FileAccess.file_exists(path + ".bak"):
		return result
	for candidate: String in [path, path + ".bak"]:
		var file := FileAccess.open(candidate, FileAccess.READ)
		if file == null or file.get_length() > 1048576:
			continue
		var parser := JSON.new()
		var parse_error := parser.parse(file.get_as_text())
		file.close()
		if parse_error != OK:
			continue
		var document: Variant = parser.data
		if not document is Dictionary or not document.get("garden") is Dictionary or not document.get("muted", false) is bool:
			continue
		if not garden.restore(document.garden):
			continue
		result.loaded = true
		result.muted = document.get("muted", false)
		result.recovered = candidate != path
		return result
	result.error = "Invalid garden save and backup"
	return result


func save_state(garden: GardenState, muted: bool) -> Error:
	var temporary := path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify({"garden": garden.snapshot(), "muted": muted}))
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		return write_error
	var absolute := ProjectSettings.globalize_path(path)
	var backup := absolute + ".bak"
	if FileAccess.file_exists(path):
		# 只备份能完整读取的旧档，避免恢复备份后又用坏主档覆盖它。
		var previous := GardenState.new()
		var probe := GardenSave.new(path)
		var previous_result := probe.load_state(previous)
		if bool(previous_result.loaded) and not bool(previous_result.recovered):
			var backup_error := DirAccess.copy_absolute(absolute, backup)
			if backup_error != OK:
				return backup_error
	var rename_error := DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), absolute)
	if rename_error != OK and not FileAccess.file_exists(path) and FileAccess.file_exists(backup):
		DirAccess.copy_absolute(backup, absolute)
	return rename_error
