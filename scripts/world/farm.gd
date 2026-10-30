class_name FarmWorld
extends Node2D
## 林间农场只负责呈现与交互路由，经营规则保存在 GardenState 中。

const CELL_SIZE := 16
const MAP_SIZE := Vector2i(60, 40)
const SPAWN_POSITION := Vector2(488, 418)
const HOUSE_RECT := Rect2(256, 214, 124, 98)
const POND_RECT := Rect2(660, 300, 112, 88)
const INTERACTION_RADIUS := 20.0
const ANIMATION_STEP := 1.0 / 12.0
const ForestArtScript := preload("res://scripts/world/forest_art.gd")
const MOON_FRAMES: Array[Texture2D] = [
	preload("res://assets/art/runtime/moon_moss_0.png"), preload("res://assets/art/runtime/moon_moss_1.png"),
	preload("res://assets/art/runtime/moon_moss_2.png"), preload("res://assets/art/runtime/moon_moss_3.png"),
]
const BELL_FRAMES: Array[Texture2D] = [
	preload("res://assets/art/runtime/glow_bell_0.png"), preload("res://assets/art/runtime/glow_bell_1.png"),
	preload("res://assets/art/runtime/glow_bell_2.png"), preload("res://assets/art/runtime/glow_bell_3.png"),
]
const LANTERN_FRAMES: Array[Texture2D] = [
	preload("res://assets/art/runtime/lantern_broken.png"), preload("res://assets/art/runtime/lantern_off.png"),
	preload("res://assets/art/runtime/lantern_on.png"),
]

var garden: GardenState
var _target_cell := Vector2i(-1, -1)
var _target_lantern := -1
var _light_overlay := false
var _animation_time := 0.0
var _animation_accumulator := 0.0
var _air: ForestAir
var companion := false
var companion_anchor := Vector2.ZERO
var _touch_time := 0.0
var _touch_index := -1


class ForestAir extends Node2D:
	var forest: FarmWorld

	func _draw() -> void:
		if is_instance_valid(forest):
			forest._draw_atmosphere(self)


func _ready() -> void:
	# 静态节点不会因目标高亮、作物生长或萤火动画而重绘。
	var scenery := ForestArtScript.new()
	scenery.name = "CachedForestScenery"
	scenery.z_index = -10
	add_child(scenery)
	_air = ForestAir.new()
	_air.name = "FirefliesAndMist"
	_air.forest = self
	_air.z_index = 20
	add_child(_air)
	_add_collision(Rect2(-16, -16, 992, 16), "NorthBoundary")
	_add_collision(Rect2(-16, 640, 992, 16), "SouthBoundary")
	_add_collision(Rect2(-16, 0, 16, 640), "WestBoundary")
	_add_collision(Rect2(960, 0, 16, 640), "EastBoundary")
	_add_collision(HOUSE_RECT, "Cottage")
	_add_collision(POND_RECT, "Pond")
	_add_collision(Rect2(264, 335, 36, 17), "WestFence")
	_add_collision(Rect2(640, 442, 68, 17), "EastFence")
	_add_collision(Rect2(584, 454, 26, 23), "OldStump")
	# 完整树冠不可穿行。换正式Sprite后可改为Y排序与树干碰撞。
	for index in range(ForestArtScript.TREE_SPOTS.size()):
		var point: Vector2 = ForestArtScript.TREE_SPOTS[index]
		_add_collision(Rect2(point + Vector2(-50, -106), Vector2(101, 119)), "Tree%d" % index)
	for index in range(GardenState.LANTERN_POSITIONS.size()):
		var point: Vector2 = GardenState.LANTERN_POSITIONS[index]
		_add_collision(Rect2(point + Vector2(-5, -5), Vector2(10, 9)), "Lantern%d" % index)
	queue_redraw()


func bind_garden(value: GardenState) -> void:
	garden = value
	queue_redraw()


func _process(delta: float) -> void:
	_animation_time += delta
	_touch_time = maxf(0.0, _touch_time - delta)
	_animation_accumulator += delta
	if _animation_accumulator >= ANIMATION_STEP:
		_animation_accumulator = fmod(_animation_accumulator, ANIMATION_STEP)
		queue_redraw()
		if is_instance_valid(_air):
			_air.queue_redraw()


func get_world_rect() -> Rect2:
	return Rect2(Vector2.ZERO, Vector2(MAP_SIZE * CELL_SIZE))


func get_spawn_position() -> Vector2:
	return SPAWN_POSITION


func nearest_lit_lantern(point: Vector2) -> int:
	if garden == null:
		return -1
	for index in range(garden.lanterns.size()):
		var lamp: Dictionary = garden.lanterns[index]
		if lamp.restored and lamp.lit and point.distance_to(lamp.position) <= GardenState.LIGHT_RADIUS:
			return index
	return -1


func touch_companion(index: int) -> void:
	_touch_index = index
	_touch_time = 2.5


func set_interaction_target(world_position: Vector2) -> void:
	var cell := _world_to_cell(world_position)
	var lantern := _lantern_near(to_local(world_position))
	if cell != _target_cell or lantern != _target_lantern:
		_target_cell = cell
		_target_lantern = lantern
		queue_redraw()


func get_context(world_position: Vector2) -> Dictionary:
	if garden == null:
		return {"title": "林间空地", "detail": "苔灯正在醒来。", "action": "", "progress": -1.0, "condition": ""}
	var lantern := _lantern_near(to_local(world_position))
	if lantern >= 0:
		return garden.get_lantern_info(lantern)
	return garden.get_plot_info(_world_to_cell(world_position))


func interact(world_position: Vector2) -> String:
	if garden == null:
		return "林间苗床还未准备好。"
	var lantern := _lantern_near(to_local(world_position))
	if lantern >= 0:
		return garden.interact_lantern(lantern)
	return garden.plant_or_harvest(_world_to_cell(world_position))


func nourish(world_position: Vector2) -> String:
	if garden == null:
		return "林间苗床还未准备好。"
	if _lantern_near(to_local(world_position)) >= 0:
		return "露滴用来露养植物；苔灯可以按 E 操作。"
	return garden.nourish(_world_to_cell(world_position))


func clear_crop(world_position: Vector2) -> String:
	if garden == null:
		return "林间苗床还未准备好。"
	if _lantern_near(to_local(world_position)) >= 0:
		return "这里是苔灯。面朝苗床可移除植物。"
	return garden.clear_crop(_world_to_cell(world_position))


func set_light_overlay(is_visible: bool) -> void:
	_light_overlay = is_visible
	queue_redraw()


func _world_to_cell(world_position: Vector2) -> Vector2i:
	var point := to_local(world_position)
	return Vector2i(floori(point.x / CELL_SIZE), floori(point.y / CELL_SIZE))


func _lantern_near(local_position: Vector2) -> int:
	if garden == null:
		return -1
	var nearest := -1
	var distance_squared := INTERACTION_RADIUS * INTERACTION_RADIUS
	for index in range(garden.lanterns.size()):
		var point: Vector2 = garden.lanterns[index]["position"]
		var candidate := local_position.distance_squared_to(point)
		if candidate <= distance_squared:
			nearest = index
			distance_squared = candidate
	return nearest


func _add_collision(rectangle: Rect2, body_name: String) -> void:
	var body := StaticBody2D.new()
	body.name = body_name
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := RectangleShape2D.new()
	shape.size = rectangle.size
	var collider := CollisionShape2D.new()
	collider.shape = shape
	collider.position = rectangle.get_center()
	body.add_child(collider)
	add_child(body)


func _draw() -> void:
	if garden == null:
		return
	_draw_beds()
	_draw_ambient_light()
	if _light_overlay and not companion:
		_draw_light_ranges()
	for cell: Vector2i in garden.plots:
		var plot: Dictionary = garden.plots[cell]
		var crop: String = plot["crop"]
		if crop.is_empty():
			continue
		var center := Vector2(cell * CELL_SIZE) + Vector2(8, 11)
		var growth: float = plot["growth"]
		var thriving := garden.growth_condition(cell)
		if crop == "moon_moss":
			_draw_moon_moss(center, growth, thriving)
		else:
			_draw_glow_bell(center, growth, thriving)
	for index in range(garden.lanterns.size()):
		_draw_lantern(garden.lanterns[index], index)
	if companion:
		_draw_companion()
	else:
		_draw_target()


func _draw_beds() -> void:
	for cell: Vector2i in garden.plots:
		var p := Vector2(cell * CELL_SIZE)
		var lit := garden.is_lit(cell)
		var soil := Color("3c3d42") if not lit else Color("4b493e")
		draw_rect(Rect2(p, Vector2(16, 16)), Color("293738"))
		draw_rect(Rect2(p + Vector2.ONE, Vector2(14, 14)), soil)
		draw_rect(Rect2(p + Vector2(2, 2), Vector2(12, 1)), Color("58604d"))
		draw_rect(Rect2(p + Vector2(2, 13), Vector2(12, 1)), Color("303137"))
		for offset: Vector2 in [Vector2(4, 6), Vector2(10, 10), Vector2(5, 12)]:
			draw_rect(Rect2(p + offset, Vector2(2, 1)), Color("626354") if lit else Color("4a4d51"))
		# 外沿用苔石围边，内部保留清晰的16px种植格。
		if not garden.plots.has(cell + Vector2i.LEFT):
			draw_rect(Rect2(p + Vector2(-2, 3), Vector2(3, 10)), Color("66745c"))
			draw_rect(Rect2(p + Vector2(-2, 4), Vector2(1, 5)), Color("8a946b"))
		if not garden.plots.has(cell + Vector2i.RIGHT):
			draw_rect(Rect2(p + Vector2(15, 2), Vector2(3, 11)), Color("4f6455"))
		if not garden.plots.has(cell + Vector2i.UP):
			draw_rect(Rect2(p + Vector2(2, -2), Vector2(11, 3)), Color("6a775f"))
		if not garden.plots.has(cell + Vector2i.DOWN):
			draw_rect(Rect2(p + Vector2(3, 15), Vector2(10, 3)), Color("4e6254"))


func _draw_ambient_light() -> void:
	# 像素圆带叠成柔光，半径与经营模型一致。
	for lantern: Dictionary in garden.lanterns:
		if not bool(lantern["restored"]) or not bool(lantern["lit"]):
			continue
		var point: Vector2 = lantern["position"]
		for radius in range(78, 4, -6):
			_pixel_ellipse(self, Rect2(point - Vector2(radius, radius), Vector2(radius * 2, radius * 2)), Color(0.96, 0.71, 0.37, 0.015), 4)
		var flicker := 0.075 + sin(_animation_time * (0.75 if companion else 2.1) + point.x) * (0.025 if companion else 0.012)
		_pixel_ellipse(self, Rect2(point + Vector2(-15, -41), Vector2(30, 30)), Color(1.0, 0.8, 0.47, flicker), 2)
	# 窗光与池光仅作装饰，不影响种植。
	for radius in range(40, 3, -5):
		_pixel_ellipse(self, Rect2(Vector2(288, 288) - Vector2(radius, radius / 2), Vector2(radius * 2, radius)), Color(1.0, 0.68, 0.38, 0.012), 3)
	for radius in range(54, 12, -7):
		_pixel_ellipse(self, Rect2(Vector2(716, 344) - Vector2(radius, radius / 2), Vector2(radius * 2, radius)), Color(0.4, 0.76, 0.87, 0.015), 3)


func _draw_light_ranges() -> void:
	for lantern: Dictionary in garden.lanterns:
		if not bool(lantern["restored"]):
			continue
		var point: Vector2 = lantern["position"]
		var color := Color(0.98, 0.77, 0.42, 0.72) if bool(lantern["lit"]) else Color(0.55, 0.69, 0.77, 0.36)
		for index in range(64):
			var angle := index * TAU / 64.0
			var dash := (point + Vector2(cos(angle), sin(angle)) * GardenState.LIGHT_RADIUS).round()
			draw_rect(Rect2(dash, Vector2(2, 2)), color)


func _growth_frame(growth: float) -> int:
	if growth >= 1.0:
		return 3
	if growth >= 0.6:
		return 2
	return 1 if growth >= 0.25 else 0


func _draw_moon_moss(point: Vector2, growth: float, thriving: bool) -> void:
	var tint := Color.WHITE if thriving or growth >= 1.0 else Color("83948c")
	draw_texture(MOON_FRAMES[_growth_frame(growth)], point - Vector2(8, 12), tint)
	if growth >= 1.0:
		var glow := 0.11 + sin(_animation_time * 2.0 + point.x) * 0.03
		_pixel_ellipse(self, Rect2(point + Vector2(-8, -8), Vector2(16, 10)), Color(0.52, 0.9, 0.85, glow), 2)
		# 成熟标记独立于环境星点；保留方形露珠而不是高茎蓝花。
		draw_rect(Rect2(point + Vector2(0, -9), Vector2(2, 2)), Color("e3f2da"))


func _draw_glow_bell(point: Vector2, growth: float, thriving: bool) -> void:
	var tint := Color.WHITE if thriving or growth >= 1.0 else Color("919080")
	draw_texture(BELL_FRAMES[_growth_frame(growth)], point - Vector2(8, 14), tint)
	if growth >= 1.0:
		var glow := 0.11 + sin(_animation_time * 2.3 + point.y) * 0.03
		_pixel_ellipse(self, Rect2(point + Vector2(-7, -13), Vector2(15, 12)), Color(1.0, 0.75, 0.38, glow), 2)
		draw_rect(Rect2(point + Vector2(0, -14), Vector2(2, 2)), Color("fff0c4"))


func _draw_lantern(lantern: Dictionary, index: int) -> void:
	var point: Vector2 = lantern["position"]
	var restored: bool = lantern["restored"]
	var lit := restored and bool(lantern["lit"])
	var frame := 2 if lit else 1 if restored else 0
	_pixel_ellipse(self, Rect2(point + Vector2(-12, -4), Vector2(25, 9)), Color("243e3b"), 2)
	draw_texture(LANTERN_FRAMES[frame], point - Vector2(16, 42))
	for y in range(1, index + 2):
		draw_rect(Rect2(point + Vector2(-5 + y * 3, 0), Vector2(1, 2)), Color("afb78a"))


func _draw_target() -> void:
	var color := Color("e7d4a0")
	if _target_lantern >= 0:
		var point: Vector2 = garden.lanterns[_target_lantern]["position"]
		_draw_brackets(Rect2(point + Vector2(-16, -41), Vector2(32, 45)), color)
	elif garden.plots.has(_target_cell):
		_draw_brackets(Rect2(Vector2(_target_cell * CELL_SIZE), Vector2(16, 16)), color)


func _draw_companion() -> void:
	# 猫与旧书只是陪伴画面，不创建资源、好感或可领取物。
	var cat := companion_anchor + Vector2(22, -2)
	var twitch := 1.0 if _touch_time > 0.0 and _touch_index == 1 else 0.0
	_pixel_ellipse(self, Rect2(cat + Vector2(-6, -4), Vector2(16, 7)), Color("b49683"), 1)
	draw_rect(Rect2(cat + Vector2(-5, -7), Vector2(8, 5)), Color("c8b29a"))
	draw_rect(Rect2(cat + Vector2(-5, -9), Vector2(2, 3)), Color("c8b29a"))
	draw_rect(Rect2(cat + Vector2(1, -9), Vector2(2, 3)), Color("c8b29a"))
	draw_rect(Rect2(cat + Vector2(-3, -5), Vector2(1, 1)), Color("3a4145"))
	draw_rect(Rect2(cat + Vector2(0, -5), Vector2(1, 1)), Color("3a4145"))
	draw_rect(Rect2(cat + Vector2(8, -3 - twitch), Vector2(4, 2)), Color("c8b29a"))
	var book := companion_anchor + Vector2(-20, 1)
	draw_rect(Rect2(book, Vector2(10, 5)), Color("726b60"))
	draw_rect(Rect2(book + Vector2(1, -1), Vector2(8, 4)), Color("d9d3b4"))
	draw_rect(Rect2(book + Vector2(4, -1), Vector2(1, 4)), Color("9d9983"))
	if _touch_time > 0.0:
		var radius := (2.5 - _touch_time) * 10.0
		for i in range(8):
			var angle := i * TAU / 8.0 + _animation_time * 0.15
			var point := companion_anchor + Vector2(cos(angle), sin(angle)) * radius + Vector2(0, -15)
			draw_rect(Rect2(point.round(), Vector2.ONE), Color(0.9, 0.87, 0.65, _touch_time / 2.5))


func _draw_brackets(rectangle: Rect2, color: Color) -> void:
	for corner: Vector2 in [rectangle.position, Vector2(rectangle.end.x, rectangle.position.y), Vector2(rectangle.position.x, rectangle.end.y), rectangle.end]:
		var direction := Vector2(1 if corner.x == rectangle.position.x else -1, 1 if corner.y == rectangle.position.y else -1)
		draw_line(corner, corner + Vector2(direction.x * 4, 0), color, 1.0)
		draw_line(corner, corner + Vector2(0, direction.y * 4), color, 1.0)


func _draw_atmosphere(canvas: Node2D) -> void:
	# 薄雾用低透明度的窄像素带，萤火避免遮住玩法和人物。
	for index in range(5):
		var drift := sin(_animation_time * 0.12 + index * 2.1) * 12
		var point := Vector2(238 + index * 113 + drift, 472 + (index % 2) * 38)
		_pixel_ellipse(canvas, Rect2(point, Vector2(112, 9)), Color(0.58, 0.71, 0.76, 0.035), 2)
		_pixel_ellipse(canvas, Rect2(point + Vector2(23, 7), Vector2(82, 5)), Color(0.58, 0.71, 0.76, 0.025), 2)
	for index in range(22):
		var base := Vector2(215 + ((index * 97) % 560), 236 + ((index * 53) % 270))
		var position := (base + Vector2(sin(_animation_time * 0.35 + index) * 8, cos(_animation_time * 0.46 + index * 1.7) * 5)).round()
		var alpha := clampf(0.35 + sin(_animation_time * 1.4 + index * 2.3) * 0.45, 0.0, 0.8)
		canvas.draw_rect(Rect2(position - Vector2.ONE, Vector2(4, 4)), Color(0.72, 0.86, 0.54, alpha * 0.07))
		canvas.draw_rect(Rect2(position, Vector2(1, 1)), Color(0.89, 0.94, 0.66, alpha))
	for index in range(4):
		var width := 5 + ((index * 3) % 9)
		var point := Vector2(702 + index * 5, 326 + index * 8)
		var alpha := 0.12 + sin(_animation_time + index) * 0.06
		canvas.draw_rect(Rect2(point, Vector2(width, 1)), Color(0.72, 0.9, 0.94, alpha))


func _pixel_ellipse(canvas: Node2D, rectangle: Rect2, color: Color, step: int = 2) -> void:
	var center := rectangle.get_center()
	var radius := rectangle.size * 0.5
	for y in range(int(rectangle.position.y), int(rectangle.end.y), step):
		var normalized := clampf((y + step * 0.5 - center.y) / radius.y, -1.0, 1.0)
		var half_width := floori(sqrt(maxf(0.0, 1.0 - normalized * normalized)) * radius.x)
		canvas.draw_rect(Rect2(floori(center.x) - half_width, y, half_width * 2, step), color)
