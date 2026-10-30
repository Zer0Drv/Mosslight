class_name FarmHUD
extends CanvasLayer
## 手账式轻量界面，让林地保留画面中心。

signal seed_selected(kind: String)
signal resume_requested
signal mute_requested
signal journal_requested
signal companion_requested
signal sleep_requested
signal companion_touched(index: int)

const INK := Color("#101e2d")
const PAPER := Color("#e2e5d1")
const QUIET := Color("#91b0ad")
const MOON := Color("#94decc")
const WARM := Color("#f3cc87")

var _root: Control
var _dew: Label
var _spores: Label
var _objective: Label
var _objective_detail: Label
var _context_title: Label
var _context_detail: Label
var _context_action: Label
var _progress: ProgressBar
var _moon_button: Button
var _bell_button: Button
var _toast: Panel
var _message: Label
var _pause_overlay: ColorRect
var _mute_button: Button
var _light_hint: Label
var _completion: Panel
var _message_time := 0.0
var _completion_time := 0.0
var _selected_crop := ""
var _journal: ColorRect
var _journal_stage: Label
var _journal_action: Label
var _journal_materials: Label
var _journal_clock: Label
var _help: Label
var _sleep: Button
var _companion_root: Control
var _companion_message: Label
var _companion_message_time := 0.0


class SeedGlyph:
	extends Control
	var moon := true
	func _draw() -> void:
		if moon:
			draw_rect(Rect2(5, 4, 2, 2), Color("#b2f4de"))
			draw_rect(Rect2(3, 6, 6, 3), Color("#87cfc7"))
			draw_rect(Rect2(2, 9, 8, 4), Color("#68a8b0"))
			draw_rect(Rect2(4, 10, 3, 2), Color("#e0f5db"))
			draw_rect(Rect2(3, 14, 6, 2), Color("#3c666a"))
		else:
			draw_rect(Rect2(6, 3, 2, 11), Color("#78a28b"))
			draw_rect(Rect2(2, 5, 6, 2), Color("#acc098"))
			draw_rect(Rect2(2, 7, 5, 5), Color("#d8a46b"))
			draw_rect(Rect2(3, 7, 3, 3), Color("#ffdda0"))
			draw_rect(Rect2(7, 10, 5, 4), Color("#f0ba75"))
			draw_rect(Rect2(8, 10, 3, 2), Color("#fff0bf"))
			draw_rect(Rect2(4, 15, 6, 2), Color("#4c6b59"))


func _ready() -> void:
	_root = Control.new()
	_root.name = "Root"
	add_child(_root)
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ui_font := SystemFont.new()
	ui_font.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei", "Noto Sans CJK SC"])
	var ui_theme := Theme.new()
	ui_theme.default_font = ui_font
	ui_theme.default_font_size = 11
	ui_theme.set_color("font_color", "Label", PAPER)
	_root.theme = ui_theme

	var title_panel := _panel(_root, Rect2(12, 12, 162, 48))
	_label(title_panel, "苔 灯 镇", Vector2(10, 3), 20, PAPER)
	_label(title_panel, "MOSSLIGHT  /  林间灯圃", Vector2(12, 32), 9, QUIET)
	var inventory := _panel(_root, Rect2(396, 12, 232, 43))
	_glyph(inventory, Vector2(10, 12), true)
	_label(inventory, "露滴", Vector2(28, 6), 9, MOON)
	_dew = _label(inventory, "02", Vector2(67, 6), 19, PAPER)
	_glyph(inventory, Vector2(124, 12), false)
	_label(inventory, "灯孢", Vector2(144, 6), 9, WARM)
	_spores = _label(inventory, "00", Vector2(185, 6), 19, PAPER)

	var mission := _panel(_root, Rect2(396, 61, 232, 41))
	_objective = _label(mission, "点亮归途   1 / 3", Vector2(10, 4), 12, WARM)
	_objective_detail = _label(mission, "下一盏 · 12 灯孢 + 8 露滴", Vector2(10, 24), 9, QUIET)

	_light_hint = _label(_root, "光域视图 · 暖黄为灯铃区 / 青蓝为月苔区", Vector2(179, 16), 9, WARM)
	_light_hint.size = Vector2(208, 34)
	_light_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_light_hint.visible = false
	var journal_button := _button(_root, Rect2(12, 67, 79, 22), "J  今日手账")
	journal_button.pressed.connect(func() -> void: journal_requested.emit())
	var sit_button := _button(_root, Rect2(96, 67, 78, 22), "F  灯下坐坐")
	sit_button.pressed.connect(func() -> void: companion_requested.emit())

	_moon_button = _seed_button(Vector2(12, 286), true, "1  月苔", "阴影生长 · 收露滴")
	_bell_button = _seed_button(Vector2(124, 286), false, "2  灯铃", "暖光生长 · 收灯孢")
	_moon_button.pressed.connect(func() -> void: seed_selected.emit("moon_moss"))
	_bell_button.pressed.connect(func() -> void: seed_selected.emit("glow_bell"))

	var context_panel := _panel(_root, Rect2(244, 282, 384, 54))
	_context_title = _label(context_panel, "林间灯圃", Vector2(10, 5), 12, PAPER)
	_context_title.size = Vector2(225, 18)
	_context_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_context_action = _label(context_panel, "E  互动", Vector2(235, 7), 10, WARM)
	_context_action.size = Vector2(138, 15)
	_context_action.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_context_action.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_context_action.clip_text = true
	_context_detail = _label(context_panel, "", Vector2(10, 25), 10, QUIET)
	_context_detail.size = Vector2(364, 16)
	_context_detail.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_progress = ProgressBar.new()
	context_panel.add_child(_progress)
	_progress.position = Vector2(10, 46)
	_progress.size = Vector2(364, 2)
	_progress.max_value = 1.0
	_progress.show_percentage = false
	_progress.add_theme_stylebox_override("background", _style(Color("#243b48"), Color.TRANSPARENT))
	_progress.add_theme_stylebox_override("fill", _style(MOON, Color.TRANSPARENT))

	var controls := _label(_root, "WASD 移动   E 互动   1/2 选种   Q 露养   R 移除   Tab 光域   J 手账   F 灯下   Esc 暂停", Vector2(12, 342), 9, QUIET)
	controls.size = Vector2(616, 14)
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_toast = _panel(_root, Rect2(112, 235, 416, 36))
	_toast.visible = false
	_message = _label(_toast, "", Vector2(10, 4), 11, PAPER)
	_message.size = Vector2(396, 29)
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	_completion = _panel(_root, Rect2(170, 110, 300, 86))
	_completion.visible = false
	_label(_completion, "灯 路 已 重 连", Vector2(75, 12), 19, WARM)
	var end_detail := _label(_completion, "林中的归途亮起来了。\n继续照料灯圃，让明暗各得其所。", Vector2(16, 43), 11, PAPER)
	end_detail.size = Vector2(268, 37)
	end_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_build_pause()
	_build_journal()
	_build_companion()


func _process(delta: float) -> void:
	if get_tree().paused:
		return
	_message_time = maxf(0.0, _message_time - delta)
	_toast.visible = _message_time > 0.0
	_completion_time = maxf(0.0, _completion_time - delta)
	_completion.visible = _completion_time > 0.0
	_companion_message_time = maxf(0.0, _companion_message_time - delta)
	_companion_message.visible = _companion_message_time > 0.0


func update_garden(garden: GardenState) -> void:
	_dew.text = _format_count(int(garden.resources.dew))
	_spores.text = _format_count(int(garden.resources.spores))
	var count := garden.get_restored_count()
	_objective.text = "点亮归途   %d / 3" % count
	var cost := garden.get_restore_cost()
	_objective_detail.text = "灯路已重连 · 留下四格阴影" if count == 3 else "下一盏 · %d 灯孢 + %d 露滴" % [cost.spores, cost.dew]
	var season_names := {"spring": "春", "summer": "夏", "autumn": "秋", "winter": "冬"}
	_journal_clock.text = "%s · 第 %d 日  /  %s" % [season_names[garden.calendar.season], garden.calendar.day, "白昼" if garden.calendar.phase == "day" else "黄昏"]
	_journal_stage.text = "灯路已重连，三盏灯守着这片灯圃。" if count == 3 else "归途亮起 %d / 3 盏灯。先让明暗各得其所。" % count
	_journal_action.text = "继续照料灯圃，或到亮灯旁按 F 坐一会儿。" if count == 3 else "暖光种灯铃，阴影种月苔。成熟后面朝苗床按 E 收获。"
	var missing_spores := maxi(0, int(cost.spores) - int(garden.resources.spores))
	var missing_dew := maxi(0, int(cost.dew) - int(garden.resources.dew))
	_journal_materials.text = "保留四格阴影，月苔依旧有生长的地方。" if count == 3 else "下一次修灯需 %d 灯孢 + %d 露滴；还差 %d 灯孢、%d 露滴。" % [cost.spores, cost.dew, missing_spores, missing_dew]
	_sleep.visible = garden.calendar.phase == "dusk"
	if _selected_crop != garden.selected_crop:
		_selected_crop = garden.selected_crop
		_style_seed(_moon_button, garden.selected_crop == "moon_moss", MOON)
		_style_seed(_bell_button, garden.selected_crop == "glow_bell", WARM)


func set_context(info: Dictionary) -> void:
	_context_title.text = String(info.get("title", "林间灯圃"))
	var condition := String(info.get("condition", ""))
	if not condition.is_empty():
		_context_title.text += " · " + condition
	_context_detail.text = String(info.get("detail", "靠近土床与苔灯，面朝它们按 E。Tab 可以查看明暗。"))
	_context_action.text = String(info.get("action", ""))
	var amount := float(info.get("progress", -1.0))
	_progress.visible = amount >= 0.0
	_progress.value = clampf(amount, 0.0, 1.0)


func _format_count(amount: int) -> String:
	return "%.1f万" % (amount / 10000.0) if amount >= 10000 else "%02d" % amount


func show_message(message: String, duration: float = 4.5) -> void:
	if message.is_empty():
		return
	_message.text = message
	_message_time = duration
	_toast.visible = true


func set_paused(is_paused: bool) -> void:
	_pause_overlay.visible = is_paused


func set_muted(is_muted: bool) -> void:
	_mute_button.text = "声音：关  [M]" if is_muted else "声音：开  [M]"


func set_light_overlay(is_visible: bool) -> void:
	_light_hint.visible = is_visible


func celebrate_restoration(count: int) -> void:
	if count == 3:
		_completion_time = 8.0
		_completion.visible = true


func _build_pause() -> void:
	_pause_overlay = ColorRect.new()
	_root.add_child(_pause_overlay)
	_pause_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause_overlay.color = Color(0.025, 0.055, 0.09, 0.88)
	_pause_overlay.visible = false
	var card := _panel(_pause_overlay, Rect2(145, 53, 350, 254))
	_label(card, "让林子歇一会儿", Vector2(70, 20), 23, PAPER)
	_label(card, "月苔依偎阴影，灯铃追随暖光。", Vector2(74, 65), 11, MOON)
	var help := _label(card, "1 / 2  选种，面朝苗床按 E 种下或收获\n两次修灯：12+8、24+16（灯孢+露滴）\nQ  花 1 露滴促长 35%  ·  R 移除未熟植物\nJ  今日与速查  ·  F 灯下坐坐  ·  Tab 光域\n灯圃自动保存，暂停时植物也会休息。", Vector2(26, 96), 11, QUIET)
	help.add_theme_constant_override("line_spacing", 5)
	var resume := Button.new()
	card.add_child(resume)
	resume.position = Vector2(26, 208)
	resume.size = Vector2(174, 29)
	resume.text = "返回灯圃  [Esc]"
	resume.focus_mode = Control.FOCUS_NONE
	resume.add_theme_stylebox_override("normal", _style(Color("#2a4748"), MOON))
	resume.add_theme_stylebox_override("hover", _style(Color("#355755"), MOON))
	resume.pressed.connect(func() -> void: resume_requested.emit())
	_mute_button = Button.new()
	card.add_child(_mute_button)
	_mute_button.position = Vector2(211, 208)
	_mute_button.size = Vector2(112, 29)
	_mute_button.focus_mode = Control.FOCUS_NONE
	_mute_button.add_theme_stylebox_override("normal", _style(INK, QUIET))
	_mute_button.add_theme_stylebox_override("hover", _style(Color("#2a404d"), PAPER))
	_mute_button.pressed.connect(func() -> void: mute_requested.emit())
	var sit := _button(card, Rect2(26, 176, 297, 24), "在附近亮灯下坐坐  [F]")
	sit.pressed.connect(func() -> void: companion_requested.emit())


func set_journal(open: bool) -> void:
	_journal.visible = open


func show_quick_reference() -> void:
	_help.visible = true


func set_companion(active: bool) -> void:
	_root.visible = not active
	_companion_root.visible = active
	if active:
		show_companion_message("在这儿歇一会儿。移动、F 或 Esc 起身。", 7.0)


func show_companion_message(value: String, duration: float = 4.0) -> void:
	_companion_message.text = value
	_companion_message_time = duration
	_companion_message.visible = true


func _build_journal() -> void:
	_journal = ColorRect.new()
	_journal.name = "TodayJournal"
	_root.add_child(_journal)
	_journal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_journal.color = Color(0.025, 0.055, 0.09, 0.8)
	_journal.visible = false
	var card := _panel(_journal, Rect2(108, 32, 424, 294))
	_label(card, "今 日", Vector2(22, 14), 22, WARM)
	_journal_clock = _label(card, "", Vector2(210, 23), 11, QUIET)
	for index in range(3):
		var label := _label(card, "", Vector2(42, 64 + index * 45), 12, PAPER)
		label.size = Vector2(356, 39)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_label(card, ["一", "二", "三"][index], Vector2(18, 64 + index * 45), 12, MOON)
		if index == 0:
			_journal_stage = label
		elif index == 1:
			_journal_action = label
		else:
			_journal_materials = label
	_help = _label(card, "WASD / 方向键移动，E / 空格种植、收获或修灯\n1 月苔（阴影 90秒） · 2 灯铃（暖光 120秒），每株 1份\nQ 花1露滴促长35% · R移除未熟植物 · Tab光域\nF 灯下坐坐 · M声音 · F11全屏 · J / Esc合上", Vector2(22, 201), 10, QUIET)
	_help.size = Vector2(382, 69)
	_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_help.visible = false
	var help_button := _button(card, Rect2(22, 263, 114, 23), "操作速查 / 引导")
	help_button.pressed.connect(show_quick_reference)
	_sleep = _button(card, Rect2(146, 263, 114, 23), "睡觉，迎接明天")
	_sleep.pressed.connect(func() -> void: sleep_requested.emit())
	var close := _button(card, Rect2(288, 263, 114, 23), "合上  [J / Esc]")
	close.pressed.connect(func() -> void: journal_requested.emit())


func _build_companion() -> void:
	_companion_root = Control.new()
	_companion_root.name = "UnderTheLamp"
	add_child(_companion_root)
	_companion_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_companion_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_companion_root.theme = _root.theme
	_companion_root.visible = false
	_companion_message = _label(_companion_root, "", Vector2(100, 282), 12, PAPER)
	_companion_message.size = Vector2(440, 33)
	_companion_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_companion_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var names := ["添灯芯", "摸猫", "摇灯铃", "拨萤火", "看池水", "翻手账"]
	for i in range(6):
		var button := _button(_companion_root, Rect2(97 + i * 75, 327, 70, 22), names[i])
		button.modulate.a = 0.7
		button.pressed.connect(func() -> void: companion_touched.emit(i))


func _button(parent: Node, rect: Rect2, value: String) -> Button:
	var button := Button.new()
	parent.add_child(button)
	button.position = rect.position
	button.size = rect.size
	button.text = value
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 10)
	button.add_theme_stylebox_override("normal", _style(INK, Color("41525e")))
	button.add_theme_stylebox_override("hover", _style(Color("2e4950"), MOON))
	return button


func _seed_button(at: Vector2, moon: bool, title: String, description: String) -> Button:
	var button := Button.new()
	_root.add_child(button)
	button.position = at
	button.size = Vector2(106, 50)
	button.focus_mode = Control.FOCUS_NONE
	_glyph(button, Vector2(8, 8), moon)
	_label(button, title, Vector2(28, 7), 13, MOON if moon else WARM)
	_label(button, description, Vector2(8, 31), 9, QUIET)
	return button


func _style_seed(button: Button, selected: bool, accent: Color) -> void:
	var fill := Color("#253f46") if selected else INK
	button.add_theme_stylebox_override("normal", _style(fill, accent if selected else Color("#41525e")))
	button.add_theme_stylebox_override("hover", _style(Color("#2e4950"), accent))
	button.add_theme_stylebox_override("pressed", _style(Color("#39575c"), accent))


func _glyph(parent: Node, at: Vector2, moon: bool) -> void:
	var glyph := SeedGlyph.new()
	glyph.moon = moon
	glyph.position = at
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(glyph)


func _label(parent: Node, value: String, at: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	parent.add_child(label)
	label.position = at
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _panel(parent: Node, rectangle: Rect2) -> Panel:
	var panel := Panel.new()
	parent.add_child(panel)
	panel.position = rectangle.position
	panel.size = rectangle.size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _style(Color(0.055, 0.105, 0.16, 0.94), Color("#456066")))
	return panel


func _style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.shadow_color = Color(0.02, 0.035, 0.06, 0.35)
	style.shadow_size = 2
	style.shadow_offset = Vector2(1, 2)
	return style
