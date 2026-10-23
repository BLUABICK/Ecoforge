extends Node2D
## Temporary movement playground. Replace with the planet map in the next stage.

@export var spawn_test_deposits: bool = false

const Deposit = preload("res://scenes/resources/resource_deposit.gd")
const Storage = preload("res://scenes/resources/resource_storage.gd")
const Visual = preload("res://tests/fixtures/resource_visual.gd")
var _status: Label
var _prompt: Label
var _bag: Label
var _chest: Label
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
	_add_resources()
	_add_resource_hud()
	var player_hud := preload("res://scenes/ui/player_hud.tscn").instantiate()
	$HUD.add_child(player_hud)
	player_hud.bind($Player2d)
	construction = preload("res://scenes/buildings/construction_controller.gd").new()
	construction.name = "Construction"
	construction.z_index = 10
	construction.bounds = Rect2(Vector2.ZERO, WORLD_SIZE)
	add_child(construction)
	var catalog: Array[Resource] = [preload("res://data/buildings/small_container.tres"), preload("res://data/buildings/cargo_container.tres"), preload("res://data/buildings/terminal.tres"), preload("res://data/buildings/trade_terminal.tres"), preload("res://data/buildings/delivery_pad.tres"), preload("res://data/buildings/technoformer.tres"), preload("res://data/buildings/conveyor.tres"), preload("res://data/buildings/router.tres"), preload("res://data/buildings/junction.tres"), preload("res://data/buildings/pipe.tres"), preload("res://data/buildings/liquid_pump.tres"), preload("res://data/buildings/gas_pump.tres"), preload("res://data/buildings/wire.tres")]
	player_hud.bind_construction(construction, catalog)
	construction.feedback.connect(_on_feedback)


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


func _add_resource_hud() -> void:
	_bag = _label_at(100)
	_chest = _label_at(160)
	_prompt = _label_at(220)
	_status = _label_at(260)
	$Player2d/Interaction.feedback.connect(_on_feedback)


func _label_at(y: float) -> Label:
	var label := Label.new()
	label.position = Vector2(20, y)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$HUD.add_child(label)
	return label


func _process(_delta: float) -> void:
	if construction.active:
		_prompt.text = "ЛКМ — установить | R — повернуть | ПКМ — отменить"
		return
	var interaction := $Player2d/Interaction
	_prompt.text = interaction.target.get_prompt() if is_instance_valid(interaction.target) else "Подойди к контейнеру (синий)"


func _describe(inventory: RefCounted) -> String:
	return "Руда: %d | Известняк: %d" % [inventory.quantity(&"iron_ore"), inventory.quantity(&"limestone")]


func _on_feedback(message: String) -> void:
	_status.text = message
