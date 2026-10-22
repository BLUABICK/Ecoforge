extends SceneTree
var failures := 0
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var world = preload("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	await process_frame
	var mode = root.get_node("WindowMode")
	var hud = world.get_node("ResourcePlayground/HUD/PlayerHUD")
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	await process_frame
	_key(KEY_F11)
	await process_frame
	_check(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN, "Short F11 tap enters native fullscreen")
	_key(KEY_ENTER, true)
	await process_frame
	_check(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED, "Short Alt Enter tap restores window")
	hud._set_inventory_open(true)
	_key(KEY_F11)
	await process_frame
	_check(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN, "Inventory does not intercept fullscreen")
	_key(KEY_F11)
	await process_frame
	hud._set_inventory_open(false)
	hud._open_storage(world.get_node("ResourcePlayground")._storage)
	_key(KEY_ENTER, true)
	await process_frame
	_check(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN, "Container does not intercept fullscreen")
	_key(KEY_F11)
	await process_frame
	_check(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED, "Fullscreen toggles exactly once per tap")
	world.queue_free()
	await process_frame
	print("Fullscreen checks finished. Failures: ", failures)
	quit(1 if failures else 0)
func _key(code: Key, alt: bool = false) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.alt_pressed = alt
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
