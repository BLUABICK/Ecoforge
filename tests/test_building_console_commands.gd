extends SceneTree
var failures := 0
func _initialize() -> void:
 call_deferred("run")
func check(ok: bool, message: String) -> void:
 print("PASS: " if ok else "FAIL: ", message)
 if not ok:
  failures += 1
func run() -> void:
 var console = root.get_node("DeveloperConsole")
 var registry = console.registry
 var world = load("res://tests/playgrounds/resource_playground.tscn").instantiate()
 root.add_child(world)
 current_scene = world
 await physics_frame
 var c = world.construction
 c.remote_placement_enabled = true # Opt in to retained remote blueprint mechanic for fixtures.
 c.set_process(false)
 c.set_physics_process(false)
 var player = world.get_node("Player2d")
 player.set_physics_process(false)
 c.begin(load("res://data/buildings/small_container.tres"))
 c.update_preview(Vector2(896, 896))
 check(c.confirm(), "Place remote command fixture")
 var building = c._occupied[Vector2i(28, 28)]
 c.advance_construction(10)
 check(building.get_meta("construction_remaining") == 1.0, "Default range blocks remote construction")
 registry.execute("build_range 1000")
 registry.execute("build_speed 2")
 c.advance_construction(0.25)
 check(is_equal_approx(building.get_meta("construction_remaining"), 0.5), "Build range and speed affect existing jobs")
 registry.execute("build_instant true")
 c.advance_construction(0)
 check(building.get_meta("construction_remaining") == 0 and building.modulate.a == 1, "Instant build completes work without time passing")
 c.cancel()
 c.set_tool(1)
 c.advance_demolition(4, building.position, true)
 check(not building.is_queued_for_deletion(), "Default demolition range still blocks remote work")
 registry.execute("demolition_range 1000")
 registry.execute("demolition_speed 2")
 await physics_frame
 c.advance_demolition(1.49, building.position, true)
 check(not building.is_queued_for_deletion(), "Double-speed screwdriver still observes remaining duration")
 c.advance_demolition(0.02, building.position, true)
 check(building.is_queued_for_deletion(), "Demolition speed changes actual removal time")
 await physics_frame
 registry.execute("build_range 1")
 registry.execute("build_range_enabled false")
 c.begin(load("res://data/buildings/small_container.tres"))
 c.update_preview(Vector2(896, 896))
 check(c.confirm(), "Place fixture with instant construction")
 building = c._occupied[Vector2i(28, 28)]
 check(building.get_meta("construction_remaining") == 0, "Disabling build range allows remote instant completion")
 c.cancel()
 registry.execute("demolition_range 1")
 registry.execute("demolition_range_enabled false")
 registry.execute("demolition_instant true")
 await physics_frame
 c.advance_demolition(0, building.position, true)
 check(building.is_queued_for_deletion(), "Unlimited instant demolition works without elapsed time")
 registry.execute("cutter_range 300")
 check(c.cutter_reach == 300 and c._cutter_in_reach(Vector2(1800, 1200)), "Unlimited demolition also removes cutter distance limit")
 registry.execute("demolition_range_enabled true")
 check(not c._cutter_in_reach(Vector2(1800, 1200)), "Restoring distance limits restores cutter reach")
 check(registry.execute("build_instant").message == "build_instant = true" and registry.execute("stamina_enabled false").message == "stamina_enabled = false", "All boolean results use true and false")
 check(not registry.execute("build_instant on").ok and not registry.execute("sprint_enabled off").ok and not registry.execute("build_speed 0").ok and not registry.execute("demolition_range -1").ok, "Old toggle words and invalid numeric values are rejected")
 check(registry.execute("help").message.contains("build_range_enabled [true|false]"), "Help lists new settings with canonical boolean syntax")
 console.submit_command("restart")
 await process_frame
 await process_frame
 await physics_frame
 var fresh = current_scene.construction
 check(fresh.build_speed == 1 and fresh.demolition_speed == 1 and not fresh.build_instant and not fresh.demolition_instant and fresh.build_range_enabled and fresh.demolition_range_enabled and fresh.construction_reach == 128 and fresh.demolition_reach == 36 and fresh.cutter_reach == 128, "Restart restores all work settings")
 print("Building command failures: ", failures)
 quit(1 if failures else 0)
