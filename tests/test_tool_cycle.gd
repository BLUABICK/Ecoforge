extends SceneTree
var failures := 0
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var world = preload("res://tests/playgrounds/resource_playground.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	var player = world.get_node("Player2d")
	var hud = world.get_node("HUD/PlayerHUD")
	var tools = player.get_node("Interaction").tools
	_cycle(hud, [1, 2, -1, 0], "Three tools including cutters and empty hands")
	tools.remove(&"wire_cutters", 1)
	_cycle(hud, [1, -1, 0, 1, -1, 0], "Two tools and empty hands")
	tools.remove(&"screwdriver", 1)
	hud._select_tool(0)
	_cycle(hud, [-1, 0, -1, 0], "One tool alternates with empty hands")
	tools.remove(&"sledgehammer", 1)
	_cycle(hud, [-1, -1, -1], "No tools stays empty")
	_check(hud._tools_button.icon == null and world.construction.selected_tool == -1, "Empty hands clear art and tool action")
	tools.add(&"sledgehammer", 1)
	tools.add(&"screwdriver", 1)
	tools.transfer_slot_to(tools, 0, 1, 3)
	tools.transfer_slot_to(tools, 1, 1, 5)
	hud._select_tool(-1)
	_cycle(hud, [3, 5, -1, 3], "Gaps are skipped in physical slot order")
	tools.add(&"sledgehammer", 4)
	hud._select_tool(0)
	_cycle(hud, [1, 2, 3, 4, 5, -1, 0], "Six occupied slots still include empty hands")
	hud._select_tool(-1)
	_check(world.construction.selected_tool == -1 and hud._tools_button.icon == null, "Full belt empty state disables demolition")
	var selected: int = hud.selected_tool
	hud._set_inventory_open(true)
	_key()
	_check(hud.selected_tool == selected, "Open inventory blocks Q cycling")
	hud._set_inventory_open(false)
	_key(true)
	_check(hud.selected_tool == selected, "Held key echo does not cycle repeatedly")
	world.queue_free()
	await process_frame
	print("Tool cycle checks finished. Failures: ", failures)
	quit(1 if failures else 0)
func _cycle(hud: Node, expected: Array, label: String) -> void:
	for value in expected:
		_key()
		_check(hud.selected_tool == value, "%s -> %d" % [label, value])
func _key(echo: bool = false) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_Q
	event.keycode = KEY_Q
	event.pressed = true
	event.echo = echo
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	event = event.duplicate()
	event.pressed = false
	event.echo = false
	Input.parse_input_event(event)
	Input.flush_buffered_events()
func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error(description)
