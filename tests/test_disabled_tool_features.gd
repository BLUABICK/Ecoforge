extends SceneTree
var failures := 0
func _initialize() -> void:
 call_deferred("run")
func check(ok: bool, message: String) -> void:
 print("PASS: " if ok else "FAIL: ", message)
 if not ok: failures += 1
func run() -> void:
 var world = load("res://tests/playgrounds/resource_playground.tscn").instantiate()
 root.add_child(world)
 await physics_frame
 var c = world.construction
 c.set_process(false)
 c.set_physics_process(false)
 var player = world.get_node("Player2d")
 player.set_physics_process(false)
 check(not c.area_selection_enabled and not c.remote_placement_enabled, "Area selection and remote placement are disabled by default")
 for kind in ["technoformer", "delivery_pad"]:
  c.begin(load("res://data/buildings/%s.tres" % kind))
  c.update_preview(Vector2(512, 480))
  check(c.can_place and c.confirm(), kind + ": partial intersection with reach allows placement")
  var large = c._occupied[Vector2i(16, 15)]
  check(large.position.distance_to(player.position) > c.construction_reach, kind + ": centre may be outside reach")
  c.remove_building(large)
  await physics_frame
 c.begin(load("res://data/buildings/small_container.tres"))
 c.update_preview(Vector2(896, 896))
 check(not c.can_place and not c.confirm() and not c._occupied.has(Vector2i(28, 28)), "Far building cannot be placed or reserved")
 c.free_build_mode = true
 c.update_preview(Vector2(900, 900))
 check(not c.can_place and not c.confirm(), "Free placement mode still respects reach")
 c.free_build_mode = false
 c.update_preview(Vector2(448, 512))
 check(c.can_place and c.confirm(), "Nearby building can be placed")
 c.cancel()
 for tool in [0, 1, 2]:
  c.set_tool(tool)
  var press := InputEventMouseButton.new()
  press.button_index = MOUSE_BUTTON_LEFT
  press.pressed = true
  press.ctrl_pressed = true
  press.position = c.get_canvas_transform() * Vector2(600, 600)
  c._unhandled_input(press)
  check(not c._cut_dragging, "Ctrl cannot start area selection for tool %d" % tool)
  var release := InputEventMouseButton.new()
  release.button_index = MOUSE_BUTTON_LEFT
  release.position = press.position
  c._input(release)
  c.queue_cut_area(Vector2(0, 0), Vector2(1000, 1000))
  c.queue_demolition_area(Vector2(0, 0), Vector2(1000, 1000))
  check(c._cut_tasks.is_empty() and c._demolition_queue.is_empty(), "Disabled selection cannot queue tasks")
 c.begin(load("res://data/buildings/wire.tres"))
 c.update_preview(Vector2(900, 900))
 check(not c.can_place, "Remote connection marker is invalid")
 c._wire_route = PackedVector2Array([Vector2(520, 500), Vector2(520, 660)])
 var control := InputEventKey.new()
 control.physical_keycode = KEY_CTRL
 control.keycode = KEY_CTRL
 control.pressed = true
 Input.parse_input_event(control)
 Input.flush_buffered_events()
 check(c.confirm(), "A route touching reach may extend beyond the radius")
 control = control.duplicate()
 control.pressed = false
 Input.parse_input_event(control)
 Input.flush_buffered_events()
 c._wire_route = PackedVector2Array([Vector2(500, 400), Vector2(532, 400)])
 check(c.confirm(), "Nearby connection remains placeable")
 c.cancel()
 c.area_selection_enabled = true
 c.set_tool(0)
 c.queue_demolition_area(Vector2(440, 500), Vector2(520, 560))
 check(not c._demolition_queue.is_empty(), "Area mechanic remains available behind feature switch")
 c.area_selection_enabled = false
 c._physics_process(0)
 check(c._demolition_queue.is_empty(), "Disabling selection cancels existing queue")
 c.remote_placement_enabled = true
 c.begin(load("res://data/buildings/small_container.tres"))
 c.update_preview(Vector2(896, 896))
 check(c.can_place and c.confirm(), "Remote blueprint mechanic is preserved behind feature switch")
 world.queue_free()
 print("Temporary feature switch failures: ", failures)
 quit(1 if failures else 0)
