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
	var player = world.get_node("Player2d")
	player.position = world._storage.position + Vector2(0, -40)
	await physics_frame
	await physics_frame
	var interaction = player.get_node("Interaction")
	var hud = world.get_node("HUD/PlayerHUD")
	var bag = interaction.inventory
	var tools = interaction.tools
	var chest = world._storage
	bag.add(&"iron_ore", 8)
	interaction.interact()
	var menu = hud._storage_menu
	var context = menu._item_context
	_right(menu._bag_slots[0])
	_check(context.popup.visible and context.popup.get_item_index(3) >= 0, "Right click opens actions with Split for stack")
	_check(context.popup.get_item_index(1) == -1 and not context.popup.is_item_disabled(context.popup.get_item_index(2)), "Current inventory omitted, container enabled")
	_check(context.popup.is_item_disabled(context.popup.get_item_index(4)), "Discard is disabled")
	context._action(4)
	_check(bag.total() == 8, "Discard placeholder never removes item")
	context._action(0)
	_check(context.info.visible and context.info.title == "Железная руда" and "8" in context.info.dialog_text, "Information shows item name and stack amount")
	context.info.hide()
	context._action(3)
	_check(context.split_dialog.visible and context.split_slider.max_value == 7, "Split selects up to stack minus one")
	context.split_slider.value = 3
	context.split_dialog.confirmed.emit()
	context.split_dialog.hide()
	_check(bag.amount_at_slot(0) == 5 and bag.amount_at_slot(1) == 3 and bag.total() == 8 and chest.inventory.total() == 0, "Split creates second stack in source inventory")
	context.open_for(bag, 1, bag, chest.inventory)
	context._action(2)
	_check(chest.inventory.total() == 3 and bag.total() == 5, "Menu sends selected stack to container")
	context.open_for(chest.inventory, 0, bag, chest.inventory)
	context._action(1)
	_check(bag.total() == 8 and chest.inventory.total() == 0, "Menu sends stack to main inventory")
	context.open_for(tools, 0, bag, chest.inventory)
	_check(context.popup.get_item_index(3) == -1, "Tools have no split action")
	context._action(1)
	_check(bag.quantity(&"sledgehammer") == 1 and tools.quantity(&"sledgehammer") == 0 and world.construction.selected_tool == -1, "Tool can be moved to main inventory and is unequipped")
	context.open_for(bag, 1, bag, chest.inventory)
	_check(context.popup.get_item_index(3) == -1, "Single item has no split action")
	context.close_all()
	menu.close_menu()
	hud._set_inventory_open(true)
	var inventory_menu = hud._inventory_menu
	_right(inventory_menu._inventory_slots[0])
	context = inventory_menu._item_context
	_check(context.popup.visible and context.popup.is_item_disabled(context.popup.get_item_index(2)), "Regular inventory supports actions with no remote container access")
	context._action(3)
	context.split_slider.value = 2
	context.split_dialog.confirmed.emit()
	context.split_dialog.hide()
	_check(bag.amount_at_slot(0) == 6 and bag.amount_at_slot(2) == 2, "Split works in regular inventory")
	bag.slot_limit = bag._slots.size()
	context.open_for(bag, 0, bag)
	_check(context.popup.is_item_disabled(context.popup.get_item_index(3)), "Split disabled when no free cells")
	bag.slot_limit = 15
	context.close_all()
	hud._set_inventory_open(false)
	_right(hud._tool_slots[1])
	_check(hud._item_context.popup.visible, "Tool slots also support context actions")
	hud._item_context.close_all()
	hud._set_inventory_open(true)
	context.open_for(bag, 0, bag)
	if "--capture" in OS.get_cmdline_user_args():
		context.close_all()
		await process_frame
		await process_frame
		var point: Vector2 = inventory_menu._inventory_slots[0].get_global_rect().get_center()
		var motion := InputEventMouseMotion.new()
		motion.position = point
		Input.parse_input_event(motion)
		Input.flush_buffered_events()
		var press := InputEventMouseButton.new()
		press.position = point
		press.button_index = MOUSE_BUTTON_RIGHT
		press.pressed = true
		Input.parse_input_event(press)
		Input.flush_buffered_events()
		await process_frame
		press = press.duplicate()
		press.pressed = false
		Input.parse_input_event(press)
		Input.flush_buffered_events()
		await process_frame
		await process_frame
		_check(context.popup.visible, "Real mouse right click keeps context menu open")
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("C:/Users/admin/Documents/Codex/2026-10-22/https-chatgpt-com-s-cx-6ada58e0c59c819191b4f8cbdfe30cc4/work/context-preview.png")
	hud._set_inventory_open(false)
	_check(not context.popup.visible and not context.split_dialog.visible and not context.info.visible, "Closing inventory hides its popups")
	world.queue_free()
	await process_frame
	print("Item context checks finished. Failures: ", failures)
	quit(1 if failures else 0)
func _right(button: Control) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_RIGHT
	event.pressed = true
	button.gui_input.emit(event)
func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error(description)




