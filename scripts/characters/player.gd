class_name FarmPlayer
extends CharacterBody2D
## 巡灯人的四向图集。脚底碰撞、交互点与外观选择相互独立。

const MOSS_ATLAS: Texture2D = preload("res://assets/art/runtime/keeper_moss.png")
const STAR_ATLAS: Texture2D = preload("res://assets/art/runtime/keeper_star.png")
const FRAME_SIZE := Vector2(32, 40)
const FOOT_ANCHOR := Vector2(16, 36)

@export var move_speed: float = 88.0
@export_enum("苔林装", "星夜装") var appearance: int = 0

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
	var frame := int(_walk_time * 8.0) % 4 if moving else 0
	# 源图集实际行序：下、右、左、上；左右各有独立提灯与挎包形状。
	var row := 0
	if facing == Vector2.RIGHT:
		row = 1
	elif facing == Vector2.LEFT:
		row = 2
	elif facing == Vector2.UP:
		row = 3
	var atlas := STAR_ATLAS if appearance == 1 else MOSS_ATLAS
	draw_rect(Rect2(-7, -2, 15, 3), Color(0.015, 0.035, 0.05, 0.45))
	# 提灯已画在人物帧中；此柔光只作装饰，不参与 GardenState 光照。
	var lantern_x := -8 if row >= 2 else 8
	var lantern_y := -7 + (frame % 2 if moving else 0)
	draw_circle(Vector2(lantern_x, lantern_y), 9.0, Color(1.0, 0.7, 0.35, 0.035))
	draw_circle(Vector2(lantern_x, lantern_y), 6.0, Color(1.0, 0.75, 0.42, 0.07))
	draw_texture_rect_region(atlas, Rect2(-FOOT_ANCHOR, FRAME_SIZE), Rect2(Vector2(frame, row) * FRAME_SIZE, FRAME_SIZE))
	if _celebration > 0.0:
		var travel := (0.9 - _celebration) * 19.0
		for index in range(6):
			var angle := float(index) * TAU / 6.0
			var spark := Vector2(cos(angle) * (6.0 + travel), sin(angle) * (6.0 + travel) - 13.0)
			draw_rect(Rect2(spark.round(), Vector2(2, 2)), Color(0.95, 0.86, 0.55, _celebration))
