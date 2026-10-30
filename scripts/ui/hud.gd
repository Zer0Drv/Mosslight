class_name FarmHUD
extends CanvasLayer
## 手账式轻量界面，让林地保留画面中心。

signal seed_selected(kind: String)
signal resume_requested
signal mute_requested
signal appearance_selected(index: int)

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
var _appearance_buttons: Array[Button] = []
var _message_time := 0.0
var _completion_time := 0.0
var _selected_crop := ""


class SeedGlyph:
	extends Control
	const ICONS: Array[Texture2D] = [
		preload("res://assets/art/runtime/icon_dew.png"), preload("res://assets/art/runtime/icon_spores.png"),
		preload("res://assets/art/runtime/icon_seed_moon.png"), preload("res://assets/art/runtime/icon_seed_bell.png"),
	]
	var moon := true
	var seed := false
	func _draw() -> void:
		var index := (0 if moon else 1) + (2 if seed else 0)
		draw_texture(ICONS[index], Vector2.ZERO)


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
	_objective_detail = _label(mission, "修复旧灯 · 每盏 6 灯孢 + 4 露滴", Vector2(10, 24), 9, QUIET)

	_light_hint = _label(_root, "光域视图 · 暖黄为灯铃区 / 青蓝为月苔区", Vector2(179, 16), 9, WARM)
	_light_hint.size = Vector2(208, 34)
	_light_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_light_hint.visible = false

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

	var controls := _label(_root, "WASD 移动   E 互动   1/2 选种   Q 露养   R 移除   Tab 光域   M 声音   Esc 暂停", Vector2(12, 342), 9, QUIET)
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
	var pouch := TextureRect.new()
	pouch.name = "SporePouch"
	pouch.texture = preload("res://assets/art/runtime/spore_pouch.png")
	pouch.position = Vector2(38, 10)
	pouch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_completion.add_child(pouch)
	_label(_completion, "灯 路 已 重 连", Vector2(75, 12), 19, WARM)
	var end_detail := _label(_completion, "林中的归途亮起来了。\n继续照料灯圃，让明暗各得其所。", Vector2(16, 43), 11, PAPER)
	end_detail.size = Vector2(268, 37)
	end_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_build_pause()


func _process(delta: float) -> void:
	if get_tree().paused:
		return
	_message_time = maxf(0.0, _message_time - delta)
	_toast.visible = _message_time > 0.0
	_completion_time = maxf(0.0, _completion_time - delta)
	_completion.visible = _completion_time > 0.0


func update_garden(garden: GardenState) -> void:
	_dew.text = _format_count(int(garden.resources.dew))
	_spores.text = _format_count(int(garden.resources.spores))
	var count := garden.get_restored_count()
	_objective.text = "点亮归途   %d / 3" % count
	_objective_detail.text = "灯路已重连 · 继续照料你的灯圃" if count == 3 else "修复旧灯 · 每盏 6 灯孢 + 4 露滴"
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


func set_appearance(index: int) -> void:
	for item in _appearance_buttons.size():
		_appearance_buttons[item].set_pressed_no_signal(item == index)
		_style_seed(_appearance_buttons[item], item == index, MOON if item == 0 else Color("c6b3ef"))


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
	var card := _panel(_pause_overlay, Rect2(130, 20, 380, 320))
	_label(card, "让林子歇一会儿", Vector2(84, 14), 23, PAPER)
	_label(card, "月苔依偎阴影，灯铃追随暖光。", Vector2(90, 50), 11, MOON)
	var help := _label(card, "1 / 2  选择植物，面朝土床按 E 种下或收获\nE  开关苔灯；修复旧灯需要 6 灯孢 + 4 露滴\nQ  花 1 露滴促长 35%  ·  R 移除未熟植物\nTab  查看光照范围  ·  F11 全屏\n灯圃自动保存，暂停时植物也会休息。", Vector2(26, 76), 11, QUIET)
	help.add_theme_constant_override("line_spacing", 5)
	_label(card, "巡灯人外观", Vector2(26, 181), 12, PAPER)
	_label(card, "本次游玩生效", Vector2(267, 184), 10, QUIET)
	var appearance_group := ButtonGroup.new()
	for index in 2:
		var option := Button.new()
		option.name = "AppearanceMoss" if index == 0 else "AppearanceStar"
		card.add_child(option)
		option.position = Vector2(26 + index * 170, 204)
		option.size = Vector2(158, 58)
		option.focus_mode = Control.FOCUS_ALL
		option.toggle_mode = true
		option.button_group = appearance_group
		var portrait := TextureRect.new()
		var frame := AtlasTexture.new()
		frame.atlas = FarmPlayer.MOSS_ATLAS if index == 0 else FarmPlayer.STAR_ATLAS
		frame.region = Rect2(0, 0, 32, 40)
		portrait.texture = frame
		portrait.position = Vector2(12, 6)
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		option.add_child(portrait)
		_label(option, "苔林装" if index == 0 else "星夜装", Vector2(60, 13), 14, MOON if index == 0 else Color("c6b3ef"))
		_label(option, "绿兜帽 · 桃领巾" if index == 0 else "紫尖帽 · 星夜衣", Vector2(60, 35), 9, QUIET)
		option.pressed.connect(_choose_appearance.bind(index))
		_appearance_buttons.append(option)
	set_appearance(0)
	var resume := Button.new()
	card.add_child(resume)
	resume.position = Vector2(26, 278)
	resume.size = Vector2(203, 29)
	resume.text = "返回灯圃  [Esc]"
	resume.focus_mode = Control.FOCUS_NONE
	resume.add_theme_stylebox_override("normal", _style(Color("#2a4748"), MOON))
	resume.add_theme_stylebox_override("hover", _style(Color("#355755"), MOON))
	resume.pressed.connect(func() -> void: resume_requested.emit())
	_mute_button = Button.new()
	card.add_child(_mute_button)
	_mute_button.position = Vector2(240, 278)
	_mute_button.size = Vector2(112, 29)
	_mute_button.focus_mode = Control.FOCUS_NONE
	_mute_button.add_theme_stylebox_override("normal", _style(INK, QUIET))
	_mute_button.add_theme_stylebox_override("hover", _style(Color("#2a404d"), PAPER))
	_mute_button.pressed.connect(func() -> void: mute_requested.emit())


func _choose_appearance(index: int) -> void:
	appearance_selected.emit(index)


func _seed_button(at: Vector2, moon: bool, title: String, description: String) -> Button:
	var button := Button.new()
	_root.add_child(button)
	button.position = at
	button.size = Vector2(106, 50)
	button.focus_mode = Control.FOCUS_NONE
	_glyph(button, Vector2(8, 8), moon, true)
	_label(button, title, Vector2(28, 7), 13, MOON if moon else WARM)
	_label(button, description, Vector2(8, 31), 9, QUIET)
	return button


func _style_seed(button: Button, selected: bool, accent: Color) -> void:
	var fill := Color("#253f46") if selected else INK
	button.add_theme_stylebox_override("normal", _style(fill, accent if selected else Color("#41525e")))
	button.add_theme_stylebox_override("hover", _style(Color("#2e4950"), accent))
	button.add_theme_stylebox_override("pressed", _style(Color("#39575c"), accent))


func _glyph(parent: Node, at: Vector2, moon: bool, seed: bool = false) -> void:
	var glyph := SeedGlyph.new()
	glyph.moon = moon
	glyph.seed = seed
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
