extends Node2D
const LIQUID_SHADER = preload("res://scenes/world/liquid_surface.gdshader")
var size := Vector2.ZERO
var is_acid := false
var variant := 0
var outline := PackedVector2Array()
var collision: CollisionPolygon2D
var surface: Polygon2D

func build(atlas: Texture2D) -> void:
	var center := size * 0.5
	for index in 48:
		var angle := TAU * index / 48.0
		var radius := 0.94 + sin(angle * 3.0 + variant * 1.7) * 0.04 + cos(angle * 5.0 + variant) * 0.02
		var point := center + Vector2(cos(angle), sin(angle)) * center * radius
		if index == 24 and variant == 0:
			point = Vector2(0, center.y)
		outline.append((point * 0.5).round() * 2.0)
	surface = Polygon2D.new()
	surface.name = "LiquidSurface"
	surface.polygon = outline
	surface.texture = atlas
	var coordinates := PackedVector2Array()
	for point in outline:
		coordinates.append(point / size * atlas.get_size())
	surface.uv = coordinates
	var material := ShaderMaterial.new()
	material.shader = LIQUID_SHADER
	material.set_shader_parameter("terrain_atlas", atlas)
	material.set_shader_parameter("atlas_size", atlas.get_size())
	material.set_shader_parameter("region_px", Vector4(56, 136, 32, 32) if is_acid else Vector4(8, 136, 32, 32))
	material.set_shader_parameter("pool_size", size)
	material.set_shader_parameter("is_acid", is_acid)
	surface.material = material
	add_child(surface)
	var body := StaticBody2D.new()
	body.name = "LiquidCollision"
	body.add_to_group("liquid_boundaries")
	collision = CollisionPolygon2D.new()
	collision.polygon = outline
	body.add_child(collision)
	add_child(body)
