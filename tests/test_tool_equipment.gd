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
	hud._set_inventory_open(true)
	await process_frame
	_check(menu._tool_slots.size() == 6, "Exactly six equipment tool slots")
	for slot in menu._tool_slots:
		_check(not slot.is_visible_in_tree() and slot.get_parent() == menu._pages[1], "Tool slot belongs only to equipment page")
	menu._select_tab(1)
	await process_frame
	_check(menu._tool_slots[0].icon == preload("res://assets/sprites/sledge.png") and menu._tool_slots[1].icon == preload("res://assets/sprites/screwdriver.png"), "New tool art appears in equipment")
	for index in 6:
		_check(menu._tool_slots[index] == menu._equipment_slots[index] and menu._tool_slots[index].is_visible_in_tree(), "Side equipment square is a functional tool slot")
	_check(menu._tool_slots[0].position.x == menu._tool_slots[2].position.x and menu._tool_slots[3].position.x == menu._tool_slots[5].position.x and menu._tool_slots[0].position.x < menu._tool_slots[3].position.x, "Three tool slots on each side")
	menu._tool_slots[1].pressed.emit()
	_check(hud.selected_tool == 1 and world.construction.selected_tool == 1 and hud._tools_button.icon == preload("res://assets/sprites/screwdriver.png"), "Equipment click selects active tool and HUD icon")
	var start: Vector2 = menu._tool_slots[0].get_global_rect().get_center()
	var finish: Vector2 = menu._hotbar_slots[0].get_global_rect().get_center()
	await _drag_gui(start, finish)
	_check(interaction.tools.quantity(&"sledgehammer") == 0 and interaction.hotbar.quantity(&"sledgehammer") == 1, "Equipment tool can be dragged into hotbar")
	_check(menu._tool_slots[0].icon == null and hud._slots[0].icon == preload("res://assets/sprites/sledge.png"), "Icons follow tool transfer and clear emptied slot")
	await _drag_gui(finish, start)
	_check(interaction.tools.quantity(&"sledgehammer") == 1 and menu._tool_slots[0].icon == preload("res://assets/sprites/sledge.png") and hud._slots[0].icon == null, "Tool drag back restores equipment icon")
	_check(menu._hotbar_slots[0].is_visible_in_tree(), "Hotbar remains visible below equipment")
	if "--capture" in OS.get_cmdline_user_args():
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("C:/Users/admin/Documents/Codex/2026-10-22/https-chatgpt-com-s-cx-6ada58e0c59c819191b4f8cbdfe30cc4/work/tools-equipment.png")
	world.queue_free()
	await process_frame
	print("Tool equipment checks finished. Failures: ", failures)
	quit(1 if failures else 0)
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


