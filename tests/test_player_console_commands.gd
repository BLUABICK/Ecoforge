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
 var player = world.get_node("Player2d")
 player.set_physics_process(false)
 var vitals = player.get_node("Vitals")
 var hud = world.get_node("HUD/PlayerHUD")
 check(registry.execute("help").message.contains("stamina_drain") and registry.execute("help").message.contains("restart"), "Help lists registered commands")
 check(registry.execute("help hp").message.contains("hp [value]") and not registry.execute("help missing").ok, "Help supports individual command lookup")
 var header_found := false
 for label in console._root.find_children("*", "Label", true, false):
  header_found = header_found or label.text == "КОНСОЛЬ"
 check(not header_found, "Console has no title label")
 check(hud._health_bar.position.y == 24 and hud._health_bar.anchor_top == 0 and hud._stamina_bar.position.y > hud._health_bar.position.y, "HP and stamina appear top left")
 check(registry.execute("max_hp 200").ok and registry.execute("hp 150").ok and vitals.health == 150 and hud._health_bar.max_value == 200 and hud._health_bar.value == 150, "HP setters update state and HUD")
 check(not registry.execute("hp 201").ok and vitals.health == 150, "Out-of-range HP cannot mutate state")
 registry.execute("max_hp 80")
 check(vitals.health == 80 and vitals.max_health == 80, "Lowering maximum clamps existing health")
 registry.execute("hp 0")
 check(not vitals.update_sprint(1, true, true), "Zero HP blocks sprinting")
 registry.execute("hp 80")
 check(vitals.update_sprint(0, true, true), "Setting positive HP revives character")
 registry.execute("max_stamina 200")
 registry.execute("stamina 150")
 check(vitals.stamina == 150 and vitals.max_stamina == 200 and hud._stamina_bar.value == 150, "Stamina and capacity setters update HUD")
 registry.execute("stamina 0")
 registry.execute("stamina_drain false")
 check(vitals.update_sprint(1, true, true), "Disabling drain allows sprinting even at zero reserve")
 registry.execute("stamina 120")
 vitals.update_sprint(1, true, true)
 check(vitals.stamina >= 120, "Infinite stamina mode does not spend reserve")
 registry.execute("stamina_drain true")
 registry.execute("stamina 100")
 vitals.update_sprint(1, true, true)
 check(vitals.stamina == 80, "Re-enabling drain restores normal consumption")
 registry.execute("stamina 0")
 registry.execute("stamina_regen 50")
 vitals.update_sprint(1, false, false)
 check(vitals.stamina == 50, "Recovery command affects actual regeneration")
 registry.execute("stamina_regen 0")
 vitals.update_sprint(2, false, false)
 check(vitals.stamina == 50, "Zero regeneration disables recovery")
 registry.execute("stamina_enabled false")
 registry.execute("stamina 0")
 check(not hud._stamina_bar.visible and vitals.update_sprint(1, true, true) and vitals.stamina == 0, "Disabling stamina hides bar and freezes reserve without blocking sprint")
 registry.execute("sprint_enabled false")
 check(not vitals.update_sprint(1, true, true), "Sprint toggle overrides disabled stamina")
 registry.execute("sprint_enabled true")
 registry.execute("sprint_speed 600")
 check(is_equal_approx(player.move_speed * player.sprint_multiplier, 600), "Sprint speed uses actual pixels per second")
 registry.execute("stamina_enabled true")
 check(hud._stamina_bar.visible and not vitals.update_sprint(0, true, true), "Re-enabling stamina restores exhausted reserve")
 var before: float = vitals.max_stamina
 check(not registry.execute("max_stamina 0").ok and not registry.execute("stamina_regen -1").ok and not registry.execute("sprint_speed nope").ok and not registry.execute("sprint_enabled maybe").ok and not registry.execute("hp nan").ok and vitals.max_stamina == before, "Bad numbers, infinities and toggle values are rejected")
 check(registry.execute("hp").message.get_slice("=", 1).strip_edges().to_float() == 80.0, "No-argument settings report current values")
 console.submit_command("restart")
 await process_frame
 await process_frame
 await physics_frame
 var fresh = current_scene.get_node("Player2d")
 check(fresh.vitals.max_health == 100 and fresh.vitals.stamina_recovery == 18 and fresh.vitals.stamina_enabled and fresh.vitals.sprint_enabled and is_equal_approx(fresh.move_speed * fresh.sprint_multiplier, 336), "Restart resets all player tuning to scene defaults")
 print("Player command failures: ", failures)
 quit(1 if failures else 0)
