extends Node2D
## Playable planet map built from the environment atlas.

@export var spawn_test_deposits: bool = false

const Deposit = preload("res://scenes/resources/resource_deposit.gd")
const Storage = preload("res://scenes/resources/resource_storage.gd")
const Visual = preload("res://tests/fixtures/resource_visual.gd")
const PlanetEnvironment = preload("res://scenes/world/planet_environment.gd")
var environment: Node2D
var _storage: StaticBody2D
var construction: Node2D

const WORLD_SIZE := Vector2(1920, 1280)
const CELL_SIZE: int = 64
const WALL_WIDTH: float = 32.0
const OBSTACLES: Array[Rect2] = [
	Rect2(640, 384, 192, 128),
	Rect2(1088, 640, 128, 256),
	Rect2(320, 896, 256, 64),
]


func _ready() -> void:
	environment = PlanetEnvironment.new()
	environment.name = "PlanetEnvironment"
	environment.z_index = -10
	add_child(environment)
	environment.build(OBSTACLES)
	_add_wall(Rect2(-WALL_WIDTH, -WALL_WIDTH, WORLD_SIZE.x + WALL_WIDTH * 2, WALL_WIDTH))
	_add_wall(Rect2(-WALL_WIDTH, WORLD_SIZE.y, WORLD_SIZE.x + WALL_WIDTH * 2, WALL_WIDTH))
	_add_wall(Rect2(-WALL_WIDTH, 0, WALL_WIDTH, WORLD_SIZE.y))
	_add_wall(Rect2(WORLD_SIZE.x, 0, WALL_WIDTH, WORLD_SIZE.y))
	var camera := $Player2d/Camera2D as Camera2D
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(WORLD_SIZE.x)
	camera.limit_bottom = int(WORLD_SIZE.y)
	_add_resources()
	var player_hud := preload("res://scenes/ui/player_hud.tscn").instantiate()
	$HUD.add_child(player_hud)
	player_hud.bind($Player2d)
	construction = preload("res://scenes/buildings/construction_controller.gd").new()
	construction.name = "Construction"
	construction.z_index = 10
	construction.bounds = Rect2(Vector2.ZERO, WORLD_SIZE)
	add_child(construction)
	construction.register_existing(_storage, preload("res://data/buildings/small_container.tres"), Vector2i(14, 21))
	var catalog: Array[Resource] = [preload("res://data/buildings/small_container.tres"), preload("res://data/buildings/cargo_container.tres"), preload("res://data/buildings/terminal.tres"), preload("res://data/buildings/trade_terminal.tres"), preload("res://data/buildings/delivery_pad.tres"), preload("res://data/buildings/technoformer.tres"), preload("res://data/buildings/conveyor.tres"), preload("res://data/buildings/router.tres"), preload("res://data/buildings/junction.tres"), preload("res://data/buildings/pipe.tres"), preload("res://data/buildings/liquid_pump.tres"), preload("res://data/buildings/gas_pump.tres"), preload("res://data/buildings/wire.tres")]
	player_hud.bind_construction(construction, catalog)


func _add_wall(rect: Rect2) -> void:
	var body := StaticBody2D.new()
	body.position = rect.get_center()
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	collision.shape = shape
	body.add_child(collision)
	add_child(body)


func _add_resources() -> void:
	if spawn_test_deposits:
		var iron := Deposit.new()
		iron.item = preload("res://data/items/iron_ore.tres")
		iron.remaining = 20
		_add_fixture(iron, Vector2(448, 320), "Железная руда", Color("b78057"))
		var limestone := Deposit.new()
		limestone.item = preload("res://data/items/limestone.tres")
		limestone.remaining = 20
		_add_fixture(limestone, Vector2(240, 560), "Известняк", Color("b8c2a0"))
	_storage = Storage.new()
	_add_fixture(_storage, Vector2(480, 680), "Контейнер", Color("528eb1"))


func _add_fixture(body: StaticBody2D, location: Vector2, title: String, tint: Color) -> void:
	body.position = location
	var shape := CircleShape2D.new()
	shape.radius = 30.0
	var collision := CollisionShape2D.new()
	collision.shape = shape
	body.add_child(collision)
	if not body is Storage:
		var visual := Visual.new()
		visual.title = title
		visual.tint = tint
		body.add_child(visual)
	add_child(body)
