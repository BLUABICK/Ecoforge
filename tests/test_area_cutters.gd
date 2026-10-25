extends SceneTree
var failures := 0
func _initialize() -> void:
 call_deferred("run")
func check(ok: bool, message: String) -> void:
 print("PASS: " if ok else "FAIL: ", message)
 if not ok:
  failures += 1
func total_length(c: Node2D) -> float:
 var result := 0.0
 for wire in c._free_buildings:
  if is_instance_valid(wire) and not wire.is_queued_for_deletion():
   var points: PackedVector2Array = c._segment_world_points(wire)
   for index in points.size() - 1:
    result += points[index].distance_to(points[index + 1])
 return result
func run() -> void:
 var world = load("res://tests/playgrounds/resource_playground.tscn").instantiate()
 root.add_child(world)
 await physics_frame
 var c = world.construction
 c.remote_placement_enabled = true # Opt in to retained remote blueprint mechanic for fixtures.
 c.area_selection_enabled = true # Retained mechanic, disabled in the normal game.
 c.set_process(false)
 c.set_physics_process(false)
 var player = world.get_node("Player2d")
 player.set_physics_process(false)
 for kind in ["wire", "pipe"]:
  player.position = Vector2(1320, 650)
  await physics_frame
  await physics_frame
  var line_y := 704.0 if kind == "pipe" else 700.0
  c.begin(load("res://data/buildings/%s.tres" % kind))
  c._wire_route = PackedVector2Array([Vector2(1320, line_y), Vector2(1600, line_y)])
  var control := InputEventKey.new()
  control.keycode = KEY_CTRL
  control.physical_keycode = KEY_CTRL
  control.pressed = true
  Input.parse_input_event(control)
  Input.flush_buffered_events()
  check(c.confirm(), kind + ": place long chain")
  control = control.duplicate()
  control.pressed = false
  Input.parse_input_event(control)
  Input.flush_buffered_events()
  check(c._free_buildings[0].visible and not c._free_buildings[1].visible, kind + ": only first segment appears immediately")
  check(not c._free_buildings[0].has_node("WorkVisual") and c._free_buildings[0].modulate.a == 1, kind + ": no construction glow or transparency")
  c.advance_construction(0.061)
  check(c._free_buildings[1].visible and not c._free_buildings[2].visible, kind + ": segments appear in drawing order")
  player.position = Vector2(1460, 650)
  await physics_frame
  c.advance_construction(10)
  c.cancel()
  c.set_tool(2)
  player.position = Vector2(1300, 700)
  await physics_frame
  await physics_frame
  var before := total_length(c)
  c.queue_cut_area(Vector2(1310, 685), Vector2(1610, 715))
  check(not c._cut_tasks.is_empty(), kind + ": drag selection queues area")
  c.advance_cut_selection()
  check(total_length(c) < before and total_length(c) > 0, kind + ": only reachable selected portions cut")
  check(not c._cut_tasks.is_empty(), kind + ": distant selection remains pending")
  var remaining := total_length(c)
  player.set_menu_open(true)
  player.position = Vector2(1500, 700)
  c.advance_cut_selection()
  check(is_equal_approx(total_length(c), remaining), kind + ": open menu pauses pending cuts")
  player.set_menu_open(false)
  for x in [1400, 1500, 1600]:
   player.position = Vector2(x, 700)
   await physics_frame
   await physics_frame
   c.advance_cut_selection()
  check(is_zero_approx(total_length(c)) and c._cut_tasks.is_empty(), kind + ": approaching completes selected area without clicking again")
  c._cut_tasks.append({"point": Vector2(1700, 900), "size": 8.0})
  c.set_tool(0)
  check(c._cut_tasks.is_empty(), kind + ": switching tools cancels pending cuts")
 # Exercise the actual press-drag-release path with a remote target.
 c.set_tool(2)
 var remote = load("res://scenes/buildings/wire.tscn").instantiate()
 remote.route = PackedVector2Array([Vector2(1400, 900), Vector2(1432, 900)])
 remote.set_meta("building_id", &"wire")
 world.add_child(remote)
 c._free_buildings.append(remote)
 player.position = Vector2(1000, 900)
 await physics_frame
 var press := InputEventMouseButton.new()
 press.button_index = MOUSE_BUTTON_LEFT
 press.pressed = true
 press.ctrl_pressed = true
 press.position = c.get_canvas_transform() * Vector2(1390, 885)
 c._unhandled_input(press)
 check(c._cut_dragging and is_instance_valid(remote), "LMB starts area preview without deleting remote target")
 var motion := InputEventMouseMotion.new()
 motion.position = c.get_canvas_transform() * Vector2(1440, 915)
 c._unhandled_input(motion)
 var release := InputEventMouseButton.new()
 release.button_index = MOUSE_BUTTON_LEFT
 release.position = motion.position
 c._input(release)
 check(not c._cut_dragging and not c._cut_tasks.is_empty(), "Releasing LMB keeps the remote selected area")
 var cancel := InputEventMouseButton.new()
 cancel.button_index = MOUSE_BUTTON_RIGHT
 cancel.pressed = true
 c._unhandled_input(cancel)
 check(c._cut_tasks.is_empty() and is_instance_valid(remote), "RMB clears selection without deleting remote target")
 world.queue_free()
 print("Area cutter and reveal failures: ", failures)
 quit(1 if failures else 0)
