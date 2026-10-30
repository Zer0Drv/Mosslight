extends SceneTree
## Reproducible visual QA. Run with a graphics backend and -- --fresh-garden.
const OUT := "res://assets/art/previews/"

class AssetBoard extends Node2D:
	var font := SystemFont.new()
	var textures: Dictionary = {}
	func _ready() -> void:
		font.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei"])
	func _draw() -> void:
		draw_rect(Rect2(0,0,1280,800),Color("14252d"))
		draw_string(font,Vector2(42,48),"MOSSLIGHT  /  苔灯镇素材包 01",HORIZONTAL_ALIGNMENT_LEFT,-1,26,Color("ecdfbf"))
		draw_string(font,Vector2(42,78),"运行时纹理 · 最近邻放大预览 · 2 套服饰 / 32 动作帧 / 20 个独立物件",HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("9fb7ae"))
		draw_string(font,Vector2(42,116),"苔林装 · 下 / 右 / 左 / 上",HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("bad0aa"))
		draw_string(font,Vector2(342,116),"星夜装 · 暂停菜单可切换",HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("c0b9e5"))
		_tex("keeper_moss",Vector2(42,124),2)
		_tex("keeper_star",Vector2(342,124),2)
		draw_string(font,Vector2(656,116),"种植 · 四阶段",HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("bad0aa"))
		for i in 4:
			_tex("moon_moss_%d"%i,Vector2(656+i*112,140),4)
			_tex("glow_bell_%d"%i,Vector2(656+i*112,212),4)
		draw_string(font,Vector2(656,312),"苔灯 · 破损 / 熄灭 / 点亮",HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("ecdfbf"))
		for i in 3:
			_tex(["lantern_broken","lantern_off","lantern_on"][i],Vector2(664+i*124,324),2)
		_tex("spore_pouch",Vector2(1060,354),2)
		draw_string(font,Vector2(656,464),"界面 · 露滴 / 灯孢 / 两种种子袋",HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("a9c9cb"))
		for i in 4:
			_tex(["icon_dew","icon_spores","icon_seed_moon","icon_seed_bell"][i],Vector2(656+i*112,480),3)
		draw_line(Vector2(42,568),Vector2(1238,568),Color("3b5257"),1)
		draw_string(font,Vector2(42,598),"林地物件 · 原始透明图与切片参数均保留",HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("bad0aa"))
		_tex("cottage",Vector2(42,612),1)
		_tex("tree",Vector2(212,602),1)
		_tex("stump",Vector2(370,658),2)
		_tex("mushroom_fern",Vector2(500,660),2)
		draw_string(font,Vector2(656,634),"当前接入：两套服饰、作物、灯、物件与图标",HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("ecdfbf"))
		draw_string(font,Vector2(656,670),"Esc 暂停 → 选择服饰，本次游玩生效",HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("9fb7ae"))
		draw_string(font,Vector2(656,704),"手提灯、窗灯与装饰物不改变作物光照",HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("9fb7ae"))
		draw_string(font,Vector2(42,774),"2026.10.31  /  built-in image_gen → Godot RGBA sprites",HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("708d8d"))
	func _tex(id: String, at: Vector2, zoom: int) -> void:
		if not textures.has(id):
			textures[id] = load("res://assets/art/runtime/"+id+".png")
		var texture: Texture2D = textures[id]
		draw_texture_rect(texture,Rect2(at,texture.get_size()*zoom),false)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if not OS.get_cmdline_user_args().has("--fresh-garden"):
		printerr("Preview requires -- --fresh-garden to protect real saves.")
		quit(1)
		return
	var game: Node2D = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	current_scene = game
	game.music.set_muted(true)
	game.hud.set_muted(true)
	game.player.facing = Vector2.DOWN
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var first := root.get_texture().get_image()
	first.save_png(OUT+"gameplay_moss.png")
	game._toggle_pause()
	game.hud.find_child("AppearanceStar", true, false).pressed.emit()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+"appearance_menu.png")
	game._toggle_pause()
	# Staged visual QA state, never persisted: every crop phase and three lamp states.
	game.garden.lanterns[1]["restored"] = true
	game.garden.lanterns[1]["lit"] = false
	var index := 0
	for cell: Vector2i in game.garden.plots:
		game.garden.plots[cell]["crop"] = "moon_moss" if index % 8 < 4 else "glow_bell"
		game.garden.plots[cell]["growth"] = [0.0,0.3,0.65,1.0][index%4]
		index += 1
	game.farm.queue_redraw()
	game.player.appearance = 1
	game.player.facing = Vector2.DOWN
	game.hud.show_message("素材检查：作物四阶段与灯具状态（此画面不保存）",30.0)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+"gameplay_states.png")
	for lantern: Dictionary in game.garden.lanterns:
		lantern["restored"] = true
		lantern["lit"] = true
	game._refresh_hud()
	game.farm.queue_redraw()
	game.hud.celebrate_restoration(3)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+"restoration_complete.png")
	game.queue_free()
	await process_frame
	root.content_scale_size = Vector2i(1280,800)
	root.size = Vector2i(1280,800)
	var board := AssetBoard.new()
	board.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	root.add_child(board)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+"asset_board.png")
	print("VISUAL CAPTURE PASS: gameplay_moss, appearance_menu, gameplay_states, restoration_complete, asset_board.")
	quit(0)
