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
	var hotbar = interaction.hotbar
	var tools = interaction.tools
	var chest = world._storage
	tools.transfer_slot_to(bag, 0, 1)
	interaction.interact()
	var menu = hud._storage_menu
	var context = menu._item_context
	_right(menu._bag_slots[0])
	_check(context.popup.get_item_index(1) == -1 and context.popup.get_item_index(2) >= 0 and context.popup.get_item_index(5) >= 0, "Main item offers container and tool inventory")
	context._action(5)
	_check(tools.quantity(&"sledgehammer") == 1 and bag.quantity(&"sledgehammer") == 0, "Context equips main inventory tool")
	_right(menu._tool_slots[0])
	_check(context.popup.get_item_index(5) == -1 and context.popup.get_item_index(1) >= 0 and context.popup.get_item_index(2) >= 0, "Tool item offers main inventory and container")
	context._action(2)
	_right(menu._storage_slots[0])
	_check(context.popup.get_item_index(2) == -1 and context.popup.get_item_index(1) >= 0 and context.popup.get_item_index(5) >= 0, "Container item offers main and tool inventories")
	context._action(5)
	_check(tools.quantity(&"sledgehammer") == 1 and chest.inventory.total() == 0, "Container tool equips correctly")
	bag.add(&"iron_ore", 8)
	_right(menu._bag_slots[0])
	_check(context.popup.is_item_disabled(context.popup.get_item_index(5)), "Tool inventory rejects ordinary resources")
	context.close_all()
	menu.close_menu()
	hud._set_inventory_open(true)
	var inventory_menu = hud._inventory_menu
	await process_frame
	await process_frame
	_check(inventory_menu._inventory_slots.size() == 15 and inventory_menu._hotbar_slots.size() == 5 and inventory_menu._tool_slots.size() == 6, "Inventory shows main, hotbar, tools separately")
	_check(hotbar != bag and hotbar.total() == 0 and hud._slots[0].text == "", "Main items do not automatically appear in hotbar")
	await _drag_gui(inventory_menu._inventory_slots[0].get_global_rect().get_center(), inventory_menu._hotbar_slots[2].get_global_rect().get_center())
	_check(bag.total() == 0 and hotbar.amount_at_slot(2) == 8, "Native drag moves main item into separate hotbar")
	_check("8" in hud._slots[2].text and "8" in inventory_menu._hotbar_slots[2].text and inventory_menu._inventory_slots[0].text == "", "HUD and hotbar row reflect separate data")
	await _drag_gui(inventory_menu._hotbar_slots[2].get_global_rect().get_center(), inventory_menu._inventory_slots[4].get_global_rect().get_center())
	_check(bag.amount_at_slot(4) == 8 and hotbar.total() == 0 and hud._slots[2].text == "", "Return drag clears HUD and restores main inventory")
	for slot in inventory_menu._inventory_slots + inventory_menu._hotbar_slots + inventory_menu._tool_slots:
		_check(is_equal_approx(slot.size.x, slot.size.y) and slot.get_theme_stylebox("normal").border_width_left == 0, "Inventory slot is square without border")
	_right(inventory_menu._inventory_slots[4])
	var main_context = inventory_menu._item_context
	_check(main_context.popup.get_item_index(6) >= 0 and not main_context.popup.is_item_disabled(main_context.popup.get_item_index(6)), "Move to hotbar action is available")
	main_context._action(6)
	_check(bag.total() == 0 and hotbar.total() == 8 and "8" in hud._slots[0].text, "Context moves stack to hotbar and updates HUD")
	_right(inventory_menu._hotbar_slots[0])
	_check(main_context.popup.get_item_index(6) == -1, "Hotbar items do not offer redundant hotbar action")
	main_context._action(1)
	_check(hotbar.total() == 0 and bag.total() == 8, "Context returns hotbar stack to main inventory")
	bag.transfer_slot_to(hotbar, 0, 3, 1)
	if "--capture" in OS.get_cmdline_user_args():
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("C:/Users/admin/Documents/Codex/2026-10-22/https-chatgpt-com-s-cx-6ada58e0c59c819191b4f8cbdfe30cc4/work/inventory-hotbar.png")
	hud._set_inventory_open(false)
	interaction._cooldown = 0
	interaction.interact()
	await process_frame
	await process_frame
	_check(menu._hotbar_slots.size() == 5 and "3" in menu._hotbar_slots[1].text, "Storage also shows separate hotbar")
	menu._slot_drop(Vector2.ZERO, {"menu": menu, "side": 3, "index": 1, "item": &"iron_ore"}, 2, 8)
	_check(hotbar.total() == 0 and chest.inventory.amount_at_slot(8) == 3, "Hotbar item can be stored via drag")
	for slot in menu._bag_slots + menu._hotbar_slots + menu._tool_slots + menu._storage_slots:
		_check(is_equal_approx(slot.size.x, slot.size.y) and slot.get_theme_stylebox("normal").border_width_left == 0, "Container slot is square without border")
	if "--capture" in OS.get_cmdline_user_args():
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("C:/Users/admin/Documents/Codex/2026-10-22/https-chatgpt-com-s-cx-6ada58e0c59c819191b4f8cbdfe30cc4/work/storage-hotbar.png")
	menu.close_menu()
	world.queue_free()
	await process_frame
	print("Inventory sections checks finished. Failures: ", failures)
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



