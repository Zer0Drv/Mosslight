class_name FarmPlayer
extends CharacterBody2D
## 戴苔色兜帽的巡灯人。脚底碰撞与四向操作独立于像素绘制。

@export var move_speed: float = 88.0

var facing: Vector2 = Vector2.UP
var _walk_time := 0.0
var _celebration := 0.0


func _physics_process(delta: float) -> void:
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = direction * move_speed
	if direction != Vector2.ZERO:
		if absf(direction.x) > absf(direction.y):
			facing = Vector2(signf(direction.x), 0.0)
		else:
			facing = Vector2(0.0, signf(direction.y))
		_walk_time += delta
	else:
		_walk_time = 0.0
	_celebration = maxf(_celebration - delta, 0.0)
	move_and_slide()
	queue_redraw()


func get_interaction_position() -> Vector2:
	return global_position + facing * 16.0


func celebrate() -> void:
	_celebration = 0.9


func _draw() -> void:
	var moving := velocity.length() > 1.0
	var step := int(_walk_time * 8.0) % 2 if moving else 0
	var bob := step if moving else 0
	var outline := Color("#132333")
	draw_rect(Rect2(-7, -2, 15, 3), Color(0.015, 0.035, 0.05, 0.45))
	draw_rect(Rect2(-4, -4, 3, 4 - step), Color("#483f46"))
	draw_rect(Rect2(1, -4, 3, 3 + step), Color("#483f46"))
	draw_rect(Rect2(-5, -1 - step, 4, 2), Color("#ac7e62"))
	draw_rect(Rect2(1, -2 + step, 4, 2), Color("#ac7e62"))
	# 不对称披风轮廓，外缘以冷色月光提亮。
	draw_rect(Rect2(-5, -14 + bob, 10, 10), outline)
	draw_rect(Rect2(-6, -9 + bob, 12, 5), Color("#295158"))
	draw_rect(Rect2(-4, -14 + bob, 8, 10), Color("#467c79"))
	draw_rect(Rect2(-4, -13 + bob, 2, 7), Color("#7fae9b"))
	draw_rect(Rect2(3, -10 + bob, 2, 5), Color("#24454e"))
	draw_rect(Rect2(-5, -5, 3, 2), Color("#517d71"))
	draw_rect(Rect2(0, -5, 4, 2), Color("#39655f"))
	# 兜帽顶部与侧面，不借用农夫草帽轮廓。
	draw_rect(Rect2(-5, -22 + bob, 10, 9), outline)
	draw_rect(Rect2(-3, -24 + bob, 6, 3), outline)
	draw_rect(Rect2(-4, -21 + bob, 8, 8), Color("#4f7775"))
	draw_rect(Rect2(-2, -23 + bob, 5, 3), Color("#78a295"))
	draw_rect(Rect2(-4, -20 + bob, 2, 5), Color("#89b2a2"))
	if facing != Vector2.UP:
		draw_rect(Rect2(-2, -19 + bob, 6, 6), Color("#d5b89a"))
		draw_rect(Rect2(-2, -19 + bob, 6, 2), Color("#685261"))
		var eye_x := 2 if facing == Vector2.RIGHT else -1
		draw_rect(Rect2(eye_x, -16 + bob, 1, 1), outline)
		if facing == Vector2.DOWN:
			draw_rect(Rect2(2, -16 + bob, 1, 1), outline)
	else:
		draw_rect(Rect2(-2, -19 + bob, 5, 6), Color("#3d656b"))
		draw_rect(Rect2(0, -21 + bob, 1, 7), Color("#5e8c87"))
	draw_rect(Rect2(-4, -13 + bob, 9, 2), Color("#c48f6d"))
	draw_rect(Rect2(2, -11 + bob, 2, 5), Color("#dcac7f"))
	# 随身提灯只作人物点缀；生长光照来自灯圃里的固定苔灯。
	var lantern_x := -9 if facing == Vector2.LEFT else 7
	var lantern_y := -10 + step
	draw_circle(Vector2(lantern_x + 2, lantern_y + 3), 9.0, Color(1.0, 0.7, 0.35, 0.035))
	draw_circle(Vector2(lantern_x + 2, lantern_y + 3), 6.0, Color(1.0, 0.75, 0.42, 0.07))
	draw_rect(Rect2(lantern_x, lantern_y - 2, 4, 2), Color("#b59b76"))
	draw_rect(Rect2(lantern_x - 1, lantern_y, 6, 7), outline)
	draw_rect(Rect2(lantern_x, lantern_y + 1, 4, 4), Color("#edbb75"))
	draw_rect(Rect2(lantern_x + 1, lantern_y + 1, 2, 3), Color("#fff0c4"))
	if _celebration > 0.0:
		var travel := (0.9 - _celebration) * 19.0
		for index in range(6):
			var angle := float(index) * TAU / 6.0
			var spark := Vector2(cos(angle) * (6.0 + travel), sin(angle) * (6.0 + travel) - 13.0)
			draw_rect(Rect2(spark.round(), Vector2(2, 2)), Color(0.95, 0.86, 0.55, _celebration))
