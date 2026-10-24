extends SceneTree
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	print("PASS: " if ok else "FAIL: ", message)
	if not ok:
		failures += 1
func key(hud: Node, code: Key) -> void:
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = code
	event.physical_keycode = code
	hud._input(event)
func run() -> void:
	var world = preload("res://tests/playgrounds/resource_playground.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	var player = world.get_node("Player2d")
	player.set_physics_process(false)
	var interaction = player.get_node("Interaction")
	interaction.set_physics_process(false)
	var hud = world.get_node("HUD/PlayerHUD")
	var terminal = preload("res://scenes/buildings/trade_terminal.tscn").instantiate()
	terminal.position = Vector2(1400, 700)
	world.add_child(terminal)
	var menu = hud._trade_menu
	for code in [KEY_ESCAPE, KEY_E, KEY_TAB]:
		interaction.inventory.remove(&"iron_ore", interaction.inventory.quantity(&"iron_ore"))
		player.global_position = terminal.to_global(Vector2(0, -40))
		await physics_frame
		await physics_frame
		interaction._cooldown = 0.0
		interaction.interact()
		check(menu.visible and menu.terminal == terminal and player.menu_open, "Front interaction opens terminal and blocks world control")
		check(menu._items.size() == 2 and menu._action.disabled, "Menu lists actual resource definitions without inventing transactions")
		menu.select_mode(1)
		check(not menu._quantity.editable, "Sale of unavailable resources is disabled")
		interaction.inventory.add(&"iron_ore", 5)
		check(menu._quantity.editable and menu._quantity.max_value == interaction.inventory.quantity(&"iron_ore"), "Sale quantity follows player inventory")
		menu.select_item(1)
		check(menu._name.text == "Известняк", "Resource selection updates the detail panel")
		key(hud, code)
		check(not menu.visible and not player.menu_open and hud._hotbar_row.visible, "E, Esc and Tab restore world control")
	player.global_position = terminal.to_global(Vector2(0, 40))
	await physics_frame
	interaction._cooldown = 0.0
	interaction.interact()
	check(not menu.visible, "Rear side cannot open the terminal")
	player.global_position = terminal.to_global(Vector2(0, -40))
	await physics_frame
	interaction._cooldown = 0.0
	interaction.interact()
	terminal.queue_free()
	await process_frame
	await process_frame
	check(not menu.visible and not player.menu_open, "Removing a terminal closes its menu safely")
	world.queue_free()
	await process_frame
	print("Trade menu failures: ", failures)
	quit(1 if failures else 0)
