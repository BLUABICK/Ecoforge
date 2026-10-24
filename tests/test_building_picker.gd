extends SceneTree
var failures := 0
func _initialize() -> void:
 call_deferred("run")
func check(ok: bool, message: String) -> void:
 print("PASS: " if ok else "FAIL: ", message)
 if not ok:
  failures += 1
func run() -> void:
 var world = load("res://tests/playgrounds/resource_playground.tscn").instantiate()
 root.add_child(world)
 await physics_frame
 await physics_frame
 var c = world.construction
 c.set_process(false)
 c.set_physics_process(false)
 var player = world.get_node("Player2d")
 player.set_physics_process(false)
 var storage = world._storage
 check(storage.position == Vector2(480, 688), "Initial container matches build-grid footprint")
 check(c._occupied.get(Vector2i(14, 21)) == storage and c._occupied.get(Vector2i(15, 21)) == storage, "Initial container reserves both building cells")
 var click := InputEventMouseButton.new()
 click.button_index = MOUSE_BUTTON_MIDDLE
 click.pressed = true
 click.position = c.get_canvas_transform() * storage.global_position
 c._unhandled_input(click)
 check(c.active and c.definition.id == &"small_container", "Middle click activates matching construction")
 check(player.get_node("Interaction").input_blocked, "Picked construction blocks normal world interactions")
 c.cancel()
 player.set_menu_open(true)
 check(not c.pick_building(storage.global_position) and not c.active, "Menu blocks picking")
 player.set_menu_open(false)
 check(not c.pick_building(Vector2(100, 100)), "Empty ground does not start construction")
 player.position = storage.position + Vector2(0, 40)
 await physics_frame
 await physics_frame
 c.set_tool(0)
 c.advance_demolition(0.61, storage.global_position, true)
 check(storage.is_queued_for_deletion(), "Initial container can be demolished with hammer")
 check(not c._occupied.has(Vector2i(14, 21)) and not c._occupied.has(Vector2i(15, 21)), "Demolition frees initial cells")
 await physics_frame
 c.begin(load("res://data/buildings/small_container.tres"))
 c.update_preview(Vector2(448, 672))
 check(c.confirm(), "Container can be rebuilt at exactly the initial position")
 world.queue_free()
 print("Building picking failures: ", failures)
 quit(1 if failures else 0)
