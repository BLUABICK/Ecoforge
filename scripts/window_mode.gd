extends Node
## Global shortcut works while inventory and container menus are open.
var _previous_mode: DisplayServer.WindowMode = DisplayServer.WINDOW_MODE_WINDOWED

func _input(event: InputEvent) -> void:
	if handle_shortcut(event):
		get_viewport().set_input_as_handled()

func handle_shortcut(event: InputEvent) -> bool:
	if not event is InputEventKey or not event.pressed or event.echo:
		return false
	var fullscreen_key: bool = event.physical_keycode == KEY_F11 or event.keycode == KEY_F11
	var alt_enter: bool = event.alt_pressed and (event.physical_keycode in [KEY_ENTER, KEY_KP_ENTER] or event.keycode in [KEY_ENTER, KEY_KP_ENTER])
	if not fullscreen_key and not alt_enter:
		return false
	toggle_fullscreen()
	return true

func toggle_fullscreen() -> void:
	var mode := DisplayServer.window_get_mode()
	if mode in [DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]:
		DisplayServer.window_set_mode(_previous_mode)
	else:
		_previous_mode = DisplayServer.WINDOW_MODE_MAXIMIZED if mode == DisplayServer.WINDOW_MODE_MAXIMIZED else DisplayServer.WINDOW_MODE_WINDOWED
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)



