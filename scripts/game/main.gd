extends Node2D
## 林间灯圃入口：协调世界、种光规则、声音与本地存档。

@onready var farm: FarmWorld = $Farm
@onready var player: FarmPlayer = $Player
@onready var hud: FarmHUD = $HUD
@onready var music: ForestAudio = $ForestAudio

var garden: GardenState
var _save_store := GardenSave.new()
var _save_enabled := false
var _save_dirty := false
var _save_clock := 0.0
var _ui_clock := 0.0
var _show_light := false


func _ready() -> void:
	garden = GardenState.new()
	_save_enabled = DisplayServer.get_name() != "headless" and not OS.get_cmdline_user_args().has("--fresh-garden")
	var load_result := {"loaded": false, "error": "", "muted": false}
	if _save_enabled:
		load_result = _save_store.load_state(garden)
		if not String(load_result.error).is_empty():
			_save_enabled = false
	music.set_muted(bool(load_result.muted))
	farm.bind_garden(garden)
	player.global_position = farm.get_spawn_position()
	var world_rect := farm.get_world_rect()
	var camera: Camera2D = $Player/Camera2D
	camera.limit_left = int(world_rect.position.x)
	camera.limit_top = int(world_rect.position.y)
	camera.limit_right = int(world_rect.end.x)
	camera.limit_bottom = int(world_rect.end.y)
	garden.changed.connect(_on_garden_changed)
	garden.harvest_collected.connect(_on_harvest_collected)
	garden.lantern_restored.connect(_on_lantern_restored)
	hud.seed_selected.connect(_select_seed)
	hud.resume_requested.connect(_toggle_pause)
	hud.mute_requested.connect(_toggle_mute)
	hud.appearance_selected.connect(_select_appearance)
	hud.set_appearance(player.appearance)
	hud.set_muted(music.is_muted())
	_refresh_hud()
	get_tree().auto_accept_quit = false
	if not String(load_result.error).is_empty():
		hud.show_message("原存档读取失败。本次灯圃暂不保存，以保留原文件。", 10.0)
	elif bool(load_result.loaded):
		hud.show_message("苔灯还亮着。上次照料的灯圃，正等你回来。", 6.0)
	else:
		hud.show_message("暗处种月苔，暖光里种灯铃。收集露滴与灯孢，修复两盏旧灯。", 9.0)


func _process(delta: float) -> void:
	if get_tree().paused or garden == null:
		return
	music.update_footsteps(player.global_position, delta)
	garden.advance(delta)
	farm.set_interaction_target(player.get_interaction_position())
	_ui_clock += delta
	_save_clock += delta
	if _ui_clock >= 0.1:
		_ui_clock = 0.0
		_refresh_hud()
	if _save_clock >= 10.0:
		_save_clock = 0.0
		_save_progress()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo:
		return
	if event.is_action_pressed("pause"):
		_toggle_pause()
	elif event.is_action_pressed("toggle_fullscreen"):
		var mode := DisplayServer.window_get_mode()
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if mode == DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)
	elif event.is_action_pressed("mute"):
		_toggle_mute()
	elif get_tree().paused:
		return
	elif event.is_action_pressed("select_moon"):
		_select_seed("moon_moss")
	elif event.is_action_pressed("select_bell"):
		_select_seed("glow_bell")
	elif event.is_action_pressed("light_overlay"):
		_show_light = not _show_light
		farm.set_light_overlay(_show_light)
		hud.set_light_overlay(_show_light)
		music.play_cue("overlay")
	elif event.is_action_pressed("interact"):
		var before := garden.snapshot()
		var message := farm.interact(player.get_interaction_position())
		var cue := _interaction_cue(before, garden.snapshot())
		if not cue.is_empty():
			music.play_cue(cue)
		hud.show_message(message)
		_save_progress()
	elif event.is_action_pressed("nourish"):
		var before := int(garden.resources.dew)
		hud.show_message(farm.nourish(player.get_interaction_position()))
		music.play_cue("nourish" if int(garden.resources.dew) < before else "denied")
		_save_progress()
	elif event.is_action_pressed("clear_crop"):
		var before := _planted_count(garden.snapshot())
		hud.show_message(farm.clear_crop(player.get_interaction_position()))
		music.play_cue("clear" if _planted_count(garden.snapshot()) < before else "denied")
		_save_progress()
	else:
		return
	_refresh_hud()
	get_viewport().set_input_as_handled()


func _select_seed(kind: String) -> void:
	if get_tree().paused:
		return
	var previous := garden.selected_crop
	garden.select_crop(kind)
	if garden.selected_crop == previous:
		return
	music.play_cue("seed_select")
	_refresh_hud()
	_save_progress()


func _select_appearance(index: int) -> void:
	if not get_tree().paused or index < 0 or index > 1 or player.appearance == index:
		return
	player.appearance = index
	player.queue_redraw()
	hud.set_appearance(index)
	music.play_cue("seed_select")


func _toggle_pause() -> void:
	get_tree().paused = not get_tree().paused
	hud.set_paused(get_tree().paused)
	music.play_cue("pause" if get_tree().paused else "resume")
	if get_tree().paused:
		_save_progress()


func _toggle_mute() -> void:
	music.set_muted(not music.is_muted())
	hud.set_muted(music.is_muted())
	_save_dirty = true
	_save_progress()


func _refresh_hud() -> void:
	if garden == null:
		return
	hud.update_garden(garden)
	hud.set_context(farm.get_context(player.get_interaction_position()))


func _on_garden_changed() -> void:
	_save_dirty = true


func _on_harvest_collected(kind: String, _amount: int) -> void:
	music.play_cue("harvest_moon" if kind == "moon_moss" else "harvest_bell")
	player.celebrate()


func _on_lantern_restored(_index: int) -> void:
	music.play_cue("complete" if garden.get_restored_count() == garden.lanterns.size() else "restore")
	player.celebrate()
	hud.celebrate_restoration(garden.get_restored_count())


static func _interaction_cue(before: Dictionary, after: Dictionary) -> String:
	# Classify committed state changes, never translated UI prose. Harvest and
	# restoration signals already request their own cue, including completion.
	if int(after["total_harvests"]) > int(before["total_harvests"]):
		return ""
	for index in range(after["lanterns"].size()):
		var old_lamp: Dictionary = before["lanterns"][index]
		var new_lamp: Dictionary = after["lanterns"][index]
		if bool(new_lamp["restored"]) != bool(old_lamp["restored"]):
			return ""
		if bool(new_lamp["lit"]) != bool(old_lamp["lit"]):
			return "lamp_on" if bool(new_lamp["lit"]) else "lamp_off"
	if _planted_count(after) > _planted_count(before):
		return "plant"
	return "denied"


static func _planted_count(snapshot: Dictionary) -> int:
	var count := 0
	for plot: Dictionary in snapshot["plots"]:
		if not String(plot["crop"]).is_empty():
			count += 1
	return count


func _save_progress() -> void:
	if not _save_enabled or not _save_dirty or garden == null:
		return
	var error := _save_store.save_state(garden, music.is_muted())
	if error == OK:
		_save_dirty = false
	else:
		hud.show_message("灯圃仍在运行，但这次保存失败。请检查存储空间。", 6.0)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_progress()
		get_tree().quit()


func _exit_tree() -> void:
	_save_progress()
