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
	player.global_position = Vector2(944, 360)
	c.begin(load("res://data/buildings/cargo_container.tres"))
	c.update_preview(Vector2(900, 400))
	check(c.confirm(), "Place cargo container")
	var host = c._occupied[Vector2i(28, 12)]
	c.begin(load("res://data/buildings/terminal.tres"))
	c.update_preview(Vector2(944, 400))
	check(c.can_place and c.confirm(), "Install terminal on occupied cargo container footprint")
	var terminal = c._free_buildings.back()
	check(terminal.mount_host == host and terminal.inventory == host.inventory, "Mounted terminal accesses the container inventory")
	check(c._occupied[Vector2i(29, 12)] == host, "Mount does not overwrite container footprint")
	c.update_preview(Vector2(912, 400))
	check(not c.can_place, "Second terminal on same container is rejected")
	c.cancel()
	host.inventory.add(&"ore", 5)
	player.global_position = host.to_global(Vector2(0, -48))
	await physics_frame
	var interaction = player.get_node("Interaction")
	interaction.refresh_target()
	check(interaction.target == terminal, "Container does not obstruct interaction with mounted terminal")
	interaction._cooldown = 0
	interaction.interact()
	var menu = world.get_node("HUD/PlayerHUD")._storage_menu
	check(menu.visible and menu.storage == terminal and menu.storage.inventory.quantity(&"ore") == 5, "E opens real cargo inventory through terminal")
	check(terminal.inventory.transfer_item_to(interaction.inventory, &"ore", 2) == 2 and host.inventory.quantity(&"ore") == 3, "Menu uses persistent cargo storage for item transfer")
	menu.close_menu()
	player.global_position = host.to_global(Vector2(0, 48))
	interaction.refresh_target()
	check(interaction.target != terminal, "Interaction remains limited to arrow-facing side")
	c.remove_building(host)
	await process_frame
	check(not is_instance_valid(terminal), "Removing container also removes mounted terminal")
	world.queue_free()
	await process_frame
	print("Mounted terminal failures: ", failures)
	quit(1 if failures else 0)