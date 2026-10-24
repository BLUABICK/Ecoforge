extends StaticBody2D

var route := PackedVector2Array()
var route_is_rounded := false
var connected_inputs: Array[Node2D] = []
var connected_outputs: Array[Node2D] = []
@export var route_width: float = 6.4
@export var route_color := Color(0.78, 0.48, 0.24)

func _ready() -> void:
	var caption := get_node_or_null("Name")
	if caption != null:
		caption.hide()
	if route.is_empty():
		if get_meta("building_id", &"") in [&"wire", &"pipe"] and has_node("Direction"):
			get_node("Direction").rotation = PI
		return
	if get_meta("building_id", &"") == &"pipe" and not route_is_rounded:
		route = rounded_route(route, route_width * 0.5)
		route_is_rounded = true
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var line := Line2D.new()
	line.show_behind_parent = true
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
	if route.is_empty() or get_meta("building_id", &"") not in [&"wire", &"pipe"]:
		return
	for index in route.size() - 1:
		if route[index].distance_to(route[index + 1]) < 6.0:
			continue
		var direction := (route[index + 1] - route[index]).normalized()
		var middle := (route[index] + route[index + 1]) * 0.5
		var side := direction.orthogonal() * minf(3.0, route_width * 0.3)
		draw_colored_polygon(PackedVector2Array([middle + direction * 3, middle - direction * 3 + side, middle - direction * 3 - side]), Color(1.0, 0.96, 0.72))


static func rounded_route(points: PackedVector2Array, radius: float) -> PackedVector2Array:
	if points.size() < 3:
		return points.duplicate()
	var result := PackedVector2Array([points[0]])
	for index in range(1, points.size() - 1):
		var corner := points[index]
		var incoming := corner - points[index - 1]
		var outgoing := points[index + 1] - corner
		if incoming.length() < 0.01 or outgoing.length() < 0.01:
			continue
		if absf(incoming.normalized().dot(outgoing.normalized())) > 0.999:
			result.append(corner)
			continue
		var distance := minf(radius, minf(incoming.length(), outgoing.length()) * 0.45)
		var before := corner - incoming.normalized() * distance
		var after := corner + outgoing.normalized() * distance
		result.append(before)
		for step in range(1, 9):
			var t := float(step) / 8.0
			result.append(before * (1.0 - t) * (1.0 - t) + corner * 2.0 * (1.0 - t) * t + after * t * t)
	result.append(points[-1])
	return result
