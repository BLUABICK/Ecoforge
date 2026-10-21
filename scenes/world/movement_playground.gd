extends Node2D
## Temporary movement playground. Replace with the planet map in the next stage.

const WORLD_SIZE := Vector2(1920, 1280)
const CELL_SIZE: int = 64
const WALL_WIDTH: float = 32.0
const OBSTACLES: Array[Rect2] = [
	Rect2(640, 384, 192, 128),
	Rect2(1088, 640, 128, 256),
	Rect2(320, 896, 256, 64),
]


func _ready() -> void:
	_add_wall(Rect2(-WALL_WIDTH, -WALL_WIDTH, WORLD_SIZE.x + WALL_WIDTH * 2, WALL_WIDTH))
	_add_wall(Rect2(-WALL_WIDTH, WORLD_SIZE.y, WORLD_SIZE.x + WALL_WIDTH * 2, WALL_WIDTH))
	_add_wall(Rect2(-WALL_WIDTH, 0, WALL_WIDTH, WORLD_SIZE.y))
	_add_wall(Rect2(WORLD_SIZE.x, 0, WALL_WIDTH, WORLD_SIZE.y))
	for obstacle in OBSTACLES:
		_add_wall(obstacle)
	var camera := $Player2d/Camera2D as Camera2D
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(WORLD_SIZE.x)
	camera.limit_bottom = int(WORLD_SIZE.y)


func _add_wall(rect: Rect2) -> void:
	var body := StaticBody2D.new()
	body.position = rect.get_center()
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	collision.shape = shape
	body.add_child(collision)
	add_child(body)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, WORLD_SIZE), Color("243a39"))
	for x in range(0, int(WORLD_SIZE.x) + 1, CELL_SIZE):
		draw_line(Vector2(x, 0), Vector2(x, WORLD_SIZE.y), Color("304c49"))
	for y in range(0, int(WORLD_SIZE.y) + 1, CELL_SIZE):
		draw_line(Vector2(0, y), Vector2(WORLD_SIZE.x, y), Color("304c49"))
	for obstacle in OBSTACLES:
		draw_rect(obstacle, Color("65716e"))
		draw_rect(obstacle, Color("91a49c"), false, 2.0)
	draw_rect(Rect2(Vector2.ZERO, WORLD_SIZE), Color("91a49c"), false, 4.0)
