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
 var c = world.construction
 c.remote_placement_enabled = true # Opt in to retained remote blueprint mechanic for fixtures.
 c.set_process(false)
 c.set_physics_process(false)
 var player = world.get_node("Player2d")
 player.set_physics_process(false)
 c.begin(load("res://data/buildings/small_container.tres"))
 c.update_preview(Vector2(896, 384))
 check(c.confirm(), "Place timed container")
 var small = c._occupied[Vector2i(28, 12)]
 var small_time: float = small.get_meta("construction_duration")
 check(small.modulate.a < 1.0 and not small.can_interact_from(small.position), "Unfinished container is translucent and unavailable")
 player.position = small.position + Vector2(0, 40)
 await physics_frame
 await physics_frame
 c.advance_construction(small_time * 0.5)
 check(small.get_node("WorkVisual").build_progress > 0 and small.get_node("WorkVisual").build_progress < 1, "Construction visual tracks partial progress")
 c.begin(load("res://data/buildings/cargo_container.tres"))
 c.update_preview(Vector2(1100, 384))
 check(c.confirm(), "Place larger timed building")
 var large = c._occupied[Vector2i(34, 12)]
 check(float(large.get_meta("construction_duration")) > small_time, "Larger footprint takes longer")
 c.advance_construction(10)
 check(small.modulate.a == 1 and small.can_interact_from(small.position), "Completed container becomes opaque and usable")
 c.cancel()
 player.position = small.position + Vector2(0, 40)
 await physics_frame
 await physics_frame
 c.set_tool(1)
 c.advance_demolition(1.0, small.position, true)
 check(small.get_node("WorkVisual").demolition_progress > 0.3, "Dismantling advances red work overlay")
 c.advance_demolition(0, small.position, false)
 check(small.get_node("WorkVisual").demolition_progress == 0, "Releasing tool clears temporary work overlay")
 for kind in ["wire", "pipe"]:
  for tool in [0, 1]:
   c.begin(load("res://data/buildings/%s.tres" % kind))
   c._start_wire_drawing(Vector2(1300, 700))
   c.update_preview(Vector2(1324, 700))
   check(c.confirm(), kind + ": place short timed segment")
   var segment = c._free_buildings.back()
   c.cancel()
   var cursor: Vector2 = (segment.input_point() + segment.output_point()) * 0.5
   player.position = cursor + Vector2(0, 28)
   await physics_frame
   await physics_frame
   c.advance_construction(1)
   c.set_tool(tool)
   c.advance_demolition(10.0, cursor, true)
   check(not segment.is_queued_for_deletion() and c._demolition_target == null, kind + ": hammer and screwdriver cannot start demolition")
   c.demolition_instant = true
   c.advance_demolition(0.0, cursor, true)
   check(not segment.is_queued_for_deletion(), kind + ": instant demolition cannot bypass tool restriction")
   c.demolition_instant = false
   c.area_selection_enabled = true
   c.queue_demolition_area(cursor - Vector2(40, 16), cursor + Vector2(40, 16))
   check(not c._demolition_queue.has(segment), kind + ": retained demolition area never selects connections")
   c.area_selection_enabled = false
   c.set_tool(2)
   check(c.cut_wire_at(cursor), kind + ": cutters still remove the selected portion")
   for piece in c._free_buildings.duplicate():
    c.remove_building(piece)
   await physics_frame
 world.queue_free()
 print("Building work failures: ", failures)
 quit(1 if failures else 0)
