extends SceneTree
const Inventory = preload("res://scenes/player/inventory.gd")
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
	var menu = hud._storage_menu
	var chest = world._storage
	var bag = interaction.inventory
	var tools = interaction.tools
	bag.add(&"iron_ore", 5)
	bag.add(&"limestone", 3)
	_check(tools.quantity(&"sledgehammer") == 1 and tools.quantity(&"screwdriver") == 1, "Tools are real starting items")
	interaction.interact()
	_check(not menu.visible, "Remote interaction cannot open storage")
	player.position = Vector2(480, 636)
	await physics_frame
	await physics_frame
	Input.action_press("interact")
	await physics_frame
	await physics_frame
	Input.action_release("interact")
	_check(menu.visible and player.menu_open and interaction.input_blocked, "E opens nearby storage and blocks gameplay")
	_check(menu._bag_slots.size() == 15 and menu._tool_slots.size() == 6 and menu._storage_slots.size() == 25, "Both inventories and tools have visible slots")
	var right_click := InputEventMouseButton.new()
	right_click.button_index = MOUSE_BUTTON_RIGHT
	right_click.pressed = true
	right_click.shift_pressed = true
	menu._bag_slots[0].gui_input.emit(right_click)
	_check(bag.quantity(&"iron_ore") == 4 and chest.inventory.quantity(&"iron_ore") == 1, "Shift right click transfers exactly one")
	var left_click := InputEventMouseButton.new()
	left_click.button_index = MOUSE_BUTTON_LEFT
	left_click.pressed = true
	left_click.shift_pressed = true
	menu._bag_slots[0].gui_input.emit(left_click)
	_check(bag.quantity(&"iron_ore") == 0 and chest.inventory.quantity(&"iron_ore") == 5, "Shift left click transfers the remaining stack")
	chest.inventory.capacity = chest.inventory.total()
	menu.transfer_slot(1, 0)
	_check(tools.quantity(&"sledgehammer") == 1, "Full container does not consume tool")
	chest.inventory.capacity = 100
	menu.transfer_slot(1, 0)
	_check(tools.quantity(&"sledgehammer") == 0 and chest.inventory.quantity(&"sledgehammer") == 1, "Tool can be stored")
	_check(world.construction.selected_tool == -1 and hud._tools_button.text == "", "Stored tool is unavailable to player")
	bag.capacity = bag.total()
	menu.transfer_slot(2, 0)
	_check(chest.inventory.quantity(&"iron_ore") == 5, "Full player inventory does not consume chest items")
	bag.capacity = 30
	menu.transfer_slot(2, 0, true)
	_check(bag.quantity(&"iron_ore") == 1 and chest.inventory.quantity(&"iron_ore") == 4, "Single-item withdrawal")
	for index in 5:
		tools.add(StringName("dummy_tool_%d" % index), 1)
	menu.transfer_slot(2, 1)
	_check(chest.inventory.quantity(&"sledgehammer") == 1 and tools.quantity(&"sledgehammer") == 0, "Full tool slots reject withdrawal without loss")
	for index in 5:
		tools.remove(StringName("dummy_tool_%d" % index), 1)
	menu.transfer_slot(2, 1)
	_check(tools.quantity(&"sledgehammer") == 1 and chest.inventory.quantity(&"sledgehammer") == 0, "Tool returns to tool belt")
	_check(world.construction.selected_tool == 0 and hud._tools_button.icon == preload("res://assets/sprites/sledge.png"), "Returned tool works again")
	var before: int = bag.total() + chest.inventory.total() + tools.total()
	for index in 8:
		menu.transfer_slot(0, 0)
		menu.transfer_slot(2, 0)
	_check(bag.total() + chest.inventory.total() + tools.total() == before, "Repeated transfers conserve all items")
	var destination = Inventory.new()
	destination.slot_limit = 1
	destination.add(&"occupied", 1)
	_check(bag.transfer_item_to(destination, &"iron_ore", 99) == 0, "Full slot limit rejects new item type")
	_check(bag.transfer_item_to(bag, &"iron_ore", 1) == 0 and bag.transfer_item_to(destination, &"iron_ore", -1) == 0, "Self and negative transfers rejected")
	_key(KEY_ESCAPE)
	_check(not menu.visible and not player.menu_open and not interaction.input_blocked, "Escape closes menu and restores gameplay")
	interaction._cooldown = 0.0
	interaction.interact()
	_check(menu.visible and tools.quantity(&"sledgehammer") == 1, "Reopening preserves inventories")
	if "--capture" in OS.get_cmdline_user_args():
		menu.transfer_slot(1, 1)
		menu.transfer_slot(0, 1)
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("C:/Users/admin/Documents/Codex/2026-10-22/https-chatgpt-com-s-cx-6ada58e0c59c819191b4f8cbdfe30cc4/work/storage-preview.png")
	chest.queue_free()
	await process_frame
	await process_frame
	_check(not menu.visible and not player.menu_open, "Deleted container safely closes its menu")
	world.queue_free()
	await process_frame
	print("Storage checks finished. Failures: ", failures)
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





