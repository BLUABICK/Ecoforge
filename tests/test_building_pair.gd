extends SceneTree
var failures := 0
func _initialize() -> void:
	call_deferred("_run")
func _check(ok: bool, message: String) -> void:
	print("PASS: " if ok else "FAIL: ", message)
	if not ok:
		failures += 1
func _run() -> void:
	var world = preload("res://tests/playgrounds/resource_playground.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	await process_frame
	var menu = world.get_node("HUD/PlayerHUD")._inventory_menu
	var controller = world.construction
	controller.set_process(false)
	menu._select_tab(2)
	await process_frame
	await process_frame
	var grid = menu._building_slots[0].get_parent()
	_check(grid.position.x + grid.size.x <= 500, "Construction grid stays within inventory page")
	for index in 12:
		var slot_index := index + 1
		var definition = menu._catalog[slot_index]
		_check(definition.id == [&"cargo_container", &"terminal", &"trade_terminal", &"delivery_pad", &"technoformer", &"conveyor", &"router", &"junction", &"pipe", &"liquid_pump", &"gas_pump", &"wire"][index], "New building appears in catalog")
		menu._building_slots[slot_index].pressed.emit()
		_check(controller.active and controller.definition == definition, "Catalog starts placement")
		controller.turns = 1
		_check(controller.dimensions() == Vector2i(definition.footprint.y, definition.footprint.x), "Footprint rotates")
		controller.update_preview(Vector2(1400, 350 + (index % 4) * 200))
		_check(controller.confirm(), "Building can be placed")
		_check(controller.active and controller.definition == definition and controller.turns == 1, "Placement keeps selection and rotation after building")
		await physics_frame
		var building = controller._free_buildings.back() if definition.free_placement else controller._occupied.get(controller.cell)
		var expected_size: Vector2 = definition.preview_size if definition.preview_size != Vector2.ZERO else Vector2(definition.footprint * 32)
		_check(is_instance_valid(building) and building.get_node("CollisionShape2D").shape.size.is_equal_approx(expected_size), "Placed object has matching collision")
		controller.begin(definition)
		controller.update_preview(building.position)
		_check(not controller.confirm(), "Occupied location rejects placement")
		controller.cancel()
		if definition.length_axis_snap:
			_check(is_equal_approx(building.position.x, (controller.cell.x + 0.5) * 32) and is_equal_approx(building.position.y, 350 + (index % 4) * 200), "Horizontal pipe snaps length and preserves cursor height")
			controller.begin(definition)
			controller.update_preview(Vector2(1501, 357))
			_check(controller.placement_position.is_equal_approx(Vector2(1501, 368)), "Vertical pipe snaps length and preserves cursor width")
			controller.cancel()
		if definition.free_placement and not definition.length_axis_snap:
			_check(building.position.is_equal_approx(Vector2(1398.4, 348.8) if definition.id == &"pipe" else Vector2(1404, 948)), "Pipe and wire use the same building-specific placement grid")
			controller.begin(definition)
			controller.update_preview(Vector2(1400, 950))
			_check(controller.placement_position.is_equal_approx(Vector2(1398.4, 950.4) if definition.id == &"pipe" else Vector2(1404, 948)), "Vertical wire snaps to building-specific cell grid")
			controller.turns = 1
			var connection_position: Vector2 = building.position + Vector2(32, 0)
			controller.update_preview(connection_position + Vector2(2, 2))
			_check(controller.placement_position.is_equal_approx(connection_position), "New wire snaps to existing wire endpoint")
			controller.update_preview(connection_position + Vector2(10, 0))
			_check(controller.placement_position.is_equal_approx(connection_position), "Wire connects within reduced attraction distance")
			var toggle := InputEventKey.new()
			toggle.physical_keycode = KEY_X
			toggle.pressed = true
			controller._unhandled_key_input(toggle)
			var free_position: Vector2 = connection_position + Vector2(2.3, 1.7)
			controller.update_preview(free_position)
			_check(controller.free_build_mode and controller.placement_position.is_equal_approx(free_position), "X disables grid and wire attraction")
			controller._unhandled_key_input(toggle)
			_check(not controller.free_build_mode and controller.placement_position.is_equal_approx(connection_position), "X restores wire attraction")
			var ctrl := InputEventKey.new()
			ctrl.keycode = KEY_CTRL
			ctrl.physical_keycode = KEY_CTRL
			ctrl.pressed = true
			Input.parse_input_event(ctrl)
			Input.flush_buffered_events()
			controller.update_preview(connection_position + Vector2(0, 8))
			_check(not controller.placement_position.is_equal_approx(connection_position), "Held Ctrl disables attraction")
			ctrl.pressed = false
			Input.parse_input_event(ctrl)
			Input.flush_buffered_events()
			controller.turns = 0
			var elbow_position: Vector2 = building.position + Vector2(20, 12) if definition.id == &"wire" else building.position + Vector2(19.2, 12.8)
			controller.update_preview(elbow_position + Vector2(1, 1))
			_check(controller.turns == 0 and controller.placement_position.is_equal_approx(elbow_position), "Perpendicular section attaches at the free end without rotating")
			_check(controller.confirm(), "End-to-corner connection can be built")
			await physics_frame
			_check(controller._available_ends(building).size() == 1, "Corner connection occupies source endpoint")
			controller.remove_building(controller._free_buildings.back())
			await physics_frame
			controller.turns = 0
			controller.update_preview(connection_position + Vector2(2, 0))
			_check(controller.turns == 1 and controller.placement_position.is_equal_approx(connection_position), "New section aligns with free endpoint direction")
			controller.turns = 1
			controller.update_preview(connection_position)
			_check(controller.confirm(), "Connected wire can be placed without overlap")
			await physics_frame
			_check(controller._available_ends(building).size() == 1, "Occupied endpoint no longer attracts new sections")
			controller.remove_building(controller._free_buildings.back())
			await physics_frame
			controller.turns = 1
			controller.update_preview(building.position + Vector2(0, 8))
			_check(controller.confirm(), "Two non-overlapping wires fit in the same cell")
			await physics_frame
			controller.remove_building(controller._free_buildings.back())
			await physics_frame
		controller.remove_building(building)
		await physics_frame
		_check(not is_instance_valid(building), "Building can be removed")
		controller.begin(definition)
		var free_toggle := InputEventKey.new()
		free_toggle.physical_keycode = KEY_X
		free_toggle.pressed = true
		controller._unhandled_key_input(free_toggle)
		var free_cursor := Vector2(1450.3, 1000.7)
		controller.update_preview(free_cursor)
		_check(controller.free_build_mode and controller.placement_position.is_equal_approx(free_cursor), "X allows free placement for every building")
		_check(controller.confirm(), "Every building can be placed freely")
		await physics_frame
		controller.remove_building(controller._free_buildings.back())
		await physics_frame
		controller._unhandled_key_input(free_toggle)
		controller.cancel()
	world.queue_free()
	await process_frame
	print("Building pair checks finished. Failures: ", failures)
	quit(1 if failures else 0)
