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
	c.remote_placement_enabled = true
	c.build_instant = true
	var player = world.get_node("Player2d")
	player.set_physics_process(false)
	player.global_position = Vector2(944, 384)
	var cargo = load("res://scenes/buildings/cargo_container.tscn").instantiate()
	cargo.position = Vector2(1040, 432)
	cargo.set_meta("building_id", &"cargo_container")
	world.add_child(cargo)
	var terminals: Array[Node2D] = []
	for y in [416, 448]:
		var terminal = load("res://scenes/buildings/terminal.tscn").instantiate()
		terminal.position = Vector2(880, y)
		terminal.set_meta("building_id", &"terminal")
		world.add_child(terminal)
		terminals.append(terminal)
	await physics_frame
	check(terminals[0].get_storage_host() == null, "Unwired terminal remains standalone")
	for y in [416, 448]:
		for index in 3:
			c.begin(load("res://data/buildings/wire.tres"))
			var start := Vector2(896 + index * 32, y)
			c._start_wire_drawing(start)
			c.update_preview(start + Vector2(32, 0))
			check(c.can_place and c.confirm(), "Draw wire from terminal through chain to cargo edge")
			await physics_frame
	c.cancel()
	check(terminals[0].get_storage_host() == cargo and terminals[1].get_storage_host() == cargo, "Several wired terminals resolve the same cargo container")
	cargo.inventory.add(&"ore", 9)
	check(terminals[0].inventory == terminals[1].inventory and terminals[0].inventory == cargo.inventory, "All terminals share persistent cargo inventory")
	player.global_position = Vector2(880, 384)
	await physics_frame
	var interaction = player.get_node("Interaction")
	interaction._cooldown = 0
	interaction.interact()
	var hud = world.get_node("HUD/PlayerHUD")
	check(hud._storage_menu.visible and hud._storage_menu.storage == terminals[0] and not hud._terminal_menu.visible, "E on wired standalone terminal opens cargo menu")
	check(terminals[0].inventory.transfer_item_to(interaction.inventory, &"ore", 2) == 2 and terminals[1].inventory.quantity(&"ore") == 7, "Changes through one terminal are visible through another")
	var broken = c._free_buildings[1]
	c.remove_building(broken)
	hud._process(0.0)
	check(not hud._storage_menu.visible and terminals[0].get_storage_host() == null, "Breaking wire closes cargo access immediately")
	check(terminals[1].get_storage_host() == cargo, "Other terminal retains its independent wire connection")
	await physics_frame
	interaction._cooldown = 0
	interaction.interact()
	check(hud._terminal_menu.visible, "Disconnected terminal opens its own menu again")
	hud._terminal_menu.close_menu()
	cargo.queue_free()
	await process_frame
	check(terminals[1].get_storage_host() == null, "Removed cargo cannot be accessed through wires")
	world.queue_free()
	await process_frame
	print("Wired terminal failures: ", failures)
	quit(1 if failures else 0)