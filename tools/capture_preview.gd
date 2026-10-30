extends SceneTree
## Graphical QA only: --script res://tools/capture_preview.gd -- --fresh-garden


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	assert(OS.get_cmdline_user_args().has("--fresh-garden"), "Preview must never load a player save.")
	var game := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	current_scene = game
	await process_frame
	paused = false
	game.player.position = Vector2(488, 368)
	game.hud._message_time = 0.0
	await _capture("normal")
	game._toggle_journal()
	game.hud.show_quick_reference()
	await _capture("journal")
	game._toggle_journal()
	game._toggle_companion()
	game._touch_companion(1)
	await _capture("companion")
	game._leave_companion()
	game.garden.resources = {"dew": 24, "spores": 36, "nightdew": 0}
	game.garden.interact_lantern(1)
	game.garden.interact_lantern(2)
	game._refresh_hud()
	await _capture("complete")
	game.queue_free()
	await process_frame
	quit()


func _capture(name: String) -> void:
	for frame in range(12):
		await process_frame
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png("res://logs/mvp-" + name + ".png")
	assert(error == OK)
	print("PREVIEW " + name)
