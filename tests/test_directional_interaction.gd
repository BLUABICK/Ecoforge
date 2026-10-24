extends SceneTree
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	print("PASS: " if ok else "FAIL: ", message)
	if not ok:
		failures += 1
func run() -> void:
	var world = preload("res://tests/playgrounds/resource_playground.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	var player = world.get_node("Player2d")
	player.set_physics_process(false)
	var interaction = player.get_node("Interaction")
	interaction.set_physics_process(false)
	var building = preload("res://scenes/buildings/trade_terminal.tscn").instantiate()
	building.position = Vector2(1400, 700)
	world.add_child(building)
	var activations := [0]
	building.interaction_requested.connect(func(_building: Node2D) -> void: activations[0] += 1)
	for turns in 4:
		building.rotation = turns * PI / 2.0
		await physics_frame
		for local_position in [Vector2(0, -40), Vector2(0, 40), Vector2(48, 0), Vector2(-48, 0)]:
			player.global_position = building.to_global(local_position)
			await physics_frame
			await physics_frame
			interaction.refresh_target()
			var is_front: bool = local_position.y < 0
			check((interaction.target == building) == is_front, "Only arrow-facing side selects building at rotation %d" % turns)
			interaction._cooldown = 0.0
			var before: int = activations[0]
			interaction.interact()
			check(activations[0] - before == (1 if is_front else 0), "Interaction is blocked from rear and lateral sides")
	player.global_position = building.to_global(Vector2(0, -40))
	await physics_frame
	interaction.refresh_target()
	player.global_position = building.to_global(Vector2(0, 40))
	await physics_frame
	interaction._cooldown = 0.0
	var before: int = activations[0]
	interaction.interact()
	check(activations[0] == before, "Moving behind a selected building invalidates stale interaction")
	world.queue_free()
	await process_frame
	print("Directional interaction failures: ", failures)
	quit(1 if failures else 0)
