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
	var interaction = player.get_node("Interaction")
	var hud = world.get_node("HUD/PlayerHUD")
	var menu = hud._inventory_menu
	var bag = interaction.inventory
	var hotbar = interaction.hotbar
	bag.add(&"iron_ore", 10)
	hud._set_inventory_open(true)
	await process_frame
	await process_frame
	var anchor: Vector2 = menu._hotbar_slots[0].global_position
	_click(menu._inventory_slots[0], MOUSE_BUTTON_RIGHT, true)
	_check(bag.total() == 9 and hotbar.total() == 1, "Inventory Shift right click moves one to hotbar")
	_click(menu._hotbar_slots[0], MOUSE_BUTTON_LEFT, true)
	_check(bag.total() == 10 and hotbar.total() == 0, "Hotbar Shift left click returns full stack")
	_click(menu._inventory_slots[0], MOUSE_BUTTON_RIGHT, false, true)
	_check(menu._quantity_dialog.visible and menu._quantity_slider.max_value == 10, "Inventory Ctrl right click opens quantity selector")
	menu._quantity_slider.value = 4
	menu._quantity_dialog.confirmed.emit()
	menu._quantity_dialog.hide()
	_check(bag.total() == 6 and hotbar.total() == 4, "Selected amount moves into hotbar")
	_click(menu._hotbar_slots[0], MOUSE_BUTTON_RIGHT, false, true)
	menu._quantity_slider.value = 2
	menu._quantity_dialog.confirmed.emit()
	menu._quantity_dialog.hide()
	_check(bag.total() == 8 and hotbar.total() == 2, "Hotbar quantity selector returns exact amount")
	_click(menu._tool_slots[0], MOUSE_BUTTON_RIGHT, false, true)
	_check(not menu._quantity_dialog.visible, "Tool has no quantity selector")
	for tab in [1, 2, 0]:
		menu._select_tab(tab)
		await process_frame
		_check(menu._hotbar_slots[0].is_visible_in_tree() and menu._hotbar_slots[0].global_position == anchor, "Hotbar stays visible and fixed on tab %d" % tab)
		_check(menu._hotbar_slots[0].global_position.y > menu._pages[tab].global_position.y + menu._pages[tab].size.y, "Hotbar stays below current page")
	menu._select_tab(1)
	_click(menu._hotbar_slots[0], MOUSE_BUTTON_RIGHT, true)
	_check(bag.total() == 9 and hotbar.total() == 1, "Quick transfer works from equipment tab hotbar")
	var drag := {"menu": menu, "side": 1, "index": 0, "item": &"iron_ore"}
	_check(menu._can_drop_slot(Vector2.ZERO, drag, 1, 3), "Equipment tab allows hotbar drag")
	menu._drop_slot(Vector2.ZERO, drag, 1, 3)
	_check(hotbar.amount_at_slot(3) == 1 and hotbar.item_at_slot(0) == &"", "Equipment tab hotbar can be reordered")
	_check(not menu._can_drop_slot(Vector2.ZERO, {"menu": menu, "side": 0, "index": 0, "item": &"iron_ore"}, 1, 1), "Hidden main inventory cannot be dragged")
	if "--capture" in OS.get_cmdline_user_args():
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("C:/Users/admin/Documents/Codex/2026-10-22/https-chatgpt-com-s-cx-6ada58e0c59c819191b4f8cbdfe30cc4/work/equipment-hotbar.png")
	menu._select_tab(0)
	menu.show_quantity(0, 0)
	hud._set_inventory_open(false)
	_check(not menu._quantity_dialog.visible, "Closing inventory closes quantity dialog")
	world.queue_free()
	await process_frame
	print("Inventory shortcuts checks finished. Failures: ", failures)
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
