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
	for index in 2:
		var pipe: Node2D = source.scene.instantiate()
		pipe.route = PackedVector2Array([Vector2(1400, 700), Vector2(1400, 716)]) if index == 0 else PackedVector2Array([Vector2(1424, 700), Vector2(1424, 732)])
		pipe.set_meta("building_id", &"pipe")
		world.add_child(pipe)
		controller._free_buildings.append(pipe)
	await physics_frame
	controller.begin(source)
	controller.update_preview(Vector2(1412, 700))
	check(controller._wire_route.size() >= 3 and controller.can_place, "Placing in the gap between offset parallel pipes offers a connector")
	check(controller.confirm(), "Offset pipes can be joined by the intervening pipe")
	await physics_frame
	var bridge = controller._free_buildings.back()
	check(bridge.route_is_rounded and bridge.route.size() > 6, "Pipe elbows use a rounded curve")
	var diagonal_segments := 0
	for index in bridge.route.size() - 1:
		var delta: Vector2 = bridge.route[index + 1] - bridge.route[index]
		if absf(delta.x) > 0.001 and absf(delta.y) > 0.001:
			diagonal_segments += 1
	check(diagonal_segments > 0, "Rounding changes the actual pipe shape and collision path")
	world.queue_free()
	await process_frame
	print("Rounded pipe connector failures: ", failures)
	quit(1 if failures else 0)
