extends SceneTree
var failures := 0
func _initialize() -> void:
	call_deferred("_run")
func check(ok: bool, message: String) -> void:
	print("PASS: " if ok else "FAIL: ", message)
	if not ok:
		failures += 1
func _run() -> void:
	var world = preload("res://tests/playgrounds/resource_playground.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	var controller = world.construction
	controller.set_process(false)
	var source = preload("res://data/buildings/wire.tres")
	for index in 2:
		var wire = source.scene.instantiate()
		wire.position = Vector2(1400, 700) if index == 0 else Vector2(1432, 668)
		wire.rotation = 0 if index == 0 else PI / 2
		wire.set_meta("building_id", &"wire")
		world.add_child(wire)
		controller._free_buildings.append(wire)
	await physics_frame
	controller.begin(source)
	controller.update_preview(Vector2(1401, 677))
	check(controller._wire_route.size() == 3, "Preview bends to connect two offset wires")
	check(controller.can_place and controller.confirm(), "Bent bridge can be placed")
	await physics_frame
	var bridge = controller._free_buildings.back()
	check(bridge.route.size() == 3 and bridge.get_child_count() == 3, "Placed bridge has line and collision on both segments")
	check(bridge.connection_ends()[0].point.is_equal_approx(Vector2(1400, 684)) and bridge.connection_ends()[1].point.is_equal_approx(Vector2(1416, 668)), "Bridge touches both wire ends")
	controller.free_build_mode = true
	controller.update_preview(Vector2(1401, 677))
	check(controller._wire_route.is_empty(), "Free placement disables bending")
	world.queue_free()
	await process_frame
	print("Wire bridge checks finished. Failures: ", failures)
	quit(1 if failures else 0)
