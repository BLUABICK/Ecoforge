extends SceneTree
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	print("PASS: " if ok else "FAIL: ", message)
	if not ok:
		failures += 1
func mouse(controller: Node2D, position: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = controller.get_canvas_transform() * position
	if pressed:
		controller._unhandled_input(event)
	else:
		controller._input(event)
func ctrl(pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_CTRL
	event.physical_keycode = KEY_CTRL
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()
func run() -> void:
	var world = preload("res://tests/playgrounds/resource_playground.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	var controller = world.construction
	controller.set_process(false)
	world.get_node("Player2d").position = Vector2(1404, 650)
	await physics_frame
	var source = preload("res://data/buildings/pipe.tres")
	for cells in range(1, 5):
		controller.begin(source)
		var start := Vector2(1404, 700)
		mouse(controller, start, true)
		check(controller._free_buildings.is_empty(), "Press begins preview without placing")
		var finish := start + Vector2(cells * 8.0, 0)
		controller.update_preview(finish)
		check(is_equal_approx(controller._wire_route[0].distance_to(controller._wire_route[1]), maxi(cells, 2) * 8.0), "Preview length is %d small cells" % cells)
		mouse(controller, finish, false)
		await physics_frame
		check(controller._free_buildings.size() == 1, "Release places one wire")
		var wire = controller._free_buildings.back()
		check(is_equal_approx(wire.route[0].distance_to(wire.route[1]), maxi(cells, 2) * 8.0), "Placed wire preserves drawn length")
		check(wire.get_child_count() == 2 and not wire.has_node("WorkVisual"), "Drawn wire has visual and collision")
		check(is_equal_approx(wire.route_width, 16.0) and is_equal_approx(wire.get_child(1).shape.size.y, 16.0), "Pipe visual and collision are two small cells wide")
		var shape = wire.get_child(1).shape
		var center: Vector2 = wire.get_child(1).position
		var corner: Vector2 = center - shape.size * 0.5
		check(is_equal_approx(corner.x / 8.0, roundf(corner.x / 8.0)) and is_equal_approx(corner.y / 8.0, roundf(corner.y / 8.0)), "Placed wire edges align with the small-cell grid")
		var adjacent_start := start + Vector2(0, 16.0)
		controller.update_preview(adjacent_start)
		check(controller.can_place, "Idle marker checks one cell instead of old full-length strip")
		mouse(controller, adjacent_start, true)
		mouse(controller, adjacent_start + Vector2(cells * 8.0, 0), false)
		await physics_frame
		check(controller._free_buildings.size() == 2, "Adjacent grid row allows a parallel wire")
		if controller._free_buildings.size() == 2:
			controller.remove_building(controller._free_buildings.back())
			await physics_frame
		controller.remove_building(wire)
		await physics_frame
	controller.begin(source)
	mouse(controller, Vector2(1404, 700), true)
	controller.update_preview(Vector2(1401.6, 900))
	check(is_equal_approx(controller._wire_route[0].distance_to(controller._wire_route[1]), 32.0), "Long drag clamps to four cells")
	mouse(controller, Vector2(1401.6, 900), false)
	await physics_frame
	var wire = controller._free_buildings.back()
	var endpoint: Vector2 = wire.connection_ends()[1].point
	mouse(controller, endpoint, true)
	check(controller._wire_start.is_equal_approx(endpoint), "Drawing snaps to a free endpoint")
	mouse(controller, endpoint + Vector2(0, 16.0), false)
	await physics_frame
	check(controller._free_buildings.size() == 2, "Drawn wire connects to existing endpoint")
	var next_wire = controller._free_buildings.back()
	check(wire.connected_outputs.has(next_wire) and next_wire.connected_inputs.has(wire), "End-to-start contact connects wires in drawing direction")
	check(next_wire.connected_outputs.is_empty() and wire.connected_inputs.is_empty(), "Connection does not run backwards")
	check(next_wire.input_point().is_equal_approx(endpoint) and next_wire.output_point().y > endpoint.y, "Wire retains the direction of the mouse drag")
	mouse(controller, Vector2(1500, 900), true)
	controller.cancel()
	mouse(controller, Vector2(1500, 920), false)
	check(controller._free_buildings.size() == 2, "Cancel prevents placement on release")
	controller.begin(source)
	controller._wire_route = PackedVector2Array([Vector2(1500, 900), Vector2(1548.0, 900)])
	check(not controller.confirm(), "Confirmation rejects wires longer than four cells")
	controller.remove_building(next_wire)
	check(wire.connected_outputs.is_empty(), "Removing a wire disconnects its neighbours")
	await physics_frame
	controller.cancel()
	for direction in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		controller.begin(source)
		mouse(controller, Vector2(1604, 804), true)
		mouse(controller, Vector2(1604, 804) + direction * 24.0, false)
		await physics_frame
		var directed_wire = controller._free_buildings.back()
		check((directed_wire.output_point() - directed_wire.input_point()).normalized().is_equal_approx(direction), "Direction follows drag in all four orientations")
		controller.remove_building(directed_wire)
		await physics_frame
	controller.begin(source)
	var long_start := Vector2(1500, 1004)
	mouse(controller, long_start, true)
	ctrl(true)
	controller.update_preview(long_start + Vector2(160, 0))
	check(is_equal_approx(controller._wire_route[0].distance_to(controller._wire_route[1]), 160.0), "Ctrl allows drawing twenty cells")
	ctrl(false)
	controller.update_preview(long_start + Vector2(160, 0))
	check(is_equal_approx(controller._wire_route[0].distance_to(controller._wire_route[1]), 32.0), "Releasing Ctrl restores four-cell limit during drawing")
	ctrl(true)
	mouse(controller, long_start + Vector2(160, 0), false)
	await physics_frame
	var pieces: Array = controller._free_buildings.filter(func(segment): return segment.input_point().y > 990.0)
	check(pieces.size() == 5, "Ctrl line splits into five manual-size segments")
	for index in pieces.size():
		check(is_equal_approx(pieces[index].input_point().distance_to(pieces[index].output_point()), 32.0), "Each segment is four small cells long")
		if index > 0:
			check(pieces[index - 1].connected_outputs.has(pieces[index]), "Split segments retain directed connections")
	ctrl(false)
	for piece in pieces:
		controller.remove_building(piece)
	await physics_frame
	world.queue_free()
	await process_frame
	print("Pipe drawing failures: ", failures)
	quit(1 if failures else 0)
