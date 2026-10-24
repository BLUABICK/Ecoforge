extends SceneTree

var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1152, 720)
	var world := preload("res://tests/playgrounds/resource_playground.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	await process_frame
	await process_frame
	var hud := world.get_node("HUD/PlayerHUD")
	var controller: Node2D = world.construction
	var player := world.get_node("Player2d")
	var menu: Control = hud._inventory_menu
	_key(KEY_Z)
	_check(menu.visible and menu.active_tab == 2 and menu._tabs[2].text == "Строительство", "Z opens construction tab")
	menu._building_slots[1].pressed.emit()
	_check(controller.active and not menu.visible and not player.menu_open, "Choosing building starts placement")
	_check(player.get_node("Interaction").input_blocked, "Placement blocks world interactions")
	controller.set_process(false)
	controller.update_preview(Vector2(900, 400))
	_check(controller.cell == Vector2i(28, 12) and controller.can_place, "Preview snaps to grid")
	_key(KEY_R)
	_check(controller.turns == 1 and controller.dimensions() == Vector2i(2, 3), "R rotates footprint")
	_mouse(MOUSE_BUTTON_LEFT, Vector2(900, 400), controller)
	_check(controller.active and get_nodes_in_group("buildings").size() == 1, "Left click places building and keeps placement active")
	_check(player.get_node("Interaction").input_blocked, "Repeated placement keeps world interaction blocked")
	if get_nodes_in_group("buildings").is_empty():
		print("Viewport: ", root.size, " cursor test: ", controller.get_canvas_transform() * Vector2(900, 400))
		world.queue_free()
		quit(1)
		return
	var building: Node2D = get_nodes_in_group("buildings")[0]
	_check(is_equal_approx(building.rotation, PI / 2.0), "Placed building retains rotation")
	var source := preload("res://data/buildings/cargo_container.tres")
	controller.begin(source)
	controller.update_preview(Vector2(900, 400))
	_check(not controller.confirm() and get_nodes_in_group("buildings").size() == 1, "Cannot overlap existing building")
	controller.update_preview(Vector2(650, 400))
	_check(not controller.can_place, "Obstacle blocks placement")
	controller.update_preview(player.global_position)
	_check(not controller.can_place, "Player blocks placement")
	controller.update_preview(Vector2(1910, 1270))
	_check(not controller.can_place, "Map boundary blocks placement")
	_mouse(MOUSE_BUTTON_RIGHT, Vector2(900, 400), controller)
	_check(not controller.active and get_nodes_in_group("buildings").size() == 1, "Right click cancels without placing")
	controller.begin(source)
	hud._set_inventory_open(true)
	_check(not controller.active and player.menu_open, "Inventory opening cancels placement")
	hud._set_inventory_open(false)
	controller.begin(source)
	controller.update_preview(Vector2(800, 600))
	controller.begin(preload("res://data/buildings/small_container.tres"))
	controller.update_preview(Vector2(1400, 700))
	_check(controller.confirm(), "Small container can be built from catalog")
	await physics_frame
	var container = controller._occupied[Vector2i(43, 21)]
	_check(container.inventory.capacity == 25 and container.inventory.slot_limit == 25, "Built container has 25 capacity and slots")
	controller.cancel()
	var interaction = player.get_node("Interaction")
	player.global_position = container.global_position + Vector2(0, -40)
	await physics_frame
	await physics_frame
	controller.advance_construction(10.0)
	interaction._cooldown = 0.0
	interaction.interact()
	_check(hud._storage_menu.visible and hud._storage_menu.storage == container and hud._storage_menu._storage_slots.size() == 25, "Built container opens its 25-slot inventory")
	hud._storage_menu.close_menu()
	print("Construction checks finished. Failures: ", failures)
	if "--capture" in OS.get_cmdline_user_args():
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("C:/Users/admin/Documents/Codex/2026-10-21/new-chat/work/building-preview.png")
	world.queue_free()
	await process_frame
	quit(1 if failures else 0)


func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error(description)


func _mouse(button: MouseButton, world_position: Vector2, controller: Node2D) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.position = controller.get_canvas_transform() * world_position
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	Input.flush_buffered_events()
