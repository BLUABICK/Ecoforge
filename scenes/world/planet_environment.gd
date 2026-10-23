extends Node2D
## Atlas-backed terrain transitions, selected through Godot's terrain-connect TileMap API.
const ATLAS_PATH := "res://assets/sprites/back_map.png"
const MAP_SIZE := Vector2i(1920, 1280)
const TILE_SIZE := 16
const LiquidPool = preload("res://scenes/world/liquid_pool.gd")
const GRASS_SHADER = preload("res://scenes/world/grass_wind.gdshader")
const PEERING := [TileSet.CELL_NEIGHBOR_TOP_SIDE, TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER, TileSet.CELL_NEIGHBOR_RIGHT_SIDE, TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER, TileSet.CELL_NEIGHBOR_BOTTOM_SIDE, TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER, TileSet.CELL_NEIGHBOR_LEFT_SIDE, TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER]
var ground: TileMapLayer
var pools: Array[Node2D] = []
var atlas: Texture2D
var grass_cell_count := 0
var ground_cell_count := 0
var transition_cell_count := 0

func build(obstacles: Array[Rect2]) -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	atlas = load(ATLAS_PATH) as Texture2D
	var source_image := atlas.get_image()
	if source_image.is_compressed():
		source_image.decompress()
	var tileset := _make_terrain_tileset(source_image)
	ground = TileMapLayer.new()
	ground.name = "ConnectedGrassAndStoneTerrain"
	ground.tile_set = tileset
	var grass_material := ShaderMaterial.new()
	grass_material.shader = GRASS_SHADER
	ground.material = grass_material
	add_child(ground)
	var all_cells: Array[Vector2i] = []
	var stone_cells: Array[Vector2i] = []
	for y in MAP_SIZE.y / TILE_SIZE:
		for x in MAP_SIZE.x / TILE_SIZE:
			var cell := Vector2i(x, y)
			var center := Vector2(cell * TILE_SIZE) + Vector2.ONE * TILE_SIZE * 0.5
			var stone := _is_stone_patch(center)
			for obstacle in obstacles:
				if obstacle.grow(40.0).has_point(center):
					stone = false
			all_cells.append(cell)
			if stone:
				stone_cells.append(cell)
	ground.set_cells_terrain_connect(all_cells, 0, 0, false)
	ground.set_cells_terrain_connect(stone_cells, 0, 1, false)
	ground_cell_count = stone_cells.size()
	grass_cell_count = all_cells.size() - ground_cell_count
	for cell in ground.get_used_cells():
		var coordinate := ground.get_cell_atlas_coords(cell)
		if coordinate.y > 0 and coordinate != Vector2i(15, 16):
			transition_cell_count += 1
	for index in obstacles.size():
		var pool := LiquidPool.new()
		pool.name = "HydrochloricAcid" if index == 1 else "Water%d" % (index + 1)
		pool.position = obstacles[index].position
		pool.size = obstacles[index].size
		pool.is_acid = index == 1
		pool.variant = index
		pool.add_to_group("liquid_surfaces")
		pool.set_meta("liquid_id", &"hydrochloric_acid" if index == 1 else &"water")
		add_child(pool)
		pool.build(atlas)
		pools.append(pool)

func _make_terrain_tileset(original: Image) -> TileSet:
	# The artist supplied a 3x3 patch at (0,80). Derive missing concave combinations
	# from those edge tiles without altering the source PNG.
	var sheet := Image.create(256, 272, false, Image.FORMAT_RGBA8)
	for variant in 3:
		sheet.blit_rect(original, Rect2i(variant * 16, 0, 16, 16), Vector2i(variant * 16, 0))
	for mask in 256:
		if not _valid_terrain_mask(mask):
			continue
		var origin := Vector2i(mask % 16, mask / 16 + 1) * TILE_SIZE
		for y in TILE_SIZE:
			for x in TILE_SIZE:
				var top := y < 8 and (mask & 1) == 0
				var right := x >= 8 and (mask & 4) == 0
				var bottom := y >= 8 and (mask & 16) == 0
				var left := x < 8 and (mask & 64) == 0
				var row := 0 if top else (2 if bottom else 1)
				var column := 0 if left else (2 if right else 1)
				var color := original.get_pixel(column * 16 + x, 80 + row * 16 + y)
				# Inner corners use the artist's red grass, with a small ragged lip.
				var corner_distance := 100
				if (mask & 1) != 0 and (mask & 64) != 0 and (mask & 128) == 0:
					corner_distance = mini(corner_distance, x + y)
				if (mask & 1) != 0 and (mask & 4) != 0 and (mask & 2) == 0:
					corner_distance = mini(corner_distance, 15 - x + y)
				if (mask & 16) != 0 and (mask & 4) != 0 and (mask & 8) == 0:
					corner_distance = mini(corner_distance, 30 - x - y)
				if (mask & 16) != 0 and (mask & 64) != 0 and (mask & 32) == 0:
					corner_distance = mini(corner_distance, x + 15 - y)
				if corner_distance < 5 + ((x * 3 + y * 7) % 3):
					color = original.get_pixel(x, y)
				sheet.set_pixelv(origin + Vector2i(x, y), color)
	var tileset := TileSet.new()
	tileset.tile_size = Vector2i.ONE * TILE_SIZE
	tileset.add_terrain_set()
	tileset.set_terrain_set_mode(0, TileSet.TERRAIN_MODE_MATCH_CORNERS_AND_SIDES)
	tileset.add_terrain(0)
	tileset.set_terrain_name(0, 0, "Red grass")
	tileset.add_terrain(0)
	tileset.set_terrain_name(0, 1, "Stone ground")
	var source := TileSetAtlasSource.new()
	source.texture = ImageTexture.create_from_image(sheet)
	source.texture_region_size = Vector2i.ONE * TILE_SIZE
	for variant in 3:
		var coordinate := Vector2i(variant, 0)
		source.create_tile(coordinate)
		var tile := source.get_tile_data(coordinate, 0)
		tile.terrain_set = 0
		tile.terrain = 0
		for peer in PEERING:
			tile.set_terrain_peering_bit(peer, 0)
	for mask in 256:
		if not _valid_terrain_mask(mask):
			continue
		var coordinate := Vector2i(mask % 16, mask / 16 + 1)
		source.create_tile(coordinate)
		var tile := source.get_tile_data(coordinate, 0)
		tile.terrain_set = 0
		tile.terrain = 1
		for bit in 8:
			tile.set_terrain_peering_bit(PEERING[bit], 1 if mask & (1 << bit) else 0)
	tileset.add_source(source, 0)
	return tileset


func _valid_terrain_mask(mask: int) -> bool:
	for corner in [Vector3i(2, 1, 4), Vector3i(8, 4, 16), Vector3i(32, 16, 64), Vector3i(128, 64, 1)]:
		if (mask & corner.x) != 0 and ((mask & corner.y) == 0 or (mask & corner.z) == 0):
			return false
	return true


func _is_stone_patch(point: Vector2) -> bool:
	# Broad, quiet land masses; no thin procedural paths or high-frequency stripes.
	var patches := [Vector4(280, 150, 360, 220), Vector4(1480, 300, 420, 300), Vector4(1430, 1130, 460, 240), Vector4(120, 1110, 240, 230)]
	for index in patches.size():
		var patch: Vector4 = patches[index]
		var offset := (point - Vector2(patch.x, patch.y)) / Vector2(patch.z, patch.w)
		var edge := 1.0 + sin(offset.angle() * 3.0 + index * 1.2) * 0.035
		if offset.length() < edge:
			return true
	return false
