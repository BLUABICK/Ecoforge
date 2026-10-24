extends SceneTree
const Inventory = preload("res://scenes/player/inventory.gd")
var failures := 0
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var bag = Inventory.new()
	bag.slot_limit = 4
	_check(bag.add(&"sledgehammer", 3) == 3, "Multiple hammers accepted as separate items")
	_check(bag.amount_at_slot(0) == 1 and bag.amount_at_slot(1) == 1 and bag.amount_at_slot(2) == 1, "Each tool occupies its own slot")
	var destination = Inventory.new()
	destination.slot_limit = 2
	_check(bag.transfer_slot_to(destination, 1, 99, 0) == 1 and bag.quantity(&"sledgehammer") == 2, "Moving one tool leaves other copies intact")
	_check(bag.transfer_slot_to(destination, 0, 1, 0) == 0, "Tools cannot merge")
	_check(bag.transfer_slot_to(destination, 0, 1, 1) == 1 and destination.amount_at_slot(1) == 1, "Duplicate tool moves into another slot")
	_check(destination.add(&"sledgehammer", 1) == 0, "Full tool slots do not stack copies")
	bag = Inventory.new()
	bag.slot_limit = 5
	bag.capacity = 10
	bag.add(&"iron_ore", 10)
	_check(bag.transfer_slot_to(bag, 0, 4, 3) == 4 and bag.amount_at_slot(0) == 6 and bag.amount_at_slot(3) == 4 and bag.total() == 10, "Split and reorder works in a full inventory")
	_check(bag.transfer_slot_to(bag, 3, 4, 0) == 4 and bag.amount_at_slot(0) == 10 and bag.item_at_slot(3) == &"", "Stack merging conserves items")
	destination = Inventory.new()
	destination.capacity = 2
	_check(bag.transfer_slot_to(destination, 0, 7, 0) == 2 and bag.total() == 8, "Partial transfer respects capacity without loss")

	root.size = Vector2i(1152, 720)
	var world = preload("res://tests/playgrounds/resource_playground.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	await process_frame
	var player = world.get_node("Player2d")
	player.position = world._storage.position + Vector2(0, -40)
	await physics_frame
	await physics_frame
	var interaction = player.get_node("Interaction")
	var hud = world.get_node("HUD/PlayerHUD")
	var menu = hud._storage_menu
	var chest = world._storage
	bag = interaction.inventory
	bag.add(&"iron_ore", 10)
	interaction.interact()
	_check(menu.visible, "Open transfer menu")
	_click(menu._bag_slots[0], MOUSE_BUTTON_LEFT)
	_click(menu._bag_slots[0], MOUSE_BUTTON_RIGHT)
	_check(bag.total() == 10 and chest.inventory.total() == 0, "Plain clicks do not quick-transfer")
	_check(menu._item_context.popup.visible, "Plain right click opens item actions")
	menu._item_context.close_all()
	_click(menu._bag_slots[0], MOUSE_BUTTON_RIGHT, true)
	_check(bag.total() == 9 and chest.inventory.total() == 1, "Shift right click moves one")
	_click(menu._bag_slots[0], MOUSE_BUTTON_RIGHT, false, true)
	_check(menu._quantity_dialog.visible and menu._quantity_slider.max_value == 9, "Ctrl right click opens quantity slider")
	menu._quantity_slider.value = 4
	_check(bag.total() == 9 and chest.inventory.total() == 1, "Moving slider does not transfer yet")
	menu._quantity_dialog.confirmed.emit()
	menu._quantity_dialog.hide()
	_check(bag.total() == 5 and chest.inventory.total() == 5, "Confirm transfers selected amount")
	_click(menu._bag_slots[0], MOUSE_BUTTON_RIGHT, false, true)
	menu._quantity_slider.value = 3
	menu._quantity_dialog.hide()
	_check(bag.total() == 5, "Cancel preserves stack")
	_click(menu._tool_slots[0], MOUSE_BUTTON_RIGHT, false, true)
	_check(not menu._quantity_dialog.visible, "Tools never show quantity dialog")
	var drag := {"menu": menu, "side": 0, "index": 0, "item": &"iron_ore"}
	_check(menu._slot_can_drop(Vector2.ZERO, drag, 2, 6), "Empty target cell accepts drag")
	menu._slot_drop(Vector2.ZERO, drag, 2, 6)
	_check(bag.total() == 0 and chest.inventory.item_at_slot(6) == &"iron_ore" and chest.inventory.amount_at_slot(6) == 5, "Drop moves stack into chosen cell")
	_check(not menu._slot_can_drop(Vector2.ZERO, drag, 2, 7), "Stale drag cannot duplicate moved stack")
	drag = {"menu": menu, "side": 2, "index": 6, "item": &"iron_ore"}
	_check(not menu._slot_can_drop(Vector2.ZERO, drag, 1, 3), "Resource cannot be dropped into tool belt")
	menu._slot_drop(Vector2.ZERO, drag, 2, 0)
	_check(chest.inventory.amount_at_slot(0) == 10 and chest.inventory.item_at_slot(6) == &"", "Drag merges compatible stacks")
	_click(menu._storage_slots[0], MOUSE_BUTTON_LEFT, true)
	_check(bag.total() == 10 and chest.inventory.total() == 0, "Shift left click moves entire stack back")
	drag = {"menu": menu, "side": 1, "index": 0, "item": &"sledgehammer"}
	menu._slot_drop(Vector2.ZERO, drag, 2, 8)
	_check(chest.inventory.amount_at_slot(8) == 1 and world.construction.selected_tool == -1, "Dragged equipped tool becomes unavailable")
	menu._slot_drop(Vector2.ZERO, {"menu": menu, "side": 2, "index": 8, "item": &"sledgehammer"}, 1, 4)
	hud._select_tool(4)
	_check(world.construction.selected_tool == 0 and interaction.tools.item_at_slot(4) == &"sledgehammer", "Tool works from its new belt slot")
	await process_frame
	await process_frame
	var start_point: Vector2 = menu._bag_slots[0].get_global_rect().get_center()
	var end_point: Vector2 = menu._storage_slots[4].get_global_rect().get_center()
	await _drag_gui(start_point, end_point)
	_check(bag.total() == 0 and chest.inventory.amount_at_slot(4) == 10, "Real GUI drag dispatches forwarded drop")
	await _drag_gui(end_point, start_point)
	_check(bag.total() == 10 and chest.inventory.total() == 0, "GUI drag returns stack")
	await _drag_gui(start_point, Vector2(10, 400))
	_check(bag.total() == 10 and chest.inventory.total() == 0, "Dropping outside slots cancels without loss")
	if "--capture" in OS.get_cmdline_user_args():
		menu.show_quantity(0, 0)
		menu._quantity_slider.value = 6
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("C:/Users/admin/Documents/Codex/2026-10-22/https-chatgpt-com-s-cx-6ada58e0c59c819191b4f8cbdfe30cc4/work/quantity-preview.png")
	menu.close_menu()
	_check(not menu._quantity_dialog.visible, "Closing menu also closes slider")
	world.queue_free()
	await process_frame
	print("Transfer controls checks finished. Failures: ", failures)
	quit(1 if failures else 0)
func _click(button: Control, code: MouseButton, shift: bool = false, ctrl: bool = false) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = code
	event.pressed = true
	event.shift_pressed = shift
	event.ctrl_pressed = ctrl
	button.gui_input.emit(event)
func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error(description)

func _drag_gui(from: Vector2, to: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = from
	Input.parse_input_event(motion)
	Input.flush_buffered_events()
	await process_frame
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = from
	Input.parse_input_event(press)
	Input.flush_buffered_events()
	await process_frame
	motion = InputEventMouseMotion.new()
	motion.position = from + Vector2(16, 0)
	motion.relative = Vector2(16, 0)
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(motion)
	Input.flush_buffered_events()
	await process_frame
	motion = InputEventMouseMotion.new()
	motion.position = to
	motion.relative = to - from - Vector2(16, 0)
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(motion)
	Input.flush_buffered_events()
	await process_frame
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.position = to
	release.pressed = false
	Input.parse_input_event(release)
	Input.flush_buffered_events()
	await process_frame

