extends Node2D
## Separate torso and head pivots, with a limited neck turn through the front arc.

@export_range(30.0, 150.0, 1.0) var head_limit_degrees: float = 75.0
@export_range(1.0, 25.0, 0.5) var head_turn_speed: float = 5.5
@export_range(1.0, 30.0, 0.5) var body_turn_speed: float = 10.0
@export_range(8.0, 100.0, 1.0) var pixels_per_frame: float = 38.0
@export var art_forward_degrees: float = -90.0

const HANDS_1 = preload("res://assets/sprites/body_hands_1.png")
const NO_HANDS = preload("res://assets/sprites/body_without_hands.png")
const HANDS_2 = preload("res://assets/sprites/body_hands_2.png")
const WALK_FRAMES: Array[Texture2D] = [HANDS_1, NO_HANDS, HANDS_2, NO_HANDS]

var facing_angle: float = -PI / 2.0
var body_angle: float = -PI / 2.0
var head_relative_angle: float = 0.0
var frame_index: int = 0
var _distance: float = 0.0
var _was_walking: bool = false
@onready var body_pivot := $BodyPivot
@onready var head_pivot := $HeadPivot
@onready var body_sprite := $BodyPivot/Body


func face_point(point: Vector2) -> void:
	var difference := point - global_position
	if not difference.is_zero_approx():
		facing_angle = difference.angle()


func update_pose(direction: Vector2, travelled: float, delta: float, cursor: Vector2, aiming: bool = true) -> void:
	update_facing(direction, delta, cursor, aiming)
	update_walk_animation(direction, travelled)


func update_facing(direction: Vector2, delta: float, cursor: Vector2, aiming: bool = true) -> void:
	if not direction.is_zero_approx():
		facing_angle = direction.angle()
	var turn := angle_difference(body_angle, facing_angle)
	body_angle += clampf(turn * (1.0 - exp(-20.0 * delta)), -body_turn_speed * delta, body_turn_speed * delta)
	if aiming:
		var difference := cursor - global_position
		if difference.length_squared() > 0.01:
			var target_relative := wrapf(difference.angle() - body_angle, -PI, PI)
			var limit := deg_to_rad(head_limit_degrees)
			target_relative = clampf(target_relative, -limit, limit)
			# Numeric interpolation is intentional: never take the short path across the back.
			var eased_step := (target_relative - head_relative_angle) * (1.0 - exp(-8.0 * delta))
			head_relative_angle += clampf(eased_step, -head_turn_speed * delta, head_turn_speed * delta)
			head_relative_angle = clampf(head_relative_angle, -limit, limit)
	body_pivot.rotation = body_angle - deg_to_rad(art_forward_degrees)
	head_pivot.rotation = body_angle + head_relative_angle - deg_to_rad(art_forward_degrees)


func update_walk_animation(direction: Vector2, travelled: float) -> void:
	var walking := travelled > 0.01 and not direction.is_zero_approx()
	if walking:
		if not _was_walking:
			frame_index = 0
			_distance = 0.0
		_distance += travelled
		while _distance >= pixels_per_frame:
			_distance -= pixels_per_frame
			frame_index = (frame_index + 1) % WALK_FRAMES.size()
		body_sprite.texture = WALK_FRAMES[frame_index]
	else:
		frame_index = 0
		_distance = 0.0
		body_sprite.texture = NO_HANDS
	_was_walking = walking


