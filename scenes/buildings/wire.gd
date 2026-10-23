extends StaticBody2D

var route := PackedVector2Array()
var connected_inputs: Array[Node2D] = []
var connected_outputs: Array[Node2D] = []
@export var route_width: float = 6.4
@export var route_color := Color(0.78, 0.48, 0.24)

func _ready() -> void:
	if route.is_empty():
		if get_meta("building_id", &"") == &"wire" and has_node("Direction"):
			get_node("Direction").rotation = PI
		return
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var line := Line2D.new()
	line.points = route
	line.width = route_width
	line.default_color = route_color
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	add_child(line)
	for index in route.size() - 1:
		var delta := route[index + 1] - route[index]
		var collision := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = Vector2(delta.length(), route_width)
		collision.shape = shape
		collision.position = (route[index] + route[index + 1]) * 0.5
		collision.rotation = delta.angle()
		add_child(collision)

func connection_ends() -> Array[Dictionary]:
	if route.is_empty():
		var direction := Vector2.UP.rotated(global_rotation)
		return [{"point": global_position + direction * 16, "direction": direction}, {"point": global_position - direction * 16, "direction": -direction}]
	return [{"point": to_global(route[0]), "direction": (route[0] - route[1]).normalized().rotated(global_rotation)}, {"point": to_global(route[-1]), "direction": (route[-1] - route[-2]).normalized().rotated(global_rotation)}]


func input_point() -> Vector2:
	return connection_ends()[0].point


func output_point() -> Vector2:
	return connection_ends()[1].point


func _draw() -> void:
	if route.is_empty() or get_meta("building_id", &"") != &"wire":
		return
	for index in route.size() - 1:
		var direction := (route[index + 1] - route[index]).normalized()
		var middle := (route[index] + route[index + 1]) * 0.5
		var side := direction.orthogonal() * 1.6
		draw_colored_polygon(PackedVector2Array([middle + direction * 2, middle - direction * 2 + side, middle - direction * 2 - side]), Color(0.95, 0.85, 0.55))
