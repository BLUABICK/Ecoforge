extends CharacterBody2D

@export_range(1.0, 1000.0, 1.0) var move_speed: float = 240.0
@export_range(1.0, 2.0, 0.05) var sprint_multiplier: float = 1.4


func _physics_process(_delta: float) -> void:
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var speed := move_speed * sprint_multiplier if Input.is_action_pressed("sprint") else move_speed
	velocity = direction * speed
	move_and_slide()
