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
 c.set_process(false)
 c.set_physics_process(false)
 var player = world.get_node("Player2d")
 player.set_physics_process(false)
 c.begin(load("res://data/buildings/small_container.tres"))
 c.update_preview(Vector2(896, 384))
 check(c.confirm(), "Remote placement creates unfinished building")
 var building = c._occupied[Vector2i(28, 12)]
 var initial: float = building.get_meta("construction_remaining")
 c.advance_construction(10)
 check(building.get_meta("construction_remaining") == initial and building.modulate.a < 1, "Remote building waits for player without progressing")
 player.position = building.position + Vector2(0, 100)
 await physics_frame
 await physics_frame
 c.advance_construction(0.25)
 check(building.get_meta("construction_remaining") < initial, "Construction works farther away than demolition")
 var partial: float = building.get_meta("construction_remaining")
 player.position = Vector2(448, 448)
 await physics_frame
 c.advance_construction(10)
 check(building.get_meta("construction_remaining") == partial, "Leaving range preserves construction progress")
 player.position = building.position + Vector2(0, 100)
 await physics_frame
 world._add_wall(Rect2(building.position + Vector2(-50, 50), Vector2(100, 8)))
 var wall = world.get_child(world.get_child_count() - 1)
 await physics_frame
 c.advance_construction(10)
 check(building.get_meta("construction_remaining") == partial, "Wall blocks construction work")
 wall.queue_free()
 await physics_frame
 c.advance_construction(10)
 check(building.get_meta("construction_remaining") == 0 and building.modulate.a == 1, "Approaching resumes and completes the building")
 c.begin(load("res://data/buildings/wire.tres"))
 c._wire_route = PackedVector2Array([Vector2(1320, 700), Vector2(1352, 700)])
 check(c.confirm(), "Place remote connection segment")
 var wire = c._free_buildings.back()
 c.advance_construction(10)
 check(not wire.visible, "Remote segment also waits for construction reach")
 player.position = Vector2(1336, 650)
 await physics_frame
 c.advance_construction(1)
 check(wire.visible and not wire.has_node("WorkVisual"), "Nearby connection appears without extra animation")
 check(world.get_node_or_null("HUD/Controls") == null and world.get_node("HUD").get_child_count() == 1, "Gameplay HUD has no debug instructions or status labels")
 check(root.get_node("DeveloperConsole")._entry.placeholder_text.is_empty(), "Console input has no command suggestions")
 world.queue_free()
 print("Construction reach failures: ", failures)
 quit(1 if failures else 0)
