class_name ForestArt
extends Node2D
## 静态林地只绘制一次；Godot 会缓存这个节点的画布命令。
## 原创程序像素稿：轮廓由像素带组成，不依赖外部纹理。

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
		_fern(origin + Vector2(17, 4), Color("42604f"), 12)


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
	var p := HOUSE.position
	_ellipse(Rect2(p + Vector2(-8, 81), Vector2(132, 24)), Color("1b2c30"), 3)
	# 略微不对称的木屋：坡屋顶、草苔、石基和手作横梁。
	draw_rect(Rect2(p + Vector2(8, 42), Vector2(98, 50)), Color("5a514b"))
	draw_rect(Rect2(p + Vector2(11, 43), Vector2(92, 46)), Color("78664f"))
	for y in range(49, 88, 7):
		draw_rect(Rect2(p + Vector2(11, y), Vector2(92, 1)), Color("514b43"))
		draw_rect(Rect2(p + Vector2(12, y + 1), Vector2(90, 1)), Color("857253"))
	draw_rect(Rect2(p + Vector2(8, 42), Vector2(5, 49)), Color("454440"))
	draw_rect(Rect2(p + Vector2(101, 42), Vector2(5, 49)), Color("454440"))
	draw_rect(Rect2(p + Vector2(8, 88), Vector2(98, 8)), Color("485552"))
	for x in range(10, 104, 13):
		draw_rect(Rect2(p + Vector2(x, 88), Vector2(10, 2)), Color("73806b"))
		draw_rect(Rect2(p + Vector2(x + 5, 94), Vector2(8, 2)), Color("344543"))
	# 屋顶使用多层台阶形状；瓦片和苔簇打破整齐边界。
	var roof := PackedVector2Array([p + Vector2(-5, 44), p + Vector2(-5, 38), p + Vector2(4, 38), p + Vector2(4, 29), p + Vector2(14, 29), p + Vector2(14, 21), p + Vector2(25, 21), p + Vector2(25, 13), p + Vector2(36, 13), p + Vector2(36, 6), p + Vector2(79, 6), p + Vector2(79, 13), p + Vector2(91, 13), p + Vector2(91, 23), p + Vector2(102, 23), p + Vector2(102, 31), p + Vector2(112, 31), p + Vector2(112, 40), p + Vector2(119, 40), p + Vector2(119, 47)])
	draw_colored_polygon(roof, Color("273b3b"))
	for row in range(5):
		var start := 34 - row * 10
		var stop := 81 + row * 9
		for x in range(start, stop, 10):
			var tile := p + Vector2(x + (row % 2) * 3, 10 + row * 7)
			draw_rect(Rect2(tile, Vector2(9, 5)), Color("49604f") if (x + row) % 3 else Color("536952"))
			draw_rect(Rect2(tile + Vector2(1, 0), Vector2(7, 1)), Color("6d7d58"))
	draw_rect(Rect2(p + Vector2(-4, 43), Vector2(121, 4)), Color("36483f"))
	for cluster: Vector2 in [Vector2(8, 39), Vector2(26, 24), Vector2(57, 9), Vector2(80, 19), Vector2(98, 39)]:
		_ellipse(Rect2(p + cluster, Vector2(17, 5)), Color("6b8557"), 1)
		draw_rect(Rect2(p + cluster + Vector2(4, 4), Vector2(2, 6)), Color("4e7352"))
	# 烟囱和远处的一缕淡烟。
	draw_rect(Rect2(p + Vector2(85, -1), Vector2(12, 21)), Color("4c5354"))
	draw_rect(Rect2(p + Vector2(82, -3), Vector2(17, 5)), Color("6e7170"))
	draw_rect(Rect2(p + Vector2(88, 4), Vector2(6, 2)), Color("7d7c70"))
	_ellipse(Rect2(p + Vector2(85, -16), Vector2(12, 6)), Color(0.55, 0.62, 0.63, 0.12), 2)
	_ellipse(Rect2(p + Vector2(88, -28), Vector2(18, 7)), Color(0.55, 0.62, 0.63, 0.07), 2)
	# 门与暖光窗。
	draw_rect(Rect2(p + Vector2(46, 58), Vector2(25, 34)), Color("333e3b"))
	draw_rect(Rect2(p + Vector2(49, 60), Vector2(19, 31)), Color("4f5143"))
	for x in [52, 58, 64]:
		draw_rect(Rect2(p + Vector2(x, 62), Vector2(1, 27)), Color("66684c"))
	draw_rect(Rect2(p + Vector2(63, 77), Vector2(2, 2)), Color("dcbf79"))
	_window(p + Vector2(20, 56), Vector2(16, 20))
	_window(p + Vector2(80, 56), Vector2(15, 17))
	_stone(p + Vector2(45, 95), Vector2(29, 7), 0)
	_stone(p + Vector2(48, 103), Vector2(24, 6), 1)
	# 窗台、花盆、悬挂月纹牌。
	draw_rect(Rect2(p + Vector2(17, 77), Vector2(22, 3)), Color("41463c"))
	draw_rect(Rect2(p + Vector2(22, 76), Vector2(7, 5)), Color("966f57"))
	_fern(p + Vector2(25, 76), Color("90a56b"), 6)
	draw_rect(Rect2(p + Vector2(75, 43), Vector2(1, 7)), Color("84906d"))
	draw_rect(Rect2(p + Vector2(72, 49), Vector2(8, 9)), Color("374a43"))
	draw_arc(p + Vector2(76, 53), 2.0, 0.3, 4.2, 7, Color("ccb97e"), 1.0, false)
	# 藤蔓攀附右侧横梁。
	for y in range(48, 87, 6):
		draw_rect(Rect2(p + Vector2(103, y), Vector2(1, 6)), Color("577250"))
		draw_rect(Rect2(p + Vector2(100, y), Vector2(4, 2)), Color("7d8f5c"))


func _window(point: Vector2, size: Vector2) -> void:
	draw_rect(Rect2(point - Vector2.ONE, size + Vector2(2, 2)), Color("313d38"))
	draw_rect(Rect2(point, size), Color("d69e61"))
	draw_rect(Rect2(point + Vector2(2, 2), size - Vector2(4, 4)), Color("edc58b"))
	draw_rect(Rect2(point + Vector2(size.x / 2, 0), Vector2(2, size.y)), Color("6e654b"))
	draw_rect(Rect2(point + Vector2(0, size.y / 2), Vector2(size.x, 2)), Color("6e654b"))


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
	var tint := Color("264744") if variation % 3 else Color("2d424b")
	_ellipse(Rect2(origin + Vector2(-36, -5), Vector2(74, 22)), Color("142a2d"), 3)
	# 像素根系和分叉树干。
	draw_colored_polygon(PackedVector2Array([origin + Vector2(-14, 7), origin + Vector2(-6, -4), origin + Vector2(-6, -45), origin + Vector2(7, -47), origin + Vector2(8, -5), origin + Vector2(20, 7), origin + Vector2(6, 4), origin + Vector2(2, 0), origin + Vector2(-4, 6)]), Color("3b3b39"))
	draw_rect(Rect2(origin + Vector2(-2, -38), Vector2(4, 40)), Color("5b5244"))
	draw_rect(Rect2(origin + Vector2(3, -29), Vector2(2, 31)), Color("6a5b47"))
	draw_line(origin + Vector2(0, -27), origin + Vector2(-20, -45), Color("4b493d"), 5.0)
	draw_line(origin + Vector2(5, -31), origin + Vector2(22, -50), Color("4b493d"), 4.0)
	# 各簇树冠重叠成不规则轮廓，阴影、叶片和苔藓共用窄色阶。
	_canopy(origin + Vector2(-26, -47), Vector2(48, 37), tint.darkened(0.14), variation + 1)
	_canopy(origin + Vector2(22, -54), Vector2(53, 41), tint, variation + 2)
	_canopy(origin + Vector2(-4, -68), Vector2(64, 45), tint.lightened(0.07), variation + 3)
	_canopy(origin + Vector2(-24, -75), Vector2(42, 31), tint.lightened(0.05), variation + 4)
	_canopy(origin + Vector2(14, -88), Vector2(43, 31), tint.lightened(0.1), variation + 5)
	for offset: Vector2 in [Vector2(-26, -35), Vector2(22, -37), Vector2(6, -55)]:
		draw_rect(Rect2(origin + offset, Vector2(2, 9)), Color("4b6e57"))
		draw_rect(Rect2(origin + offset + Vector2(-2, 7), Vector2(3, 4)), Color("6b8060"))
	if variation % 3 == 0:
		_mushroom(origin + Vector2(10, 4), true)


func _canopy(center: Vector2, size: Vector2, color: Color, variation: int) -> void:
	var rect := Rect2(center - size * 0.5, size)
	_ellipse(Rect2(rect.position + Vector2(0, 4), rect.size), color.darkened(0.2), 3)
	_ellipse(rect, color, 3)
	_ellipse(Rect2(rect.position + Vector2(5, 2), Vector2(size.x * 0.6, size.y * 0.4)), color.lightened(0.06), 2)
	for index in range(17):
		var point := rect.position + Vector2(_random.randi_range(7, int(size.x) - 8), _random.randi_range(5, int(size.y) - 8))
		var leaf_color := color.lightened(0.13) if (index + variation) % 3 else color.darkened(0.12)
		draw_rect(Rect2(point.round(), Vector2(_random.randi_range(3, 6), 2)), leaf_color)
		draw_rect(Rect2((point + Vector2(2, -1)).round(), Vector2(2, 1)), leaf_color)


func _stump(origin: Vector2) -> void:
	_ellipse(Rect2(origin + Vector2(-16, -2), Vector2(34, 12)), Color("1b3232"), 2)
	draw_rect(Rect2(origin + Vector2(-11, -14), Vector2(24, 19)), Color("584d43"))
	for x in [-8, -3, 4, 9]:
		draw_rect(Rect2(origin + Vector2(x, -11), Vector2(2, 14)), Color("716149"))
	_ellipse(Rect2(origin + Vector2(-12, -18), Vector2(26, 10)), Color("8d8061"), 1)
	_ellipse(Rect2(origin + Vector2(-7, -16), Vector2(16, 5)), Color("615c48"), 1)
	_ellipse(Rect2(origin + Vector2(-4, -15), Vector2(9, 3)), Color("a0946c"), 1)
	_mushroom(origin + Vector2(-11, -1), true)


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
