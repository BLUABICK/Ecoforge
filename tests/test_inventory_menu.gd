extends SceneTree

var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := preload("res://tests/playgrounds/resource_playground.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	var player := world.get_node("Player2d")
	var hud := world.get_node("HUD/PlayerHUD")
	var menu: Control = hud._inventory_menu
	_check(not menu.visible and menu._inventory_slots.size() == 15, "Menu starts closed with 15 slots")
	_key(KEY_TAB)
	await process_frame
	_check(menu.visible and player.menu_open and player.get_node("Interaction").input_blocked, "Tab opens menu and blocks world actions")
	var start: Vector2 = player.position
	Input.action_press("move_right")
	Input.action_press("sprint")
	for index in 5:
		await physics_frame
	_check(player.position.is_equal_approx(start), "Movement is blocked while menu open")
	Input.action_release("move_right")
	Input.action_release("sprint")
	for index in 3:
		menu._tabs[index].pressed.emit()
		_check(menu.active_tab == index and menu._pages[index].visible, "Tab %d switches page" % index)
		var visible_count: int = 0
		for page in menu._pages:
			visible_count += int(page.visible)
		_check(visible_count == 1, "Only one inventory page visible")
	_check(menu._equipment_slots.size() == 10, "Equipment page has ten square slots")
	for index in 10:
		for other in range(index + 1, 10):
			_check(not menu._equipment_slots[index].get_rect().intersects(menu._equipment_slots[other].get_rect()), "Equipment slots do not overlap")
	menu._select_tab(0)
	_check(player.get_node("Interaction").inventory.slot_limit == 15, "Inventory has 15 real slots")
	menu._inventory_slots[3].pressed.emit()
	_check(hud.selected_slot == 0, "Main inventory selection is separate from hotbar")
	menu._hotbar_slots[3].pressed.emit()
	_check(hud.selected_slot == 3, "Dedicated hotbar row selects HUD slot")
	for index in 15:
		player.get_node("Interaction").inventory.add(StringName("sample_%d" % index), 1)
	_check(player.get_node("Interaction").inventory.item_at_slot(14) == &"sample_14", "Last row is backed by inventory")
	_check(player.get_node("Interaction").inventory.add(&"overflow", 1) == 0, "Sixteenth item type rejected")
	_key(KEY_TAB)
	await process_frame
	_check(not menu.visible and not player.menu_open, "Tab closes menu and restores input")
	_key(KEY_TAB)
	await process_frame
	_key(KEY_ESCAPE)
	await process_frame
	_check(not menu.visible and not player.menu_open, "Escape closes menu")
	hud._set_inventory_open(true)
	menu._select_tab(1)
	print("Inventory menu checks finished. Failures: ", failures)
	if "--capture" in OS.get_cmdline_user_args():
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("C:/Users/admin/Documents/Codex/2026-10-21/new-chat/work/inventory-menu-preview.png")
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




