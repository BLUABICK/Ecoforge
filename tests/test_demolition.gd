extends SceneTree
var failures := 0
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	root.size = Vector2i(1152, 720)
	var world = preload("res://tests/playgrounds/resource_playground.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	await process_frame
	var controller = world.construction
	controller.set_physics_process(false)
	controller.set_process(false)
	var player = world.get_node("Player2d")
	player.set_physics_process(false)
	var hud = world.get_node("HUD/PlayerHUD")
	var source = preload("res://tests/fixtures/test_building.tres")
	controller.begin(source)
	controller.update_preview(Vector2(900, 400))
	_check(controller.confirm(), "Place demolition fixture")
	await physics_frame
	await physics_frame
	var building = get_nodes_in_group("buildings")[0]
	var cursor: Vector2 = building.global_position
	controller.advance_demolition(4.0, cursor, true)
	_check(not building.is_queued_for_deletion(), "Cannot demolish remotely")
	player.position = Vector2(870, 416)
	await physics_frame
	await physics_frame
	hud._select_tool(1)
	_check(controller.selected_tool == 1 and hud._tools_button.icon == preload("res://assets/sprites/screwdriver.png"), "Named screwdriver selected")
	controller.advance_demolition(0.7, cursor, true)
	_check(not building.is_queued_for_deletion() and controller._demolition_elapsed > 0.0, "Screwdriver needs longer than hammer")
	controller.advance_demolition(0.0, cursor, false)
	_check(controller._demolition_elapsed == 0.0, "Release resets progress")
	hud._set_inventory_open(true)
	controller.advance_demolition(4.0, cursor, true)
	_check(not building.is_queued_for_deletion(), "Inventory blocks demolition")
	hud._set_inventory_open(false)
	world._add_wall(Rect2(890, 390, 3, 60))
	var wall = world.get_child(world.get_child_count() - 1)
	await physics_frame
	await physics_frame
	controller.advance_demolition(4.0, cursor, true)
	_check(not building.is_queued_for_deletion() and controller._demolition_elapsed == 0.0, "Wall blocks tool")
	wall.queue_free()
	await physics_frame
	await physics_frame
	controller.advance_demolition(2.9, cursor, true)
	_check(not building.is_queued_for_deletion(), "Screwdriver remains unfinished before three seconds")
	controller.advance_demolition(0.11, cursor, true)
	_check(building.is_queued_for_deletion() and controller._occupied.is_empty(), "Screwdriver removes building and frees grid")
	await physics_frame
	await physics_frame
	controller.begin(source)
	controller.update_preview(Vector2(900, 400))
	_check(controller.confirm(), "Freed cells can be built on again")
	await physics_frame
	await physics_frame
	building = get_nodes_in_group("buildings")[0]
	hud._select_tool(0)
	_check(hud._tools_button.icon == preload("res://assets/sprites/sledge.png"), "Named hammer selected")
	controller.advance_demolition(0.59, cursor, true)
	_check(not building.is_queued_for_deletion(), "Hammer takes time")
	controller.advance_demolition(0.02, cursor, true)
	_check(building.is_queued_for_deletion(), "Hammer demolishes in 0.6 seconds")
	world.queue_free()
	await process_frame
	print("Demolition checks finished. Failures: ", failures)
	quit(1 if failures else 0)
func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error(description)

