extends SceneTree
var failures := 0
var controller: Node2D
var player: Node2D
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, text: String) -> void:
	print("PASS: " if ok else "FAIL: ", text)
	if not ok:
		failures += 1
func add_wire(points: PackedVector2Array, id: StringName = &"wire") -> Node2D:
	var wire: Node2D = load("res://data/buildings/%s.tres" % id).scene.instantiate()
	wire.route = points
	wire.set_meta("building_id", id)
	controller.get_parent().add_child(wire)
	controller._free_buildings.append(wire)
	controller._refresh_wire_connections()
	return wire
func run() -> void:
	var world = preload("res://tests/playgrounds/resource_playground.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	controller = world.construction
	controller.set_process(false)
	controller.set_physics_process(false)
	player = world.get_node("Player2d")
	player.set_physics_process(false)
	player.position = Vector2(1420, 728)
	var hud = world.get_node("HUD/PlayerHUD")
	hud._select_tool(2)
	check(controller.selected_tool == 2 and hud.tools.item_at_slot(2) == &"wire_cutters", "Cutters are available and selectable without artwork")
	for cells in range(1, 5):
		var short_wire = add_wire(PackedVector2Array([Vector2(1408, 708), Vector2(1408 + cells * 8, 708)]))
		await physics_frame
		check(controller.cut_wire_at(Vector2(1412, 708)), "Click cuts a %d-cell wire" % cells)
		check(short_wire.is_queued_for_deletion(), "Short wire removed")
		await physics_frame
	var original = add_wire(PackedVector2Array([Vector2(1376, 708), Vector2(1472, 708)]))
	var neighbour = add_wire(PackedVector2Array([Vector2(1408, 740), Vector2(1440, 740)]))
	await physics_frame
	controller._update_cut_preview(Vector2(1420, 708))
	check(controller._cut_preview.size() == 2 and controller._cut_preview[0].is_equal_approx(Vector2(1408, 708)) and controller._cut_preview[1].is_equal_approx(Vector2(1440, 708)), "Highlight shows exactly the wire portion inside the selected large cell")
	check(not original.is_queued_for_deletion(), "Preview does not remove the wire")
	check(controller.cut_wire_at(Vector2(1420, 708)), "Long wire can be cut inside one large cell")
	await physics_frame
	check(controller._free_buildings.size() == 3 and is_instance_valid(neighbour), "Adjacent large cell remains untouched")
	var left: Node2D
	var right: Node2D
	for wire in controller._free_buildings:
		if wire.input_point().is_equal_approx(Vector2(1376, 708)):
			left = wire
		if wire.output_point().is_equal_approx(Vector2(1472, 708)):
			right = wire
	check(left != null and left.output_point().is_equal_approx(Vector2(1408, 708)), "Left fragment ends exactly at large-cell border")
	check(right != null and right.input_point().is_equal_approx(Vector2(1440, 708)), "Right fragment begins exactly at next border")
	check(left.connected_outputs.is_empty() and right.connected_inputs.is_empty(), "Cut breaks the connection while retaining direction")
	controller.remove_building(neighbour)
	await physics_frame
	var pipe = add_wire(PackedVector2Array([Vector2(1408, 716), Vector2(1440, 716)]), &"pipe")
	await physics_frame
	check(controller.cut_wire_at(Vector2(1420, 716)) and pipe.is_queued_for_deletion(), "Universal secateur also cuts pipes")

	await physics_frame
	player.position = Vector2(1424, 728)
	controller._last_cut_cursor = Vector2(1392, 708)
	controller._using_tool = true
	var motion := InputEventMouseMotion.new()
	motion.position = controller.get_canvas_transform() * Vector2(1456, 708)
	controller._unhandled_input(motion)
	check(controller._free_buildings.size() == 2, "Dragging without X does not cut more cells")
	var ctrl := InputEventKey.new()
	ctrl.keycode = KEY_X
	ctrl.physical_keycode = KEY_X
	ctrl.pressed = true
	Input.parse_input_event(ctrl)
	Input.flush_buffered_events()
	controller._update_cut_preview(Vector2(1404, 708))
	check(controller._cut_preview.size() == 2 and controller._cut_preview[0].is_equal_approx(Vector2(1400, 708)) and controller._cut_preview[1].is_equal_approx(Vector2(1408, 708)), "X highlights exactly one small cell")
	controller._unhandled_input(motion)
	ctrl = ctrl.duplicate()
	ctrl.pressed = false
	Input.parse_input_event(ctrl)
	Input.flush_buffered_events()
	controller._using_tool = false
	await physics_frame
	check(controller._free_buildings.size() == 2, "X sweep preserves cells outside the traversed area")
	var precise_wire = add_wire(PackedVector2Array([Vector2(1408, 716), Vector2(1440, 716)]))
	await physics_frame
	ctrl = ctrl.duplicate()
	ctrl.pressed = true
	Input.parse_input_event(ctrl)
	Input.flush_buffered_events()
	check(controller.cut_wire_at(Vector2(1420, 716)), "X click deletes a single small cell")
	await physics_frame
	var preserved_left := false
	var preserved_right := false
	for wire in controller._free_buildings:
		if wire.input_point().is_equal_approx(Vector2(1408, 716)) and wire.output_point().is_equal_approx(Vector2(1416, 716)):
			preserved_left = true
		if wire.input_point().is_equal_approx(Vector2(1424, 716)) and wire.output_point().is_equal_approx(Vector2(1440, 716)):
			preserved_right = true
	check(preserved_left and preserved_right, "X removes only eight pixels and preserves both neighbouring portions")
	ctrl = ctrl.duplicate()
	ctrl.pressed = false
	Input.parse_input_event(ctrl)
	Input.flush_buffered_events()
	var far_wire = add_wire(PackedVector2Array([Vector2(1600, 708), Vector2(1632, 708)]))
	await physics_frame
	check(not controller.cut_wire_at(Vector2(1612, 708)), "Cutters respect tool reach")
	player.position = Vector2(1612, 728)
	player.menu_open = true
	controller._update_cut_preview(Vector2(1612, 708))
	check(controller._cut_preview.is_empty(), "No deletion highlight while menu is open")
	check(not controller.cut_wire_at(Vector2(1612, 708)), "Open menu blocks cutters")
	player.menu_open = false
	controller.set_tool(0)
	check(not controller.cut_wire_at(Vector2(1612, 708)), "Other tools do not trigger cutting")
	var separate_wire = add_wire(PackedVector2Array([Vector2(1700, 1004), Vector2(1716, 1004)]), &"wire")
	var separate_pipe = add_wire(PackedVector2Array([Vector2(1716, 1004), Vector2(1732, 1004)]), &"pipe")
	controller._refresh_wire_connections()
	check(separate_wire.connected_outputs.is_empty() and separate_pipe.connected_inputs.is_empty(), "Pipes and wires never connect to each other")
	world.queue_free()
	await process_frame
	print("Cutters failures: ", failures)
	quit(1 if failures else 0)
