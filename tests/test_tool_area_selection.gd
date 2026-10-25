extends SceneTree
var failures := 0
func _initialize() -> void:
 call_deferred("run")
func check(ok: bool, message: String) -> void:
 print("PASS: " if ok else "FAIL: ", message)
 if not ok:
  failures += 1
func run() -> void:
 for tool in [0, 1]:
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
  c.begin(load("res://data/buildings/small_container.tres"))
  c.update_preview(Vector2(512, 672))
  check(c.confirm(), "Place second demolition fixture")
  c.advance_construction(10)
  var first = world._storage
  var second = c._occupied[Vector2i(16, 21)]
  c.cancel()
  c.set_tool(tool)
  player.position = Vector2(512, 688)
  await physics_frame
  await physics_frame
  var press := InputEventMouseButton.new()
  press.button_index = MOUSE_BUTTON_LEFT
  press.pressed = true
  press.ctrl_pressed = true
  press.position = c.get_canvas_transform() * Vector2(440, 650)
  c._unhandled_input(press)
  check(c._cut_dragging and not c._using_tool, "Ctrl press starts selection instead of demolition")
  var release := InputEventMouseButton.new()
  release.button_index = MOUSE_BUTTON_LEFT
  release.position = c.get_canvas_transform() * Vector2(580, 720)
  c._input(release)
  check(c._demolition_queue.size() == 2, "Ctrl area queues both buildings")
  var duration := 0.6 if tool == 0 else 3.0
  c.advance_demolition_queue(duration - 0.01)
  check(not first.is_queued_for_deletion() and not second.is_queued_for_deletion(), "Queue respects selected tool duration")
  var current = c._demolition_target
  var pending = second if current == first else first
  check(current != null and current.get_node("WorkVisual").demolition_progress > 0.9, "Only current target shows demolition progress")
  c.advance_demolition_queue(0.02)
  check(current.is_queued_for_deletion() and not pending.is_queued_for_deletion() and c._demolition_queue.size() == 1, "Only one building is removed at a time")
  await physics_frame
  player.position = Vector2(1300, 700)
  await physics_frame
  c.advance_demolition_queue(10)
  check(not pending.is_queued_for_deletion() and c._demolition_queue.size() == 1, "Remote building remains selected without being removed")
  player.position = pending.position + Vector2(0, 40)
  await physics_frame
  await physics_frame
  player.set_menu_open(true)
  c.advance_demolition_queue(10)
  check(not pending.is_queued_for_deletion(), "Menu pauses queued demolition")
  player.set_menu_open(false)
  c.advance_demolition_queue(duration + 0.01)
  check(pending.is_queued_for_deletion() and c._demolition_queue.is_empty(), "Approaching resumes the next queued building")
  c._demolition_queue.append(pending)
  var cancel := InputEventMouseButton.new()
  cancel.button_index = MOUSE_BUTTON_RIGHT
  cancel.pressed = true
  c._unhandled_input(cancel)
  check(c._demolition_queue.is_empty(), "RMB cancels selected buildings")
  press = press.duplicate()
  press.ctrl_pressed = false
  c._unhandled_input(press)
  check(not c._cut_dragging and c._using_tool, "Normal LMB retains single-target tool use")
  world.queue_free()
  await physics_frame
 print("Tool area selection failures: ", failures)
 quit(1 if failures else 0)
