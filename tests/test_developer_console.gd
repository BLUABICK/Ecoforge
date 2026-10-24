extends SceneTree
const Registry = preload("res://scripts/console_command_registry.gd")
var failures := 0
func _initialize() -> void:
 call_deferred("run")
func check(ok: bool, message: String) -> void:
 print("PASS: " if ok else "FAIL: ", message)
 if not ok:
  failures += 1
func run() -> void:
 var console = root.get_node("DeveloperConsole")
 if "--exit-test" in OS.get_cmdline_user_args():
  console.submit_command("exit")
  await create_timer(2.0, true).timeout
  quit(1)
  return
 var registry := Registry.new()
 registry.register_command("sample", func(args: PackedStringArray) -> Dictionary: return {"ok": true, "message": "|".join(args)}, "Test extension", 2, 2, "sample <name> <count>")
 check(registry.execute('sample "hello world" 12').message == "hello world|12", "Registry accepts quoted arguments and extension callbacks")
 check(not registry.execute('sample "unterminated').ok, "Unclosed quote gives a readable error")
 check(not registry.execute("sample one").ok, "Registry validates argument counts")
 check(not registry.execute("unknown").ok, "Unknown commands are rejected")
 check(console.registry.has_command("help") and console.registry.has_command("restart") and console.registry.has_command("exit"), "Help, restart and exit are registered")
 var world = load("res://tests/playgrounds/resource_playground.tscn").instantiate()
 root.add_child(world)
 current_scene = world
 await physics_frame
 var player = world.get_node("Player2d")
 var starting_position: Vector2 = player.position
 player.position += Vector2(120, 0)
 player.get_node("Interaction").inventory.add(&"iron_ore", 3)
 var key := InputEventKey.new()
 key.physical_keycode = KEY_QUOTELEFT
 key.pressed = true
 console._input(key)
 check(console.is_open and paused and console._entry.has_focus(), "Physical ё key opens console, focuses input, and pauses game")
 console._set_entry('restart "hello world" 12')
 var colors: Dictionary = console._highlighter.get_line_syntax_highlighting(0)
 check(colors.has(0) and colors.has(8) and colors.has(22), "Command, quoted argument and number have syntax highlighting")
 console.submit_command("unknown")
 console.submit_command("restart extra")
 check(is_instance_valid(world), "Invalid restart arguments do not restart the scene")
 check(console.log_entries.size() == 4 and console.log_entries.back().kind == "error", "Log includes commands and errors")
 console._set_entry("draft")
 console.browse_history(-1)
 check(console._entry.text == "restart extra", "Up restores most recent command")
 await process_frame
 console.browse_history(-1)
 check(console._entry.text == "unknown", "Up traverses older commands")
 console.browse_history(1)
 console.browse_history(1)
 check(console._entry.text == "draft", "Down restores unfinished draft after history")
 console.set_open(false)
 check(not paused and not console.is_open, "Closing console restores prior pause state")
 var hud = world.get_node("HUD/PlayerHUD")
 hud._set_inventory_open(true)
 console.set_open(true)
 var tab := InputEventKey.new()
 tab.keycode = KEY_TAB
 tab.physical_keycode = KEY_TAB
 tab.pressed = true
 Input.parse_input_event(tab)
 Input.flush_buffered_events()
 await process_frame
 check(hud._inventory_menu.visible and console.is_open, "Console input does not toggle underlying inventory")
 console.set_open(false)
 check(hud._inventory_menu.visible and player.menu_open, "Closing console preserves existing menu state")
 hud._set_inventory_open(false)
 paused = true
 console.set_open(true)
 console.set_open(false)
 check(paused, "Console preserves an already paused game")
 paused = false
 console.set_open(true)
 console.submit_command("restart")
 await process_frame
 await process_frame
 await physics_frame
 var fresh = current_scene
 check(not is_instance_valid(world) and fresh != null, "Restart replaces the whole current scene")
 check(fresh.get_node("Player2d").position == starting_position, "Restart restores initial player position")
 check(fresh.get_node("Player2d/Interaction").inventory.quantity(&"iron_ore") == 0, "Restart resets scene inventory")
 check(not console.is_open and not paused and console.history.back() == "restart", "Restart closes console while retaining command history")
 console.set_open(true)
 console.browse_history(-1)
 check(console._entry.text == "restart", "History is usable after restart")
 console.set_open(false)
 print("Console failures: ", failures)
 quit(1 if failures else 0)
