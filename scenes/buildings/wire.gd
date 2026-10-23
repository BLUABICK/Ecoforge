extends StaticBody2D

var route := PackedVector2Array()
const WIDTH := 6.4
@export var route_color := Color(0.78, 0.48, 0.24)

func _ready() -> void:
	if route.is_empty():
		return
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var line := Line2D.new()
	line.points = route
	line.width = WIDTH
	line.default_color = route_color
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	add_child(line)
	for index in route.size() - 1:
		var delta := route[index + 1] - route[index]
		var collision := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = Vector2(delta.length(), WIDTH)
		collision.shape = shape
		collision.position = (route[index] + route[index + 1]) * 0.5
		collision.rotation = delta.angle()
		add_child(collision)

func connection_ends() -> Array[Dictionary]:
	if route.is_empty():
		var direction := Vector2.UP.rotated(global_rotation)
		return [{"point": global_position + direction * 16, "direction": direction}, {"point": global_position - direction * 16, "direction": -direction}]
	return [{"point": to_global(route[0]), "direction": (route[0] - route[1]).normalized().rotated(global_rotation)}, {"point": to_global(route[-1]), "direction": (route[-1] - route[-2]).normalized().rotated(global_rotation)}]
