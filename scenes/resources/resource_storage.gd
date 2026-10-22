extends "res://scenes/resources/interactable.gd"

const Inventory = preload("res://scenes/player/inventory.gd")
const CLOSED_TEXTURE = preload("res://assets/sprites/small_container_closed.png")
const OPEN_TEXTURE = preload("res://assets/sprites/small_container_opened.png")
signal menu_requested(storage: Node2D)
var inventory := Inventory.new()
var _closed_sprite: Sprite2D
var _open_sprite: Sprite2D
var _visual: Node2D
var _animation: Tween

func _init() -> void:
	inventory.capacity = 25
	inventory.slot_limit = 25

func _ready() -> void:
	super._ready()
	# Match the solid footprint to the visible closed sprite at its 2x scale.
	var bounds := CLOSED_TEXTURE.get_image().get_used_rect()
	var footprint := RectangleShape2D.new()
	footprint.size = Vector2(bounds.size) * 2.0
	var collision: CollisionShape2D
	for child in get_children():
		if child is CollisionShape2D:
			collision = child
			break
	if collision == null:
		collision = CollisionShape2D.new()
		add_child(collision)
	collision.shape = footprint
	collision.position = (Vector2(bounds.position) + Vector2(bounds.size) * 0.5 - CLOSED_TEXTURE.get_size() * 0.5) * 2.0
	_visual = Node2D.new()
	add_child(_visual)
	_closed_sprite = Sprite2D.new()
	_closed_sprite.texture = CLOSED_TEXTURE
	_closed_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_closed_sprite.scale = Vector2(2, 2)
	_visual.add_child(_closed_sprite)
	_open_sprite = Sprite2D.new()
	_open_sprite.texture = OPEN_TEXTURE
	_open_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_open_sprite.scale = Vector2(2, 2)
	_open_sprite.modulate.a = 0.0
	_visual.add_child(_open_sprite)
	selection_changed.connect(func(selected: bool) -> void:
		_visual.modulate = Color(1.15, 1.15, 1.15) if selected else Color.WHITE)

func set_opened(opened: bool) -> void:
	if _animation != null:
		_animation.kill()
	_animation = create_tween().set_parallel(true)
	_animation.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_animation.tween_property(_closed_sprite, "modulate:a", 0.0 if opened else 1.0, 0.22)
	_animation.tween_property(_open_sprite, "modulate:a", 1.0 if opened else 0.0, 0.22)
	_animation.tween_property(_visual, "position:y", -3.0 if opened else 0.0, 0.22)

func get_prompt() -> String:
	return "Контейнер %d/%d | E — открыть" % [inventory.total(), inventory.capacity]

func interact(_player_inventory: RefCounted, _secondary: bool = false) -> String:
	menu_requested.emit(self)
	return "Контейнер открыт"


