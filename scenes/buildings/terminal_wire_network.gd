extends RefCounted
const EPSILON := 0.25
static func ready_building(building: Node2D) -> bool:
	return is_instance_valid(building) and not building.is_queued_for_deletion() and float(building.get_meta("construction_remaining", 0.0)) <= 0.0
static func points(wire: Node2D) -> PackedVector2Array:
	var result := PackedVector2Array()
	if wire.route.is_empty():
		return PackedVector2Array([wire.input_point(), wire.output_point()])
	for point in wire.route:
		result.append(wire.to_global(point))
	return result
static func touches_device(path: PackedVector2Array, device: Node2D) -> bool:
	var collision := device.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision == null or not collision.shape is RectangleShape2D or path.size() < 2:
		return false
	var half: Vector2 = collision.shape.size * 0.5
	for point in [path[0], path[-1]]:
		var local: Vector2 = collision.to_local(point)
		if absf(local.x) <= half.x + EPSILON and absf(local.y) <= half.y + EPSILON and (absf(absf(local.x) - half.x) <= EPSILON or absf(absf(local.y) - half.y) <= EPSILON):
			return true
	return false
static func touches_wire(a: PackedVector2Array, b: PackedVector2Array) -> bool:
	for endpoint in [a[0], a[-1]]:
		for index in b.size() - 1:
			if endpoint.distance_to(Geometry2D.get_closest_point_to_segment(endpoint, b[index], b[index + 1])) <= EPSILON:
				return true
	for endpoint in [b[0], b[-1]]:
		for index in a.size() - 1:
			if endpoint.distance_to(Geometry2D.get_closest_point_to_segment(endpoint, a[index], a[index + 1])) <= EPSILON:
				return true
	return false
static func find_storage(terminal: Node2D) -> Node2D:
	var wires: Array[PackedVector2Array] = []
	var containers: Array[Node2D] = []
	for building in terminal.get_tree().get_nodes_in_group("buildings"):
		if not ready_building(building):
			continue
		if building.get_meta("building_id", &"") == &"wire" and building.visible:
			wires.append(points(building))
		elif building.get_meta("building_id", &"") == &"cargo_container":
			containers.append(building)
	var pending: Array[int] = []
	var visited: Array[int] = []
	for index in wires.size():
		if touches_device(wires[index], terminal):
			pending.append(index)
			visited.append(index)
	while not pending.is_empty():
		var current: int = pending.pop_back()
		for container in containers:
			if touches_device(wires[current], container):
				return container
		for index in wires.size():
			if not visited.has(index) and touches_wire(wires[current], wires[index]):
				visited.append(index)
				pending.append(index)
	return null