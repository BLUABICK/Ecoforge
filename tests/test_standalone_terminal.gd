extends SceneTree
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + message)
	if not ok:
		failures += 1
func run() -> void:
	var world = load("res://tests/playgrounds/resource_playground.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	var c = world.construction
	c.set_process(false)
	c.set_physics_process(false)
	c.build_instant = true
	var player = world.get_node("Player2d")
	player.set_physics_process(false)
	player.global_position = Vector2(912, 368)
	c.begin(load("res://data/buildings/terminal.tres"))
	c.update_preview(Vector2(912, 400))
	check(c.confirm(), "Place a standalone terminal")
	var terminal = c._occupied[Vector2i(28, 12)]
	c.cancel()
	await physics_frame
	var interaction = player.get_node("Interaction")
	interaction._cooldown = 0
	interaction.interact()
	var hud = world.get_node("HUD/PlayerHUD")
	check(hud._terminal_menu.visible and hud._terminal_menu.terminal == terminal, "E opens the terminal's own menu")
	check(not hud._storage_menu.visible and player.menu_open, "Standalone terminal does not open storage and blocks movement")
	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.pressed = true
	hud._input(event)
	check(not hud._terminal_menu.visible and not player.menu_open, "Escape closes terminal menu and restores movement")
	interaction._cooldown = 0
	interaction.interact()
	event.keycode = KEY_E
	event.physical_keycode = KEY_E
	hud._input(event)
	check(not hud._terminal_menu.visible and not player.menu_open, "E closes terminal menu")
	world.queue_free()
	await process_frame
	print("Standalone terminal failures: ", failures)
	quit(1 if failures else 0)