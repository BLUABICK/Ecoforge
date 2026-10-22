extends Node

const Inventory = preload("res://scenes/player/inventory.gd")

signal target_changed(target: Node2D)
signal feedback(message: String)
signal storage_requested(storage: Node2D)

@export_range(32.0, 256.0, 1.0) var interaction_distance: float = 36.0
@export_range(0.1, 2.0, 0.1) var repeat_interval: float = 0.4
var inventory := Inventory.new()
var hotbar := Inventory.new()
var tools := Inventory.new()
var input_blocked: bool = false
var target: Node2D
var _cooldown: float = 0.0
@onready var actor := get_parent() as CharacterBody2D
@onready var interaction_area := get_parent().get_node("InteractionArea") as Area2D


func _init() -> void:
	inventory.slot_limit = 15
	hotbar.slot_limit = 5
	tools.slot_limit = 6
	tools.capacity = 6
	tools.add(&"sledgehammer", 1)
	tools.add(&"screwdriver", 1)


func _ready() -> void:
	var collision := interaction_area.get_node("CollisionShape2D") as CollisionShape2D
	collision.shape = collision.shape.duplicate()
	collision.shape.radius = interaction_distance


func _physics_process(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)
	refresh_target()
	if input_blocked:
		return
	if Input.is_action_just_pressed("interact_secondary"):
		interact(true)
	elif Input.is_action_pressed("interact") and _cooldown <= 0.0 and (not is_instance_valid(target) or not target.has_signal("menu_requested") or Input.is_action_just_pressed("interact")):
		interact()


func refresh_target() -> void:
	var nearest: Node2D
	var best_distance: float = INF
	# Query the Area2D shape directly so selection also updates immediately after a teleport.
	var collision := interaction_area.get_node("CollisionShape2D") as CollisionShape2D
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = collision.shape
	query.transform = collision.global_transform
	query.collision_mask = interaction_area.collision_mask
	query.exclude = [actor.get_rid()]
	for overlap in actor.get_world_2d().direct_space_state.intersect_shape(query, 256):
		var candidate := overlap.collider as Node2D
		if not candidate.is_in_group("interactables"):
			continue
		var distance := actor.global_position.distance_to(candidate.global_position)
		if distance > best_distance:
			continue
		var ray := PhysicsRayQueryParameters2D.create(actor.global_position, candidate.global_position)
		ray.exclude = [actor.get_rid()]
		var hit := actor.get_world_2d().direct_space_state.intersect_ray(ray)
		if not hit.is_empty() and hit.collider != candidate:
			continue
		nearest = candidate
		best_distance = distance
	if nearest == target:
		return
	if is_instance_valid(target):
		target.set_selected(false)
	target = nearest
	if is_instance_valid(target):
		target.set_selected(true)
	target_changed.emit(target)


func interact(secondary: bool = false) -> void:
	refresh_target()
	if input_blocked or actor.get_node("Vitals").health <= 0.0 or not is_instance_valid(target) or _cooldown > 0.0:
		return
	_cooldown = repeat_interval
	if target.has_signal("menu_requested"):
		storage_requested.emit(target)
	else:
		feedback.emit(target.interact(inventory, secondary))











