extends SceneTree
var failures := 0
func _initialize() -> void:
 call_deferred("run")
func check(ok: bool, message: String) -> void:
 print("PASS: " if ok else "FAIL: ", message)
 if not ok:
  failures += 1
func place(c: Node2D, start: Vector2, finish: Vector2) -> Node2D:
 c._start_wire_drawing(start)
 c.update_preview(finish)
 if not c.confirm():
  check(false, "Placement succeeds")
  return null
 return c._free_buildings.back()
func run() -> void:
 var world := Node2D.new()
 root.add_child(world)
 var c = load("res://scenes/buildings/construction_controller.gd").new()
 world.add_child(c)
 c.set_process(false)
 var player = load("res://scenes/player/player-2d.tscn").instantiate()
 world.add_child(player)
 player.set_physics_process(false)
 c.actor = player
 for kind in ["wire", "pipe"]:
  player.position = Vector2(510, 460)
  await physics_frame
  c.begin(load("res://data/buildings/%s.tres" % kind))
  var first = place(c, Vector2(404, 404), Vector2(428, 404))
  await physics_frame
  var endpoint: Vector2 = first.output_point()
  c.update_preview(endpoint + Vector2(7, 1))
  check(c.placement_position.is_equal_approx(endpoint + first.connection_ends()[1].direction * (8 if kind == "pipe" else 4)), kind + ": marker occupies next cell beyond endpoint")
  var turned = place(c, endpoint + Vector2(7, 1), endpoint + Vector2(0, 24))
  await physics_frame
  check(not first.is_queued_for_deletion() and turned.input_point().is_equal_approx(endpoint), kind + ": turn keeps source and starts at exact endpoint")
  check(first.connected_outputs.has(turned), kind + ": explicit turn connects")
  var half_width := 8.0 if kind == "pipe" else 4.0
  var expected_x: float = endpoint.x + half_width
  check(is_equal_approx(turned.output_point().x, expected_x), kind + ": turn advances past previous edge by half width")
  check(is_equal_approx(fposmod(turned.output_point().x - half_width, 8.0), 0.0), kind + ": turned strip edges stay on small-cell grid")
  check(turned.output_point().y > endpoint.y, kind + ": turn follows mouse direction")
  c.update_preview(Vector2(470, 470))
  check(c._wire_route.is_empty(), kind + ": no automatic bridges")
  var separate = place(c, Vector2(508, 404), Vector2(532, 404))
  await physics_frame
  check(separate.connected_inputs.is_empty(), kind + ": separate placement stays disconnected")
  c._start_wire_drawing(Vector2(516, 388))
  c.update_preview(Vector2(516, 420))
  check(not c.can_place and not c.confirm(), kind + ": overlapping placement is blocked")
  check(is_instance_valid(separate) and not separate.is_queued_for_deletion(), kind + ": blocked placement preserves existing segment")
  c.cancel()
  c.begin(load("res://data/buildings/%s.tres" % kind))
  # Finishing a later segment at an existing input must not connect it retroactively.
  var old = place(c, Vector2(604, 404), Vector2(628, 404))
  await physics_frame
  var finish: Vector2 = old.input_point()
  c._drawing_wire = true
  c._wire_start_connected = false
  c._wire_start_source = null
  c._wire_route = PackedVector2Array([finish - Vector2(24, 0), finish])
  check(c.confirm(), kind + ": touching endpoint placement succeeds")
  check(old.connected_inputs.is_empty(), kind + ": existing input never connects retroactively")
  for segment in c._free_buildings.duplicate():
   c.remove_building(segment)
  await physics_frame
  c.cancel()
  c.begin(load("res://data/buildings/%s.tres" % kind))
  player.position = Vector2(780, 760)
  await physics_frame
  var control := InputEventKey.new()
  control.keycode = KEY_CTRL
  control.physical_keycode = KEY_CTRL
  control.pressed = true
  Input.parse_input_event(control)
  Input.flush_buffered_events()
  place(c, Vector2(804, 804), Vector2(844, 804))
  check(c._free_buildings.size() == 2, kind + ": forty pixels split into two valid pieces")
  var total := 0.0
  for segment in c._free_buildings:
   var length: float = segment.input_point().distance_to(segment.output_point())
   total += length
   check(length >= (16 if kind == "pipe" else 8) and length <= 32, kind + ": remainder respects manual segment limits")
   check(segment.get_child(0).show_behind_parent, kind + ": direction arrows render above line")
  check(is_equal_approx(total, 40), kind + ": splitting preserves full length")
  c.advance_construction(1.0)
  var last: Node2D = c._free_buildings.back()
  var snap: Dictionary = c._start_snap(last.output_point() + Vector2(7, 1))
  check(not snap.is_empty() and snap.source == last, kind + ": magnet works while Ctrl is held")
  control = control.duplicate()
  control.pressed = false
  Input.parse_input_event(control)
  Input.flush_buffered_events()
  for segment in c._free_buildings.duplicate():
   c.remove_building(segment)
  await physics_frame
  c.cancel()
 world.queue_free()
 print("Endpoint placement failures: ", failures)
 quit(1 if failures else 0)
