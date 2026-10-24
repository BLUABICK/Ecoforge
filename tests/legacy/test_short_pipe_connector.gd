extends SceneTree
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	print("PASS: " if ok else "FAIL: ", message)
	if not ok:
		failures += 1
func run() -> void:
	var world = preload("res://tests/playgrounds/resource_playground.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	var controller = world.construction
	controller.set_process(false)
	var source = preload("res://data/buildings/pipe.tres")
	for gap in [1.0, 4.0, 8.0, 12.0]:
		var first: Node2D = source.scene.instantiate()
		first.route = PackedVector2Array([Vector2(1408, 704), Vector2(1424, 704)])
		first.set_meta("building_id", &"pipe")
		world.add_child(first)
		controller._free_buildings.append(first)
		var second: Node2D = source.scene.instantiate()
		second.route = PackedVector2Array([Vector2(1424 + gap, 704), Vector2(1440 + gap, 704)])
		second.set_meta("building_id", &"pipe")
		world.add_child(second)
		controller._free_buildings.append(second)
		await physics_frame
		controller.begin(source)
		var cursor := Vector2(1424 + gap * 0.5, 704)
		controller.update_preview(cursor)
		check(controller._wire_route.size() == 2 and controller.can_place, "Gap of %.1f pixels has a valid short connector preview" % gap)
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = true
		event.position = controller.get_canvas_transform() * cursor
		controller._unhandled_input(event)
		await physics_frame
		check(controller._free_buildings.size() == 3, "Click inserts a connector shorter than the normal minimum")
		var bridge = controller._free_buildings.back()
		check(is_equal_approx(bridge.route[0].distance_to(bridge.route[1]), gap) and is_equal_approx(bridge.route_width, 16.0), "Inserted connector fits the gap exactly with full pipe width")
		check(first.connected_outputs.has(bridge) and bridge.connected_outputs.has(second), "Short connector joins both directed pipe sections")
		for pipe in controller._free_buildings.duplicate():
			controller.remove_building(pipe)
		await physics_frame
	controller.begin(source)
	controller._start_wire_drawing(Vector2(1500, 804))
	controller.update_preview(Vector2(1508, 804))
	check(is_equal_approx(controller._wire_route[0].distance_to(controller._wire_route[1]), 16.0), "Standalone pipes retain the 2x2 minimum")
	controller.cancel()
	world.queue_free()
	await process_frame
	print("Short pipe connector failures: ", failures)
	quit(1 if failures else 0)
