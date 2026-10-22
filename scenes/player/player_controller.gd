extends CharacterBody2D

@export_range(1.0, 1000.0, 1.0) var move_speed: float = 240.0
@export_range(1.0, 2.0, 0.05) var sprint_multiplier: float = 1.4
@export_range(0.2, 0.9, 0.05) var slow_multiplier: float = 0.5
@export var acceleration: float = 3600.0
@export var deceleration: float = 4800.0
var menu_open: bool = false
var _hitboxes: Array[CollisionShape2D] = []
var _hitbox_bases: Array[Transform2D] = []
@onready var vitals := $Vitals
@onready var visuals := $Visuals


func _ready() -> void:
	for child in get_children():
		if child is CollisionShape2D:
			_hitboxes.append(child)
			_hitbox_bases.append(child.transform)


func _physics_process(delta: float) -> void:
	var direction := Vector2.ZERO if menu_open else Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var slowing := Input.is_action_pressed("slow_walk")
	var sprinting: bool = vitals.update_sprint(delta, not direction.is_zero_approx(), Input.is_action_pressed("sprint") and not slowing)
	var speed := move_speed * sprint_multiplier if sprinting else move_speed
	if slowing:
		speed = move_speed * slow_multiplier
	if vitals.health <= 0.0:
		direction = Vector2.ZERO
	var target_velocity := direction * speed
	var rate := deceleration if direction.is_zero_approx() else acceleration
	velocity = velocity.move_toward(target_velocity, rate * delta)
	if menu_open or vitals.health <= 0.0:
		velocity = Vector2.ZERO
	visuals.update_facing(velocity.normalized() if not direction.is_zero_approx() else Vector2.ZERO, delta, get_global_mouse_position(), not menu_open and vitals.health > 0.0)
	_sync_hitboxes()
	move_and_slide()
	visuals.update_walk_animation(direction, get_position_delta().length())


func _input(event: InputEvent) -> void:
	if menu_open or vitals.health <= 0.0:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		if Input.get_vector("move_left", "move_right", "move_up", "move_down").is_zero_approx():
			visuals.face_point(get_canvas_transform().affine_inverse() * event.position)


func set_menu_open(open: bool) -> void:
	menu_open = open
	$Interaction.input_blocked = open
	if open:
		velocity = Vector2.ZERO


func _sync_hitboxes() -> void:
	var angle: float = visuals.body_pivot.rotation
	for index in _hitboxes.size():
		# CollisionShape2D must remain a direct child of CharacterBody2D.
		_hitboxes[index].position = _hitbox_bases[index].origin.rotated(angle)
		_hitboxes[index].rotation = _hitbox_bases[index].get_rotation() + angle

