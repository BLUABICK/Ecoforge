extends SceneTree

var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1152, 720)
	var world := preload("res://tests/playgrounds/resource_playground.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	var player := world.get_node("Player2d")
	player.set_physics_process(false)
	var visuals := player.get_node("Visuals")
	visuals.facing_angle = 0.0
	visuals.body_angle = 0.0
	visuals.head_relative_angle = 0.0
	visuals.update_pose(Vector2.ZERO, 0, 1.0, player.global_position + Vector2.DOWN * 100)
	_check(is_equal_approx(visuals.body_angle, 0.0), "Idle torso keeps last direction")
	_check(absf(visuals.head_relative_angle - deg_to_rad(75)) < 0.01, "Head follows mouse independently")
	visuals.head_relative_angle = deg_to_rad(75)
	visuals.update_pose(Vector2.ZERO, 0, 0.1, player.global_position + Vector2(-100, -20))
	_check(visuals.head_relative_angle > 0 and visuals.head_relative_angle < deg_to_rad(75), "Rear crossing turns back through front arc")
	for index in 50:
		visuals.update_pose(Vector2.ZERO, 0, 0.02, player.global_position + Vector2(-100, -20))
	_check(absf(visuals.head_relative_angle) <= deg_to_rad(75.01), "Head remains within neck limits")
	visuals.face_point(player.global_position + Vector2.DOWN * 100)
	visuals.update_pose(Vector2.ZERO, 0, 1.0, player.global_position, false)
	_check(is_equal_approx(visuals.body_angle, PI / 2), "Idle click target turns torso")
	visuals.face_point(player.global_position + Vector2.LEFT * 100)
	visuals.update_pose(Vector2.RIGHT, 1.0, 1.0, player.global_position, false)
	_check(is_equal_approx(visuals.body_angle, 0.0), "Movement direction overrides click target")
	_check(visuals.body_sprite.texture == visuals.HANDS_1, "Walk starts with hands frame one")
	visuals.update_pose(Vector2.RIGHT, 37.0, 0.15, player.global_position, false)
	_check(visuals.body_sprite.texture == visuals.NO_HANDS, "Walk frame two has no hands")
	visuals.update_pose(Vector2.RIGHT, 38.0, 0.15, player.global_position, false)
	_check(visuals.body_sprite.texture == visuals.HANDS_2, "Walk frame three has hands two")
	visuals.update_pose(Vector2.RIGHT, 38.0, 0.15, player.global_position, false)
	_check(visuals.body_sprite.texture == visuals.NO_HANDS, "Walk frame four has no hands")
	visuals.update_pose(Vector2.ZERO, 0, 0.1, player.global_position, false)
	_check(visuals.body_sprite.texture == visuals.NO_HANDS, "Stopping resets to idle")
	visuals.update_pose(Vector2.RIGHT, 0, 0.2, player.global_position, false)
	_check(visuals.body_sprite.texture == visuals.NO_HANDS, "Blocked movement does not animate walking")
	_check(player.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST and visuals.scale == Vector2(3, 3), "Pixel art uses nearest filtering and integer scale")
	var facing_before: float = visuals.facing_angle
	player.menu_open = true
	var event := InputEventMouseButton.new()
	event.pressed = true
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = Vector2.ZERO
	player._input(event)
	_check(visuals.facing_angle == facing_before, "Inventory clicks do not turn torso")
	player.menu_open = false
	visuals.body_angle = -PI / 2.0
	visuals.facing_angle = -PI / 2.0
	visuals.head_relative_angle = 0.0
	visuals.update_pose(Vector2.ZERO, 0, 1.0, player.global_position + Vector2.UP * 100)
	for angle in [0.0, PI / 2.0, PI, -PI / 2.0]:
		visuals.body_pivot.rotation = angle
		player._sync_hitboxes()
		_check(absf(angle_difference(player.get_node("CollisionShape2D2").rotation, PI / 2.0 + angle)) < 0.001, "Body hitbox follows torso rotation")
	_check(player.get_node("CollisionShape2D").shape.radius == 12.0 and player.get_node("CollisionShape2D2").shape.height == 42.0, "User hitbox dimensions preserved")
	print("Player visuals checks finished. Failures: ", failures)
	if "--capture" in OS.get_cmdline_user_args():
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("C:/Users/admin/Documents/Codex/2026-10-21/new-chat/work/pixel-player-preview.png")
	world.queue_free()
	await process_frame
	quit(1 if failures else 0)


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error(description)



