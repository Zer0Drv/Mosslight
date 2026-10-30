class_name ForestArt
extends Node2D
## 静态林地只绘制一次；Godot 会缓存这个节点的画布命令。
## 导入的透明像素物件与程序地表分层，位置和碰撞仍由原地图定义。
const COTTAGE: Texture2D = preload("res://assets/art/runtime/cottage.png")
const TREE: Texture2D = preload("res://assets/art/runtime/tree.png")
const STUMP: Texture2D = preload("res://assets/art/runtime/stump.png")
const MUSHROOM_FERN: Texture2D = preload("res://assets/art/runtime/mushroom_fern.png")

const TREE_SPOTS: Array[Vector2] = [
	Vector2(100, 192), Vector2(165, 238), Vector2(224, 196),
	Vector2(310, 166), Vector2(392, 194), Vector2(478, 182),
	Vector2(556, 196), Vector2(650, 188), Vector2(728, 230),
	Vector2(815, 274), Vector2(868, 352), Vector2(828, 440),
	Vector2(792, 548), Vector2(706, 578), Vector2(628, 594),
	Vector2(535, 612), Vector2(436, 598), Vector2(348, 592),
	Vector2(250, 578), Vector2(170, 532), Vector2(122, 446),
	Vector2(165, 356), Vector2(82, 320), Vector2(879, 188),
]
const HOUSE := Rect2(260, 216, 112, 96)
const POND := Rect2(660, 300, 112, 88)

var _random := RandomNumberGenerator.new()


func _draw() -> void:
	_random.seed = 240728
	_ground()
	_path()
	_forest_floor()
	_pond()
	_house()
	_stump(Vector2(596, 472))
	_sign(Vector2(403, 386))
	_fence(Vector2(264, 348), 2)
	_fence(Vector2(640, 455), 4)
	for index in range(TREE_SPOTS.size()):
		_tree(TREE_SPOTS[index], index)
	# 屏幕边缘的蕨丛和巨叶，形成有层次的林下空间。
	for origin: Vector2 in [Vector2(230, 502), Vector2(340, 528), Vector2(648, 505), Vector2(771, 432), Vector2(214, 302), Vector2(600, 227)]:
		_fern(origin, Color("3c685a"), 17)
		draw_texture(MUSHROOM_FERN, origin + Vector2(4, -19), Color("a5b9a5"))


func _ground() -> void:
	draw_rect(Rect2(0, 0, 960, 640), Color("172431"))
	_ellipse(Rect2(125, 170, 727, 425), Color("223837"), 8)
	_ellipse(Rect2(196, 205, 598, 333), Color("2a413b"), 6)
	_ellipse(Rect2(306, 260, 339, 227), Color("31463c"), 5)
	_ellipse(Rect2(425, 217, 238, 139), Color("283e3d"), 5)
	for index in range(390):
		var position := Vector2(_random.randi_range(20, 940), _random.randi_range(130, 622))
		var size := Vector2(_random.randi_range(5, 24), _random.randi_range(3, 9))
		var colors: Array[Color] = [Color("263c3b"), Color("30483f"), Color("283e3e"), Color("26383a")]
		_ellipse(Rect2(position, size), colors[index % colors.size()], 2)
	for index in range(1600):
		var point := Vector2(_random.randi_range(10, 950), _random.randi_range(140, 630))
		var color := Color("47604b") if index % 3 == 0 else Color("355149")
		draw_rect(Rect2(point, Vector2(1, _random.randi_range(2, 4))), color)
		if index % 2 == 0:
			draw_rect(Rect2(point + Vector2(-2, 2), Vector2(2, 1)), color)
	for index in range(100):
		var point := Vector2(_random.randi_range(200, 800), _random.randi_range(230, 540))
		draw_rect(Rect2(point, Vector2(2, 1)), Color("7b8062"))
		draw_rect(Rect2(point + Vector2(3, 2), Vector2(1, 1)), Color("4e6f59"))


func _path() -> void:
	var points: Array[Vector2] = [Vector2(320, 313), Vector2(322, 337), Vector2(341, 358), Vector2(370, 377), Vector2(399, 392), Vector2(429, 403), Vector2(458, 415), Vector2(489, 422), Vector2(520, 432), Vector2(551, 437), Vector2(584, 432), Vector2(616, 421), Vector2(644, 408), Vector2(674, 401), Vector2(699, 397)]
	for point in points:
		_ellipse(Rect2(point - Vector2(21, 13), Vector2(42, 25)), Color("3a4942"), 3)
	for index in range(points.size()):
		var point := points[index]
		var width := _random.randi_range(16, 23)
		var height := _random.randi_range(8, 12)
		_stone(point - Vector2(width / 2, height / 2), Vector2(width, height), index)
		if index % 2 == 0:
			_stone(point + Vector2(-7, 9), Vector2(9, 5), index + 2)
	# 通向旧灯的小径，石缝留有苔藓。
	for point: Vector2 in [Vector2(596, 392), Vector2(616, 369), Vector2(620, 341), Vector2(618, 320)]:
		_stone(point, Vector2(13, 7), 1)


func _stone(point: Vector2, size: Vector2, shade: int) -> void:
	var base := Color("626c68") if shade % 2 == 0 else Color("535f60")
	var polygon := PackedVector2Array([point + Vector2(2, 0), point + Vector2(size.x - 3, 0), point + Vector2(size.x, 3), point + Vector2(size.x - 1, size.y - 1), point + Vector2(3, size.y + 1), point + Vector2(0, size.y - 2)])
	draw_colored_polygon(polygon, Color("253b3a"))
	for index in range(polygon.size()):
		polygon[index].y -= 2
	draw_colored_polygon(polygon, base)
	draw_rect(Rect2(point + Vector2(3, -2), Vector2(size.x - 7, 1)), Color("7a8273"))
	draw_rect(Rect2(point + Vector2(3, size.y - 3), Vector2(5, 1)), Color("637950"))
	if size.x > 15:
		draw_line(point + Vector2(size.x - 6, 1), point + Vector2(size.x - 9, size.y - 3), Color("3e5150"), 1.0)


func _forest_floor() -> void:
	var fern_spots: Array[Vector2] = [Vector2(241, 379), Vector2(258, 426), Vector2(389, 261), Vector2(621, 262), Vector2(641, 294), Vector2(780, 388), Vector2(591, 503), Vector2(459, 505), Vector2(386, 462), Vector2(254, 496), Vector2(754, 485)]
	for point in fern_spots:
		_fern(point, Color("547655"), 11)
		_fern(point + Vector2(10, 3), Color("3e6254"), 8)
	for point: Vector2 in [Vector2(244, 335), Vector2(392, 294), Vector2(649, 433), Vector2(756, 413), Vector2(281, 471), Vector2(589, 255), Vector2(614, 492)]:
		_mushroom(point, false)
		_mushroom(point + Vector2(7, 4), true)
		_mushroom(point + Vector2(-5, 6), true)
	for point: Vector2 in [Vector2(229, 416), Vector2(628, 242), Vector2(748, 457), Vector2(404, 493)]:
		_stone(point, Vector2(16, 11), 0)
		_stone(point + Vector2(13, 5), Vector2(8, 6), 1)
	# 菌圈是一圈不完整的细小蓝点，不做大面积高亮。
	for index in range(12):
		var angle := index * TAU / 12.0
		var point := Vector2(631, 476) + Vector2(cos(angle) * 22, sin(angle) * 11).round()
		draw_rect(Rect2(point, Vector2(2, 2)), Color("88bba6"))


func _fern(origin: Vector2, color: Color, height: int) -> void:
	for branch in [-1, 0, 1]:
		var tip := origin + Vector2(branch * height, -height + absi(branch) * 4)
		draw_line(origin, tip, color.darkened(0.18), 1.0)
		for step in range(2, height, 3):
			var ratio := float(step) / height
			var center := origin.lerp(tip, ratio).round()
			var width := maxi(2, int((1.0 - ratio) * 5))
			draw_line(center, center + Vector2(-width, -3), color, 1.0)
			draw_line(center, center + Vector2(width, -3), color.lightened(0.08), 1.0)


func _mushroom(origin: Vector2, small: bool) -> void:
	var width := 5 if small else 9
	var height := 4 if small else 7
	draw_rect(Rect2(origin + Vector2(0, -height), Vector2(2, height)), Color("7b9c97"))
	_ellipse(Rect2(origin + Vector2(-width / 2, -height - 3), Vector2(width, 5)), Color("87b9ae") if small else Color("a9b5b6"), 1)
	draw_rect(Rect2(origin + Vector2(-1, -height - 3), Vector2(2, 1)), Color("d1d8be"))
	draw_rect(Rect2(origin + Vector2(-3, -height + 1), Vector2(width - 2, 1)), Color("4c777d"))


func _house() -> void:
	_ellipse(Rect2(HOUSE.position + Vector2(-8, 81), Vector2(132, 24)), Color("1b2c30"), 3)
	draw_texture(COTTAGE, HOUSE.position + Vector2(-6, -7), Color("d8e0d7"))


func _pond() -> void:
	var p := POND.position
	_ellipse(Rect2(p - Vector2(8, 6), POND.size + Vector2(16, 12)), Color("233b3d"), 3)
	_ellipse(POND, Color("526459"), 3)
	_ellipse(Rect2(p + Vector2(5, 5), POND.size - Vector2(10, 10)), Color("315b66"), 3)
	_ellipse(Rect2(p + Vector2(11, 12), POND.size - Vector2(22, 25)), Color("2d5063"), 3)
	_ellipse(Rect2(p + Vector2(22, 23), POND.size - Vector2(43, 43)), Color("34465f"), 3)
	for index in range(23):
		var angle := TAU * index / 23.0
		var point := p + POND.size * 0.5 + Vector2(cos(angle) * 51, sin(angle) * 39).round()
		_stone(point - Vector2(4, 2), Vector2(_random.randi_range(6, 11), _random.randi_range(4, 7)), index)
	for point: Vector2 in [Vector2(15, 38), Vector2(69, 21), Vector2(62, 62)]:
		draw_rect(Rect2(p + point, Vector2(16, 1)), Color("729d9e"))
		draw_rect(Rect2(p + point + Vector2(5, 3), Vector2(9, 1)), Color("466e83"))
	for point: Vector2 in [Vector2(21, 51), Vector2(75, 29)]:
		_ellipse(Rect2(p + point, Vector2(13, 7)), Color("5a826c"), 1)
		draw_rect(Rect2(p + point + Vector2(7, 0), Vector2(1, 4)), Color("304e4d"))
		draw_rect(Rect2(p + point + Vector2(2, -2), Vector2(4, 3)), Color("d1b0c3"))
	for point: Vector2 in [Vector2(-3, 55), Vector2(88, 74), Vector2(8, 9)]:
		_fern(p + point, Color("588a78"), 12)


func _tree(origin: Vector2, variation: int) -> void:
	_ellipse(Rect2(origin + Vector2(-36, -5), Vector2(74, 22)), Color("142a2d"), 3)
	# 现有全树冠碰撞覆盖此轮廓；冷色调使树木退到夜色背景。
	var tint := Color("779a97") if variation % 3 else Color("818fa0")
	draw_texture(TREE, origin + Vector2(-56, -108), tint)


func _stump(origin: Vector2) -> void:
	_ellipse(Rect2(origin + Vector2(-16, -2), Vector2(34, 12)), Color("1b3232"), 2)
	draw_texture(STUMP, origin + Vector2(-20, -25), Color("c4cfbd"))


func _sign(origin: Vector2) -> void:
	draw_rect(Rect2(origin + Vector2(0, -12), Vector2(3, 17)), Color("6e6750"))
	draw_rect(Rect2(origin + Vector2(-8, -21), Vector2(21, 13)), Color("3c4a43"))
	draw_rect(Rect2(origin + Vector2(-7, -20), Vector2(19, 10)), Color("6d6d50"))
	draw_arc(origin + Vector2(-2, -15), 3.0, 0.4, 4.2, 8, Color("c1c2a0"), 1.0, false)
	draw_rect(Rect2(origin + Vector2(5, -17), Vector2(2, 5)), Color("d9b474"))
	draw_rect(Rect2(origin + Vector2(3, -15), Vector2(6, 1)), Color("d9b474"))


func _fence(origin: Vector2, sections: int) -> void:
	draw_line(origin + Vector2(0, -11), origin + Vector2(sections * 16, -9), Color("645e4b"), 3.0)
	draw_line(origin + Vector2(0, -5), origin + Vector2(sections * 16, -4), Color("4e5144"), 2.0)
	for index in range(sections + 1):
		var p := origin + Vector2(index * 16, -17 + index % 2)
		draw_rect(Rect2(p, Vector2(4, 21)), Color("555847"))
		draw_rect(Rect2(p, Vector2(4, 2)), Color("92916a"))
		if index % 2 == 0:
			draw_rect(Rect2(p + Vector2(-2, 12), Vector2(5, 2)), Color("64815b"))


func _ellipse(rectangle: Rect2, color: Color, step: int = 2) -> void:
	var center := rectangle.get_center()
	var radius := rectangle.size * 0.5
	if radius.x <= 0.0 or radius.y <= 0.0:
		return
	for y in range(int(rectangle.position.y), int(rectangle.end.y), step):
		var normalized := clampf((y + step * 0.5 - center.y) / radius.y, -1.0, 1.0)
		var half_width := floori(sqrt(maxf(0.0, 1.0 - normalized * normalized)) * radius.x)
		draw_rect(Rect2(floori(center.x) - half_width, y, half_width * 2, step), color)
