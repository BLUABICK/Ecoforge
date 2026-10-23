extends SceneTree
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, text: String) -> void:
	print("PASS: " if ok else "FAIL: ", text)
	if not ok:
		failures += 1
func run() -> void:
	var world = preload("res://scenes/world/planet_preview.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	var environment = world.environment
	print("Grass coverage: ", 100.0 * environment.grass_cell_count / (environment.grass_cell_count + environment.ground_cell_count), "%")
	check(environment.ground.get_used_cells().size() == 120 * 80, "Atlas ground covers the complete playable map")
	check(environment.pools.size() == 3, "Three liquid surfaces replace the old placeholder blocks")
	check(environment.pools[0].get_meta("liquid_id") == &"water" and environment.pools[1].get_meta("liquid_id") == &"hydrochloric_acid", "Water and yellow hydrochloric acid remain distinct")
	check(environment.ground_cell_count > 9600 * 0.30 and environment.grass_cell_count > environment.ground_cell_count, "Grey soil occupies broad regions while red grass remains the majority")
	check(environment.transition_cell_count > 100, "Terrain-connect selects transition tiles along landscape edges")
	check(environment.ground.tile_set.get_terrain_sets_count() == 1 and environment.ground.tile_set.get_terrains_count(0) == 2, "Grass and stone are connected through actual TileMap terrains")
	for index in environment.pools.size():
		var pool = environment.pools[index]
		check(pool.get_child_count() == 2, "Liquid meets grass directly without extra bank strips")
		for y in range(int(pool.position.y) - 16, int(pool.position.y + pool.size.y) + 17, 16):
			for x in range(int(pool.position.x) - 16, int(pool.position.x + pool.size.x) + 17, 16):
				var coordinate: Vector2i = environment.ground.get_cell_atlas_coords(Vector2i(x / 16, y / 16))
				if coordinate.y != 0:
					check(false, "Terrain around every shoreline must be grass")
		check(pool.position == world.OBSTACLES[index].position and pool.size == world.OBSTACLES[index].size, "Liquid footprint matches existing blocked terrain")
		check(pool.outline.size() >= 32 and pool.collision.polygon == pool.outline, "Rounded shoreline and collision share exactly the same polygon")
		var corner_query := PhysicsPointQueryParameters2D.new()
		corner_query.position = pool.position + Vector2(2, 2)
		check(world.get_world_2d().direct_space_state.intersect_point(corner_query).is_empty(), "Old square corners are now walkable dry ground")
		var query := PhysicsPointQueryParameters2D.new()
		query.position = pool.position + pool.size * 0.5
		check(not world.get_world_2d().direct_space_state.intersect_point(query).is_empty(), "Liquid remains blocked for movement and construction")
	check(environment.ground.material is ShaderMaterial and environment.ground.material.shader != null, "Grass has a wind animation material")
	world.queue_free()
	await process_frame
	print("Planet environment failures: ", failures)
	quit(1 if failures else 0)
