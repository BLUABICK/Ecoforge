extends CanvasLayer
## Autoload keeps the log and history across scene restarts.
const BuildingCommands = preload("res://scripts/building_console_commands.gd")
var _building_commands: RefCounted

const PlayerCommands = preload("res://scripts/player_console_commands.gd")
var _player_commands: RefCounted

const Registry = preload("res://scripts/console_command_registry.gd")
const CommandHighlighter = preload("res://scripts/console_syntax_highlighter.gd")
const HISTORY_LIMIT := 100
const LOG_LIMIT := 300
var registry := Registry.new()
var is_open := false
var history: Array[String] = []
var log_entries: Array[Dictionary] = []
var _history_index := 0
var _draft := ""
var _setting_input := false
var _was_paused := false
var _previous_focus: WeakRef
var _root: Control
var _output: RichTextLabel
var _entry: TextEdit
var _highlighter: SyntaxHighlighter

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	register_builtin_commands()
	_build_ui()
	_root.hide()

func register_builtin_commands() -> void:
	registry.register_command("help", _command_help, "Список команд или справка по одной команде.", 0, 1, "help [command]")
	_player_commands = PlayerCommands.new(get_tree())
	_player_commands.register_commands(registry)
	_building_commands = BuildingCommands.new(get_tree())
	_building_commands.register_commands(registry)
	registry.register_command("restart", _command_restart, "Перезапустить текущую сцену с исходным состоянием.")
	registry.register_command("exit", _command_exit, "Закрыть игру.")

func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	var shade := ColorRect.new()
	shade.color = Color(0.015, 0.025, 0.04, 0.4)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(shade)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	panel.anchor_bottom = 0.58
	panel.offset_bottom = 0
	var style := StyleBoxFlat.new()
	style.bg_color = Color("111c24")
	style.border_color = Color("36515f")
	style.border_width_bottom = 2
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 12
	style.content_margin_bottom = 14
	panel.add_theme_stylebox_override("panel", style)
	_root.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	_output = RichTextLabel.new()
	_output.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_output.selection_enabled = true
	_output.scroll_following = true
	_output.add_theme_font_size_override("normal_font_size", 17)
	_output.add_theme_color_override("default_color", CommandHighlighter.DEFAULT_COLOR)
	column.add_child(_output)
	var input_row := HBoxContainer.new()
	column.add_child(input_row)
	var prompt := Label.new()
	prompt.text = ">"
	prompt.add_theme_color_override("font_color", CommandHighlighter.COMMAND_COLOR)
	input_row.add_child(prompt)
	_entry = TextEdit.new()
	_entry.custom_minimum_size = Vector2(0, 42)
	_entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_entry.scroll_fit_content_height = false
	_entry.wrap_mode = TextEdit.LINE_WRAPPING_NONE
	_entry.add_theme_font_size_override("font_size", 18)
	_entry.add_theme_color_override("font_color", CommandHighlighter.DEFAULT_COLOR)
	_highlighter = CommandHighlighter.new()
	_highlighter.registry = registry
	_entry.syntax_highlighter = _highlighter
	_entry.text_changed.connect(_on_text_changed)
	input_row.add_child(_entry)

func set_open(open: bool) -> void:
	if open == is_open:
		return
	is_open = open
	_root.visible = open
	if open:
		_was_paused = get_tree().paused
		var focused := get_viewport().gui_get_focus_owner()
		_previous_focus = weakref(focused) if focused != null else null
		get_tree().paused = true
		_history_index = history.size()
		_entry.grab_focus()
	else:
		_entry.release_focus()
		get_tree().paused = _was_paused
		if _previous_focus != null:
			var focused = _previous_focus.get_ref()
			if is_instance_valid(focused) and focused.is_inside_tree() and focused.is_visible_in_tree():
				focused.grab_focus()

func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		var toggle: bool = event.physical_keycode == KEY_QUOTELEFT or event.keycode == KEY_QUOTELEFT or event.unicode in [0x451, 0x401]
		if toggle:
			if event.pressed and not event.echo:
				set_open(not is_open)
			get_viewport().set_input_as_handled()
			return
	if not is_open:
		return
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			set_open(false)
		elif event.keycode in [KEY_ENTER, KEY_KP_ENTER]:
			if not event.echo:
				submit_command(_entry.text)
		elif event.keycode == KEY_UP:
			browse_history(-1)
		elif event.keycode == KEY_DOWN:
			browse_history(1)
		elif event.keycode == KEY_TAB:
			_entry.grab_focus()
		else:
			return
		get_viewport().set_input_as_handled()

func _on_text_changed() -> void:
	if not _setting_input:
		_history_index = history.size()
		_draft = _entry.text

func _set_entry(text: String) -> void:
	_setting_input = true
	_entry.text = text
	_entry.set_caret_line(_entry.get_line_count() - 1)
	_entry.set_caret_column(_entry.get_line(_entry.get_caret_line()).length())
	_setting_input = false

func browse_history(direction: int) -> void:
	if history.is_empty():
		return
	if _history_index == history.size():
		_draft = _entry.text
	_history_index = clampi(_history_index + direction, 0, history.size())
	_set_entry(_draft if _history_index == history.size() else history[_history_index])

func submit_command(line: String) -> void:
	line = line.strip_edges()
	_set_entry("")
	_draft = ""
	if line.is_empty():
		return
	if history.is_empty() or history.back() != line:
		history.append(line)
		if history.size() > HISTORY_LIMIT:
			history.pop_front()
	_history_index = history.size()
	write_log(line, "command")
	var result := registry.execute(line)
	if not String(result.get("message", "")).is_empty():
		write_log(result.message, "result" if result.get("ok", false) else "error")

func write_log(message: String, kind: String = "result") -> void:
	log_entries.append({"text": message, "kind": kind})
	if log_entries.size() > LOG_LIMIT:
		log_entries.pop_front()
		_output.clear()
		for entry in log_entries:
			_append_log(entry)
	else:
		_append_log(log_entries.back())

func _append_log(entry: Dictionary) -> void:
	if entry.kind == "command":
		_output.push_color(CommandHighlighter.DEFAULT_COLOR)
		_output.add_text("> ")
		_output.pop()
		var parsed := Registry.tokenize(entry.text)
		var offset := 0
		for index in parsed.spans.size():
			var span: Dictionary = parsed.spans[index]
			_output.add_text(String(entry.text).substr(offset, span.start - offset))
			_output.push_color(_highlighter.token_color(span, index))
			_output.add_text(String(entry.text).substr(span.start, span.end - span.start))
			_output.pop()
			offset = span.end
		_output.add_text(String(entry.text).substr(offset))
	else:
		_output.push_color(CommandHighlighter.ERROR_COLOR if entry.kind == "error" else Color("a8c1c9"))
		_output.add_text(entry.text)
		_output.pop()
	_output.add_text("\n")

func _command_restart(_args: PackedStringArray) -> Dictionary:
	if get_tree().current_scene == null or get_tree().current_scene.scene_file_path.is_empty():
		return {"ok": false, "message": "Нет сохранённой текущей сцены для перезапуска."}
	_reload_scene.call_deferred()
	return {"ok": true, "message": "Перезапуск сцены…"}

func _reload_scene() -> void:
	set_open(false)
	var error := get_tree().reload_current_scene()
	if error != OK:
		write_log("Не удалось перезапустить сцену: %s" % error_string(error), "error")
		set_open(true)

func _command_exit(_args: PackedStringArray) -> Dictionary:
	get_tree().quit.call_deferred()
	return {"ok": true, "message": "Выход из игры…"}


func _command_help(args: PackedStringArray) -> Dictionary:
	if not args.is_empty():
		var command := args[0].to_lower()
		if not registry.has_command(command):
			return {"ok": false, "message": "Неизвестная команда: %s" % args[0]}
		var entry: Dictionary = registry.commands[command]
		return {"ok": true, "message": "%s — %s" % [entry.usage, entry.description]}
	var lines := PackedStringArray()
	for entry in registry.commands.values():
		lines.append("%s — %s" % [entry.usage, entry.description])
	return {"ok": true, "message": "\n".join(lines)}
