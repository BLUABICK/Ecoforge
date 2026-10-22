extends SceneTree

const Inventory = preload("res://scenes/player/inventory.gd")
var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var bag := Inventory.new()
	bag.slot_limit = 5
	for index in 5:
		bag.add(StringName("item_%d" % index), 1)
	_check(bag.add(&"sixth", 1) == 0 and bag.total() == 5, "Five distinct items maximum")
	_check(bag.add(&"item_0", 2) == 2, "Existing stack can grow")
	bag.remove(&"item_1", 1)
	_check(bag.item_at_slot(1) == &"" and bag.item_at_slot(2) == &"item_2", "Removing item preserves other slots")
	bag.add(&"replacement", 1)
	_check(bag.item_at_slot(1) == &"replacement", "New item fills empty slot")
	var world := preload("res://tests/playgrounds/resource_playground.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	var player := world.get_node("Player2d")
	player.set_physics_process(false)
	var vitals := player.get_node("Vitals")
	_check(vitals.health == 100.0 and vitals.stamina == 100.0, "Vitals start full")
	vitals.update_sprint(1.0, true, true)
	_check(vitals.stamina == 80.0, "Running consumes stamina")
	vitals.update_sprint(0.5, false, true)
	_check(vitals.stamina == 80.0, "Standing with Ctrl does not consume stamina")
	vitals.update_sprint(1.0, false, false)
	_check(vitals.stamina > 80.0, "Stamina recovers after delay")
	vitals.update_sprint(10.0, true, true)
	_check(vitals.stamina == 0.0 and vitals.exhausted, "Exhaustion stops running")
	_check(not vitals.update_sprint(0.8, true, true), "Held Ctrl does not cause sprint flicker")
	vitals.update_sprint(3.0, false, false)
	_check(not vitals.exhausted and vitals.stamina > 25.0, "Recovery unlocks running")
	vitals.take_damage(-10)
	_check(vitals.health == 100.0, "Negative damage ignored")
	vitals.take_damage(30)
	_check(vitals.health == 70.0, "Damage reduces HP")
	vitals.heal(1000)
	_check(vitals.health == 100.0, "Healing capped at maximum")
	vitals.take_damage(1000)
	_check(vitals.health == 0.0 and not vitals.update_sprint(1.0, true, true), "Zero HP prevents running")
	vitals.health = 100.0
	vitals.stamina = 72.0
	vitals.changed.emit()
	var hud := world.get_node("HUD/PlayerHUD")
	_check(hud._slots.size() == 5, "HUD has five slots")
	hud._select(4)
	_check(hud.selected_slot == 4, "Slot selection updates HUD")
	hud._toggle_tools()
	_check(hud._tool_panel.visible, "Tools button opens separate panel")
	hud._select_tool(2)
	_check(hud.selected_tool == 2 and not hud._tool_panel.visible, "Empty tool slot can be selected")
	hud._toggle_tools()
	_check(hud._tool_panel.visible and hud._tool_slots.size() == 6, "Six tool choices reopen")
	hud._tool_slots[1].pressed.emit()
	_check(hud.selected_tool == 1, "Clicking tool slot changes selection")
	var selected_style := hud._tool_slots[1].get_theme_stylebox("normal") as StyleBoxFlat
	_check(selected_style.border_width_left == 0 and hud._tool_slots[0].get_theme_stylebox("normal").border_width_left == 0 and selected_style.bg_color != hud._tool_slots[0].get_theme_stylebox("normal").bg_color, "Selected tool uses background emphasis without borders")
	_check(hud._stamina_bar.size.y < hud._health_bar.size.y and hud._stamina_bar.position.y < hud._health_bar.position.y, "Stamina is thinner and above HP")
	hud._toggle_tools()
	_check(get_nodes_in_group("interactables").size() == 1, "No surface ores in playground")
	await process_frame
	await process_frame
	_check(hud._tool_slots[0].position.y > hud._tool_slots[5].position.y and is_equal_approx(hud._tool_slots[0].position.x, hud._tool_slots[5].position.x), "Tool choices extend vertically upwards")
	hud._select(4)
	hud._select_tool(5)
	var key := InputEventKey.new()
	key.physical_keycode = KEY_Q
	key.keycode = KEY_Q
	key.pressed = true
	Input.parse_input_event(key)
	Input.flush_buffered_events()
	key = key.duplicate()
	key.pressed = false
	Input.parse_input_event(key)
	Input.flush_buffered_events()
	_check(hud.selected_tool == 0 and hud.selected_slot == 4, "Q cycles tools and preserves hotbar selection")
	var wheel := InputEventMouseButton.new()
	wheel.pressed = true
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	Input.parse_input_event(wheel)
	Input.flush_buffered_events()
	_check(hud.selected_slot == 0 and hud.selected_tool == 0, "Wheel wraps five hotbar slots without selecting tools")
	wheel = wheel.duplicate()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	Input.parse_input_event(wheel)
	Input.flush_buffered_events()
	_check(hud.selected_slot == 4, "Reverse wheel wraps to fifth slot")
	hud._set_inventory_open(true)
	wheel = wheel.duplicate()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	Input.parse_input_event(wheel)
	Input.flush_buffered_events()
	_check(hud.selected_slot == 4, "Inventory menu blocks hotbar scrolling")
	hud._set_inventory_open(false)
	hud._tool_panel.show()
	print("HUD and vitals checks finished. Failures: ", failures)
	if "--capture" in OS.get_cmdline_user_args():
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("C:/Users/admin/Documents/Codex/2026-10-21/new-chat/work/hud-preview.png")
	world.queue_free()
	await process_frame
	quit(1 if failures else 0)


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error(description)






