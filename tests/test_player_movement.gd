extends SceneTree

var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	var world := scene.instantiate()
	root.add_child(world)
	var player := world.get_node("Player2d") as CharacterBody2D
	await physics_frame
	var start := player.position
	Input.action_press("move_right")
	await _frames(30)
	Input.action_release("move_right")
	var straight_distance := player.position.distance_to(start)
	_check(straight_distance > 100.0, "Right input moves player")
	await _frames(2)
	var stopped := player.position
	await _frames(5)
	_check(player.position.is_equal_approx(stopped), "Released input stops movement")
	player.position = start
	Input.action_press("move_right")
	Input.action_press("move_down")
	await _frames(30)
	Input.action_release("move_right")
	Input.action_release("move_down")
	_check(absf(player.position.distance_to(start) - straight_distance) < 5.0, "Diagonal speed equals straight speed")
	player.position = Vector2(200, 200)
	Input.action_press("sprint")
	Input.action_press("move_right")
	await _frames(10)
	_check(is_equal_approx(player.velocity.length(), 336.0), "Sprint increases speed by 40 percent")
	Input.action_press("move_down")
	await _frames(2)
	_check(is_equal_approx(player.velocity.length(), 336.0), "Sprint diagonal speed is normalized")
	Input.action_release("sprint")
	await _frames(2)
	_check(is_equal_approx(player.velocity.length(), 240.0), "Releasing sprint restores walk speed")
	Input.action_release("move_right")
	Input.action_release("move_down")
	player.position = Vector2(580, 448)
	Input.action_press("move_right")
	await _frames(60)
	Input.action_release("move_right")
	_check(player.position.x > 600.0 and player.position.x <= 621.0, "Obstacle blocks movement")
	player.position = Vector2(64, 200)
	Input.action_press("move_left")
	await _frames(60)
	Input.action_release("move_left")
	_check(player.position.x >= 19.0 and player.position.x < 25.0, "Map boundary blocks movement")
	var camera := player.get_node("Camera2D") as Camera2D
	_check(camera.enabled and camera.limit_right == 1920 and camera.limit_bottom == 1280, "Camera enabled with map limits")
	world.queue_free()
	await process_frame
	print("Movement checks finished. Failures: ", failures)
	quit(1 if failures else 0)


func _frames(count: int) -> void:
	for index in count:
		await physics_frame


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error(description)
