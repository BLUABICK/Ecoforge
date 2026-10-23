extends Node2D

signal mode_changed(active: bool)
signal feedback(message: String)
signal building_placed(building: Node2D)
signal wire_cut(length: float)
var _last_cut_cursor := Vector2.ZERO
var _cut_preview := PackedVector2Array()
var _cut_preview_width: float = WIRE_STEP

const PipeGeometry = preload("res://scenes/buildings/wire.gd")
const CELL_SIZE: int = 32
const MAX_CONNECTION_LENGTH: float = CELL_SIZE
const WIRE_STEP: float = CELL_SIZE / 4.0
const MAX_WIRE_CELLS: int = 4
var _drawing_wire := false
var _wire_start := Vector2.ZERO
var _wire_start_connected := false
var bounds := Rect2(Vector2.ZERO, Vector2(1920, 1280))
var definition: Resource
var active: bool = false
var turns: int = 0
var _requested_turns: int = 0
var _last_preview_turns: int = 0
var cell := Vector2i.ZERO
var placement_position := Vector2.ZERO
var _cursor_position := Vector2.ZERO
var free_build_mode: bool = false
var _wire_route := PackedVector2Array()
var _route_exclude: Array[RID] = []
var _free_buildings: Array[Node2D] = []
var can_place: bool = false
signal demolition_progress(text: String)
var actor: CharacterBody2D
var selected_tool: int = 0
var _using_tool: bool = false
var _demolition_target: Node2D
var _demolition_elapsed: float = 0.0

var _occupied: Dictionary[Vector2i, Node2D] = {}


func begin(source: Resource) -> void:
	_drawing_wire = false
	definition = source
	turns = 0
	_requested_turns = 0
	_last_preview_turns = 0
	active = true
	update_preview(get_global_mouse_position())
	mode_changed.emit(true)


func cancel() -> void:
	_drawing_wire = false
	active = false
	can_place = false
	queue_redraw()
	mode_changed.emit(false)


func dimensions() -> Vector2i:
	return Vector2i(definition.footprint.y, definition.footprint.x) if turns % 2 == 1 else definition.footprint


func update_preview(world_position: Vector2) -> void:
	if turns != _last_preview_turns:
		_requested_turns = turns
	turns = _requested_turns
	_wire_route.clear()
	_route_exclude.clear()
	cell = Vector2i((world_position / CELL_SIZE).floor())
	_cursor_position = world_position
	placement_position = world_position
	if _drawing_wire:
		_update_drawn_wire(world_position)
		can_place = _valid_location()
		queue_redraw()
		return
	if definition != null and definition.length_axis_snap and not free_build_mode:
		if turns % 2 == 1:
			placement_position.x = (cell.x + 0.5) * CELL_SIZE
		else:
			placement_position.y = (cell.y + 0.5) * CELL_SIZE
	if definition != null and definition.free_placement and not definition.length_axis_snap and not free_build_mode:
		var divisions := 4 if definition.id in [&"wire", &"pipe"] else 5
		var step := float(CELL_SIZE) / divisions
		var cell_origin := Vector2(cell * CELL_SIZE)
		var local_position := world_position - cell_origin
		var subcell := Vector2i((local_position / step).floor())
		subcell.x = clampi(subcell.x, 0, divisions - 1)
		subcell.y = clampi(subcell.y, 0, divisions - 1)
		placement_position = cell_origin + (Vector2(subcell) + Vector2(0.5, 0.5)) * step
	if definition != null and definition.id in [&"wire", &"pipe"] and not free_build_mode and not Input.is_key_pressed(KEY_CTRL):
		_snap_wire_end(world_position)
		_find_wire_bridge(world_position)
		if _wire_route.is_empty() and definition.id == &"pipe":
			_find_short_pipe_bridge(world_position)
		if _wire_route.is_empty():
			_find_corner_bridge(world_position)
	can_place = _valid_location()
	if definition != null and definition.id in [&"wire", &"pipe"] and _wire_route.is_empty():
		can_place = _wire_marker_is_clear()
	_last_preview_turns = turns
	queue_redraw()


func _process(_delta: float) -> void:
	if active:
		update_preview(get_global_mouse_position())
	elif selected_tool == 2:
		_update_cut_preview(get_global_mouse_position())


func _wire_marker_is_clear() -> bool:
	var marker_size := Vector2(WIRE_STEP, WIRE_STEP)
	if definition.id == &"pipe":
		marker_size = Vector2.ONE * definition.preview_size.x
	var marker := _cursor_position if free_build_mode else (_cursor_position / WIRE_STEP).floor() * WIRE_STEP + marker_size * 0.5
	if not bounds.encloses(Rect2(marker - marker_size * 0.5, marker_size)):
		return false
	var shape := RectangleShape2D.new()
	shape.size = marker_size - Vector2.ONE * 0.2
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0, marker)
	return get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()


func _update_drawn_wire(cursor: Vector2) -> void:
	var offset := cursor - _wire_start
	var direction := Vector2.UP.rotated(_requested_turns * PI / 2.0)
	var distance := 0.0
	if absf(offset.x) > absf(offset.y):
		direction = Vector2(signf(offset.x), 0)
		distance = absf(offset.x)
	elif not is_zero_approx(offset.y):
		direction = Vector2(0, signf(offset.y))
		distance = absf(offset.y)
	var minimum_cells := 2 if definition.id == &"pipe" else 1
	var cells := maxi(roundi(distance / WIRE_STEP), minimum_cells)
	if not Input.is_key_pressed(KEY_CTRL):
		cells = mini(cells, MAX_WIRE_CELLS)
	var length := cells * WIRE_STEP
	var start := _wire_start
	if not free_build_mode and not _wire_start_connected:
		start -= direction * WIRE_STEP * 0.5
		if definition.id == &"pipe":
			start += Vector2(absf(direction.y), absf(direction.x)) * WIRE_STEP * 0.5
	_wire_route = PackedVector2Array([start, start + direction * length])
	placement_position = (_wire_route[0] + _wire_route[1]) * 0.5


func _start_wire_drawing(cursor: Vector2) -> void:
	_wire_start_connected = false
	_wire_start = cursor if free_build_mode else (cursor / WIRE_STEP).floor() * WIRE_STEP + Vector2.ONE * WIRE_STEP * 0.5
	if not free_build_mode and not Input.is_key_pressed(KEY_CTRL):
		var nearest := WIRE_STEP * 0.25
		for wire in _free_buildings:
			if not is_instance_valid(wire) or wire.is_queued_for_deletion() or wire.get_meta("building_id", &"") != definition.id:
				continue
			for connection in _available_ends(wire):
				var distance := cursor.distance_to(connection.point)
				if distance < nearest:
					nearest = distance
					_wire_start = connection.point
					_wire_start_connected = true
	_drawing_wire = true
	update_preview(cursor)


func _unhandled_key_input(event: InputEvent) -> void:
	if not active or not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.physical_keycode == KEY_X:
		free_build_mode = not free_build_mode
		update_preview(_cursor_position)
		feedback.emit("Свободная установка" if free_build_mode else "Привязка включена")
	elif event.physical_keycode == KEY_R:
		_requested_turns = (_requested_turns + 1) % 4
		turns = _requested_turns
		update_preview(_cursor_position)
		queue_redraw()
	elif event.keycode == KEY_ESCAPE:
		cancel()
	else:
		return
	get_viewport().set_input_as_handled()


func _available_ends(wire: Node2D) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for connection in wire.connection_ends():
		var probe := PhysicsPointQueryParameters2D.new()
		probe.position = connection.point + connection.direction * 0.5
		probe.exclude = [wire.get_rid()]
		if get_world_2d().direct_space_state.intersect_point(probe, 1).is_empty():
			result.append(connection)
	return result

func _snap_wire_end(cursor: Vector2) -> void:
	var best_position := placement_position
	var best_turns := turns
	var best_distance := 14.0
	var half_length: float = definition.preview_size.y * 0.5
	var requested_turns := turns
	var requested_direction := Vector2.UP.rotated(turns * PI / 2.0)
	for wire in _free_buildings:
		if not is_instance_valid(wire) or wire.is_queued_for_deletion() or wire.get_meta("building_id", &"") != definition.id:
			continue
		for connection in _available_ends(wire):
			var candidate: Vector2 = connection.point + connection.direction * half_length
			var distance := cursor.distance_to(candidate)
			var previous_turns := turns
			turns = 0 if absf(connection.direction.y) > 0.5 else 1
			placement_position = candidate
			if distance < best_distance and _valid_location():
				best_position = candidate
				best_turns = turns
				best_distance = distance
			turns = previous_turns
			if absf(requested_direction.dot(connection.direction)) < 0.1:
				var half_width: float = definition.preview_size.x * 0.5
				for side in [-1.0, 1.0]:
					var corner_position: Vector2 = connection.point + connection.direction * half_width + requested_direction * (half_length - half_width) * side
					var corner_distance := cursor.distance_to(corner_position)
					if corner_distance >= best_distance:
						continue
					turns = requested_turns
					placement_position = corner_position
					if _valid_location():
						best_position = corner_position
						best_turns = requested_turns
						best_distance = corner_distance
					turns = previous_turns
	placement_position = best_position
	turns = best_turns

func _valid_location() -> bool:
	if definition == null:
		return false
	if not _wire_route.is_empty():
		if definition.id in [&"wire", &"pipe"]:
			var length := 0.0
			for index in _wire_route.size() - 1:
				length += _wire_route[index].distance_to(_wire_route[index + 1])
			var minimum_length: float = WIRE_STEP * 2.0 if definition.id == &"pipe" else WIRE_STEP
			if definition.id == &"pipe" and _route_exclude.size() == 2:
				minimum_length = 0.1
			if length < minimum_length - 0.01 or length > _connection_limit() + 0.01:
				return false
		return _route_is_clear(_wire_route, _route_exclude)
	var size_cells := dimensions()
	var rect := Rect2(Vector2(cell * CELL_SIZE), Vector2(size_cells * CELL_SIZE))
	if definition.free_placement or free_build_mode:
		var wire_size: Vector2 = definition.preview_size if definition.preview_size != Vector2.ZERO else Vector2(definition.footprint * CELL_SIZE)
		if turns % 2 == 1:
			wire_size = Vector2(wire_size.y, wire_size.x)
		rect = Rect2(placement_position - wire_size * 0.5, wire_size)
	if not bounds.encloses(rect):
		return false
	for x in size_cells.x:
		for y in size_cells.y:
			if not definition.free_placement and not free_build_mode and _occupied.has(cell + Vector2i(x, y)):
				return false
	var shape := RectangleShape2D.new()
	shape.size = rect.size - Vector2.ONE * 0.2
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0, rect.get_center())
	return get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()


func confirm() -> bool:
	if not active:
		return false
	can_place = _valid_location()
	if not can_place:
		feedback.emit("Место занято или за границей карты")
		queue_redraw()
		return false
	var building := definition.scene.instantiate() as Node2D
	var size_cells := dimensions()
	building.position = placement_position if definition.free_placement or free_build_mode else Vector2(cell * CELL_SIZE) + Vector2(size_cells * CELL_SIZE) / 2.0
	building.rotation = turns * PI / 2.0
	building.set_meta("building_id", definition.id)
	if not _wire_route.is_empty():
		building.position = Vector2.ZERO
		building.rotation = 0.0
		building.route = _wire_route.duplicate()
	get_parent().add_child(building)
	if definition.free_placement or free_build_mode:
		_free_buildings.append(building)
	else:
		for x in size_cells.x:
			for y in size_cells.y:
				_occupied[cell + Vector2i(x, y)] = building
	_refresh_wire_connections()
	building_placed.emit(building)
	feedback.emit("Здание установлено")
	_drawing_wire = false
	update_preview(_cursor_position)
	return true


func _draw() -> void:
	if not active and selected_tool == 2:
		for index in range(0, _cut_preview.size(), 2):
			draw_line(_cut_preview[index], _cut_preview[index + 1], Color(1.0, 0.25, 0.18, 0.85), _cut_preview_width)
			draw_line(_cut_preview[index], _cut_preview[index + 1], Color(1.0, 0.9, 0.5), 1.0)
		return
	if not active or definition == null:
		return
	var size_cells := dimensions()
	var origin := Vector2(cell * CELL_SIZE)
	var tint := Color(0.5, 0.9, 0.7, 0.8) if can_place else Color(0.95, 0.35, 0.35, 0.8)
	if definition.free_placement or free_build_mode:
		var wire_size: Vector2 = definition.preview_size if definition.preview_size != Vector2.ZERO else Vector2(definition.footprint * CELL_SIZE)
		if turns % 2 == 1:
			wire_size = Vector2(wire_size.y, wire_size.x)
		if definition.id in [&"wire", &"pipe"] and not free_build_mode:
			var divisions := 4 if definition.id in [&"wire", &"pipe"] else 5
			var step := float(CELL_SIZE) / divisions
			var grid_origin := origin - Vector2(CELL_SIZE, CELL_SIZE)
			for index in range(divisions * 3 + 1):
				var offset := index * step
				var grid_color := Color(0.8, 0.85, 0.85, 0.45 if index % divisions == 0 else 0.18)
				draw_line(grid_origin + Vector2(offset, 0), grid_origin + Vector2(offset, CELL_SIZE * 3), grid_color)
				draw_line(grid_origin + Vector2(0, offset), grid_origin + Vector2(CELL_SIZE * 3, offset), grid_color)
		if definition.id in [&"wire", &"pipe"] and not _drawing_wire and _wire_route.is_empty():
			var marker_size := Vector2(WIRE_STEP, WIRE_STEP)
			if definition.id == &"pipe":
				marker_size = Vector2.ONE * definition.preview_size.x
			var marker := _cursor_position if free_build_mode else (_cursor_position / WIRE_STEP).floor() * WIRE_STEP + marker_size * 0.5
			draw_rect(Rect2(marker - marker_size * 0.5, marker_size), tint)
		elif not _wire_route.is_empty():
			draw_polyline(PipeGeometry.rounded_route(_wire_route, definition.preview_size.x * 0.5) if definition.id == &"pipe" else _wire_route, tint, definition.preview_size.x)
			if definition.id in [&"wire", &"pipe"]:
				for index in _wire_route.size() - 1:
					if _wire_route[index].distance_to(_wire_route[index + 1]) < 6.0:
						continue
					var direction := (_wire_route[index + 1] - _wire_route[index]).normalized()
					var middle := (_wire_route[index] + _wire_route[index + 1]) * 0.5
					var side := direction.orthogonal() * 1.6
					draw_colored_polygon(PackedVector2Array([middle + direction * 2, middle - direction * 2 + side, middle - direction * 2 - side]), Color(0.95, 0.85, 0.55))
		else:
			draw_rect(Rect2(placement_position - wire_size * 0.5, wire_size), tint)
		return
	for x in range(-1, size_cells.x + 2):
		draw_line(origin + Vector2(x * CELL_SIZE, -CELL_SIZE), origin + Vector2(x * CELL_SIZE, (size_cells.y + 1) * CELL_SIZE), Color(0.8, 0.85, 0.85, 0.25))
	for y in range(-1, size_cells.y + 2):
		draw_line(origin + Vector2(-CELL_SIZE, y * CELL_SIZE), origin + Vector2((size_cells.x + 1) * CELL_SIZE, y * CELL_SIZE), Color(0.8, 0.85, 0.85, 0.25))
	var rect := Rect2(origin, Vector2(size_cells * CELL_SIZE))
	draw_rect(rect, Color(tint, 0.2))
	draw_rect(rect, tint, false, 2.0)
	var center := rect.get_center()
	if definition.preview_size != Vector2.ZERO:
		var preview_size: Vector2 = definition.preview_size
		if turns % 2 == 1:
			preview_size = Vector2(preview_size.y, preview_size.x)
		draw_rect(Rect2(center - preview_size * 0.5, preview_size), tint)
		return
	var direction := Vector2.UP.rotated(turns * PI / 2.0)
	draw_line(center, center + direction * 20.0, tint, 3.0)
	draw_circle(center + direction * 20.0, 4.0, tint)


func _unhandled_input(event: InputEvent) -> void:
	if not active and selected_tool == 2 and event is InputEventMouseMotion and _using_tool and Input.is_physical_key_pressed(KEY_X):
		_sweep_cut_wires(get_canvas_transform().affine_inverse() * event.position)
		get_viewport().set_input_as_handled()
		return
	if not active and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_using_tool = true
		if selected_tool == 2:
			_last_cut_cursor = get_canvas_transform().affine_inverse() * event.position
			cut_wire_at(_last_cut_cursor)
			get_viewport().set_input_as_handled()
		return
	if not active or not event is InputEventMouseButton or not event.pressed:
		return
	if event.button_index == MOUSE_BUTTON_LEFT:
		var cursor: Vector2 = get_canvas_transform().affine_inverse() * event.position
		if definition.id in [&"wire", &"pipe"]:
			update_preview(cursor)
			if definition.id == &"pipe" and not _wire_route.is_empty() and _route_exclude.size() == 2:
				confirm()
			else:
				_start_wire_drawing(cursor)
		else:
			update_preview(cursor)
			confirm()
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		cancel()
	else:
		return
	get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		if active and _drawing_wire:
			update_preview(get_canvas_transform().affine_inverse() * event.position)
			confirm()
			_drawing_wire = false
			update_preview(_cursor_position)
			get_viewport().set_input_as_handled()
		_using_tool = false
		_reset_demolition()


func _physics_process(delta: float) -> void:
	if selected_tool == 2:
		if _using_tool and Input.is_physical_key_pressed(KEY_X):
			_sweep_cut_wires(get_global_mouse_position())
		return
	advance_demolition(delta, get_global_mouse_position(), _using_tool)


func advance_demolition(delta: float, cursor: Vector2, held: bool) -> void:
	if not held or active or not is_instance_valid(actor) or actor.menu_open or actor.vitals.health <= 0.0 or selected_tool < 0 or selected_tool > 1 or get_viewport().gui_get_hovered_control() != null:
		_reset_demolition()
		return
	var point := PhysicsPointQueryParameters2D.new()
	point.position = cursor
	var candidate: Node2D
	for hit in get_world_2d().direct_space_state.intersect_point(point, 32):
		if _occupied.values().has(hit.collider) or _free_buildings.has(hit.collider):
			candidate = hit.collider
			break
	if candidate == null or not _within_tool_reach(candidate):
		_reset_demolition()
		return
	if candidate != _demolition_target:
		_reset_demolition()
		_demolition_target = candidate
	_demolition_elapsed += delta
	var duration := 0.6 if selected_tool == 0 else 3.0
	var verb := "Разрушение" if selected_tool == 0 else "Разборка"
	demolition_progress.emit("%s: %d%%" % [verb, mini(100, int(_demolition_elapsed / duration * 100.0))])
	if _demolition_elapsed >= duration:
		remove_building(candidate)
		feedback.emit("Постройка разрушена" if selected_tool == 0 else "Постройка разобрана")
		_using_tool = false
		_reset_demolition()


func _within_tool_reach(building: Node2D) -> bool:
	var collision := actor.get_node("InteractionArea/CollisionShape2D") as CollisionShape2D
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = collision.shape
	query.transform = collision.global_transform
	query.exclude = [actor.get_rid()]
	var nearby := false
	for hit in get_world_2d().direct_space_state.intersect_shape(query, 256):
		if hit.collider == building:
			nearby = true
	if not nearby:
		return false
	var ray := PhysicsRayQueryParameters2D.create(actor.global_position, building.global_position)
	ray.exclude = [actor.get_rid()]
	var obstruction := get_world_2d().direct_space_state.intersect_ray(ray)
	return not obstruction.is_empty() and obstruction.collider == building


func remove_building(building: Node2D) -> void:
	_free_buildings.erase(building)
	for occupied_cell in _occupied.keys():
		if _occupied[occupied_cell] == building:
			_occupied.erase(occupied_cell)
	building.queue_free()
	_refresh_wire_connections()


func _reset_demolition() -> void:
	_demolition_target = null
	_demolition_elapsed = 0.0
	demolition_progress.emit("")


func set_tool(index: int) -> void:
	_cut_preview.clear()
	queue_redraw()
	selected_tool = index
	_using_tool = false
	_reset_demolition()
















func _route_is_clear(points: PackedVector2Array, excluded: Array[RID]) -> bool:
	if definition.id == &"pipe":
		points = PipeGeometry.rounded_route(points, definition.preview_size.x * 0.5)
		for source in _free_buildings:
			if not is_instance_valid(source) or not excluded.has(source.get_rid()):
				continue
			var source_points := PackedVector2Array()
			if source.route.is_empty():
				source_points = PackedVector2Array([source.input_point(), source.output_point()])
			else:
				for point in source.route:
					source_points.append(source.to_global(point))
			for index in points.size() - 1:
				var sample := (points[index] + points[index + 1]) * 0.5
				for segment in source_points.size() - 1:
					var delta := source_points[segment + 1] - source_points[segment]
					if delta.length_squared() < 0.001:
						continue
					var projection := (sample - source_points[segment]).dot(delta) / delta.length_squared()
					if projection > 0.001 and projection < 0.999 and sample.distance_to(source_points[segment] + delta * projection) < source.route_width * 0.5 - 0.1:
						return false
	for index in points.size() - 1:
		var delta := points[index + 1] - points[index]
		if delta.length() < 0.01:
			return false
		var shape := RectangleShape2D.new()
		shape.size = Vector2(delta.length() - 0.1, definition.preview_size.x - 0.2)
		var query := PhysicsShapeQueryParameters2D.new()
		query.shape = shape
		query.transform = Transform2D(delta.angle(), (points[index] + points[index + 1]) * 0.5)
		query.exclude = excluded
		var extent: Vector2 = Vector2(absf(delta.x), absf(delta.y)) * 0.5 + Vector2.ONE * definition.preview_size.x * 0.5
		if not bounds.encloses(Rect2(query.transform.origin - extent, extent * 2)):
			return false
		if not get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty():
			return false
	return true

func _find_wire_bridge(cursor: Vector2) -> void:
	var wires: Array[Node2D] = []
	for wire in _free_buildings:
		if is_instance_valid(wire) and not wire.is_queued_for_deletion() and wire.get_meta("building_id", &"") == definition.id and wire.has_method("connection_ends"):
			for connection in _available_ends(wire):
				if cursor.distance_to(connection.point) <= _connection_limit() + 14.0:
					wires.append(wire)
					break
	var best_score := INF
	for first_index in wires.size():
		for second_index in range(first_index + 1, wires.size()):
			var first := wires[first_index]
			var second := wires[second_index]
			for a in _available_ends(first):
				for b in _available_ends(second):
					var offset: Vector2 = b.point - a.point
					var length := absf(offset.x) + absf(offset.y)
					if length < (0.1 if definition.id == &"pipe" else definition.preview_size.x) or length > _connection_limit() or absf(offset.x) < 0.1 or absf(offset.y) < 0.1:
						continue
					var points := PackedVector2Array([a.point])
					if absf(a.direction.dot(b.direction)) < 0.1:
						points.append(Vector2(a.point.x, b.point.y) if absf(a.direction.y) > 0.5 else Vector2(b.point.x, a.point.y))
					else:
						if a.direction.dot(b.direction) > -0.9:
							continue
						if absf(a.direction.y) > 0.5:
							var middle: float = (a.point.y + b.point.y) * 0.5
							points.append(Vector2(a.point.x, middle))
							points.append(Vector2(b.point.x, middle))
						else:
							var middle: float = (a.point.x + b.point.x) * 0.5
							points.append(Vector2(middle, a.point.y))
							points.append(Vector2(middle, b.point.y))
					points.append(b.point)
					if (points[1] - points[0]).normalized().dot(a.direction) < 0.9 or (points[-2] - points[-1]).normalized().dot(b.direction) < 0.9:
						continue
					var distance := INF
					for index in points.size() - 1:
						distance = minf(distance, cursor.distance_to(Geometry2D.get_closest_point_to_segment(cursor, points[index], points[index + 1])))
					if distance > 14.0:
						continue
					var excluded: Array[RID] = [first.get_rid(), second.get_rid()]
					var score := distance + length * 0.05
					if score < best_score and _route_is_clear(points, excluded):
						best_score = score
						if definition.id == &"pipe" and second.output_point().is_equal_approx(points[-1]):
							points.reverse()
						_wire_route = points
						_route_exclude = excluded





func _find_corner_bridge(cursor: Vector2) -> void:
	var nearby: Array[Node2D] = []
	for building in _free_buildings:
		if not is_instance_valid(building) or building.is_queued_for_deletion() or building.get_meta("building_id", &"") != definition.id:
			continue
		for connection in _available_ends(building):
			if cursor.distance_to(connection.point) < _connection_limit() + 14.0:
				nearby.append(building)
				break
	var best_score := INF
	for first_index in nearby.size():
		for second_index in range(first_index + 1, nearby.size()):
			var first := nearby[first_index]
			var second := nearby[second_index]
			for a in _available_ends(first):
				for b in _available_ends(second):
					if a.point.distance_to(b.point) < 0.1 or a.point.distance_to(b.point) > _connection_limit():
						continue
					var start: Vector2 = a.point + a.direction * (definition.preview_size.x * 0.25 if definition.id == &"pipe" else definition.preview_size.x)
					var finish: Vector2 = b.point + b.direction * (definition.preview_size.x * 0.25 if definition.id == &"pipe" else definition.preview_size.x)
					for corner in [Vector2(start.x, finish.y), Vector2(finish.x, start.y)]:
						var points := PackedVector2Array()
						for point in [a.point, start, corner, finish, b.point]:
							if points.is_empty() or not points[-1].is_equal_approx(point):
								points.append(point)
						var length := 0.0
						var distance := INF
						for index in points.size() - 1:
							length += points[index].distance_to(points[index + 1])
							distance = minf(distance, cursor.distance_to(Geometry2D.get_closest_point_to_segment(cursor, points[index], points[index + 1])))
						if length > _connection_limit() or distance > 14.0:
							continue
						# Only the end caps may touch the two source objects.
						var enters_source := false
						for index in points.size() - 1:
							var midpoint := (points[index] + points[index + 1]) * 0.5
							for source in [first, second]:
								if source.route.is_empty() and Rect2(-definition.preview_size * 0.5 + Vector2.ONE * 0.1, definition.preview_size - Vector2.ONE * 0.2).has_point(source.to_local(midpoint)):
									enters_source = true
						if enters_source:
							continue
						var excluded: Array[RID] = [first.get_rid(), second.get_rid()]
						var score := distance + length * 0.1
						if score < best_score and _route_is_clear(points, excluded):
							best_score = score
							if definition.id == &"pipe" and second.output_point().is_equal_approx(points[-1]):
								points.reverse()
							_wire_route = points
							_route_exclude = excluded


func _refresh_wire_connections() -> void:
	var wires: Array[Node2D] = []
	for wire in _free_buildings:
		if is_instance_valid(wire) and not wire.is_queued_for_deletion() and wire.get_meta("building_id", &"") in [&"wire", &"pipe"]:
			wire.connected_inputs.clear()
			wire.connected_outputs.clear()
			wires.append(wire)
	for source in wires:
		for target in wires:
			if source == target or source.get_meta("building_id") != target.get_meta("building_id"):
				continue
			if source.output_point().distance_to(target.input_point()) < 0.15:
				source.connected_outputs.append(target)
				target.connected_inputs.append(source)


func _connection_limit() -> float:
	if definition.id in [&"wire", &"pipe"]:
		return INF if Input.is_key_pressed(KEY_CTRL) else WIRE_STEP * MAX_WIRE_CELLS
	return MAX_CONNECTION_LENGTH


func _sweep_cut_wires(cursor: Vector2) -> void:
	var count := maxi(1, ceili(_last_cut_cursor.distance_to(cursor) / (WIRE_STEP * 0.5)))
	for index in range(1, count + 1):
		cut_wire_at(_last_cut_cursor.lerp(cursor, float(index) / count))
	_last_cut_cursor = cursor


func _update_cut_preview(cursor: Vector2) -> void:
	var plan := _wire_cut_plan(cursor)
	_cut_preview = plan.get("segments", PackedVector2Array())
	_cut_preview_width = plan.get("width", WIRE_STEP)
	queue_redraw()


func cut_wire_at(cursor: Vector2) -> bool:
	var plan := _wire_cut_plan(cursor)
	if plan.is_empty():
		return false
	var wire: Node2D = plan.wire
	var scene: PackedScene = load(wire.scene_file_path)
	for fragment in plan.fragments:
		var replacement: Node2D = scene.instantiate()
		replacement.route = fragment
		replacement.route_is_rounded = true
		replacement.route_width = wire.route_width
		replacement.route_color = wire.route_color
		replacement.set_meta("building_id", wire.get_meta("building_id"))
		get_parent().add_child(replacement)
		_free_buildings.append(replacement)
	remove_building(wire)
	wire_cut.emit(plan.removed)
	feedback.emit("Труба срезана" if wire.get_meta("building_id") == &"pipe" else "Провод срезан")
	_update_cut_preview(cursor)
	return true


func _wire_cut_plan(cursor: Vector2) -> Dictionary:
	if active or selected_tool != 2 or not is_instance_valid(actor) or actor.menu_open or actor.vitals.health <= 0 or get_viewport().gui_get_hovered_control() != null:
		return {}
	var area_shape := actor.get_node("InteractionArea/CollisionShape2D") as CollisionShape2D
	var local_cursor := area_shape.to_local(cursor)
	if local_cursor.length() > area_shape.shape.radius:
		return {}
	var cut_size: float = WIRE_STEP if Input.is_physical_key_pressed(KEY_X) else CELL_SIZE
	var cell_rect := Rect2((cursor / cut_size).floor() * cut_size, Vector2.ONE * cut_size)
	for wire in _free_buildings.duplicate():
		if not is_instance_valid(wire) or wire.is_queued_for_deletion() or wire.get_meta("building_id", &"") not in [&"wire", &"pipe"]:
			continue
		var points := PackedVector2Array()
		if wire.route.is_empty():
			points = PackedVector2Array([wire.input_point(), wire.output_point()])
		else:
			for point in wire.route:
				points.append(wire.to_global(point))
		var touched := false
		for index in points.size() - 1:
			if cursor.distance_to(Geometry2D.get_closest_point_to_segment(cursor, points[index], points[index + 1])) < wire.route_width * 0.5:
				touched = true
		if not touched:
			continue
		var ray := PhysicsRayQueryParameters2D.create(actor.global_position, cursor)
		var exclusions: Array[RID] = [actor.get_rid()]
		for building in get_tree().get_nodes_in_group("buildings"):
			if building.get_meta("building_id", &"") in [&"wire", &"pipe"]:
				exclusions.append(building.get_rid())
		ray.exclude = exclusions
		var hit := get_world_2d().direct_space_state.intersect_ray(ray)
		if not hit.is_empty() and hit.collider != wire:
			return {}
		var fragments: Array[PackedVector2Array] = []
		var removed := 0.0
		var segments := PackedVector2Array()
		for index in points.size() - 1:
			var a := points[index]
			var b := points[index + 1]
			var cut_rect := cell_rect
			if wire.route_width > WIRE_STEP:
				var padding: float = wire.route_width * 0.5
				if absf(b.x - a.x) > 0.01:
					cut_rect.position.y -= padding
					cut_rect.size.y += padding * 2
				else:
					cut_rect.position.x -= padding
					cut_rect.size.x += padding * 2
			var interval := _segment_cell_interval(a, b, cut_rect)
			if interval.x < 0:
				_append_wire_piece(fragments, a, b)
			else:
				var before := a.lerp(b, interval.x)
				var after := a.lerp(b, interval.y)
				_append_wire_piece(fragments, a, before)
				_append_wire_piece(fragments, after, b)
				removed += before.distance_to(after)
				segments.append(before)
				segments.append(after)
		if removed < 0.01:
			continue
		return {"wire": wire, "fragments": fragments, "removed": removed, "segments": segments, "width": wire.route_width}
	return {}


func _segment_cell_interval(a: Vector2, b: Vector2, rect: Rect2) -> Vector2:
	var start := 0.0
	var finish := 1.0
	var delta := b - a
	for axis in 2:
		if absf(delta[axis]) < 0.001:
			if a[axis] <= rect.position[axis] + 0.001 or a[axis] >= rect.end[axis] - 0.001:
				return Vector2(-1, -1)
		else:
			var first: float = (rect.position[axis] - a[axis]) / delta[axis]
			var last: float = (rect.end[axis] - a[axis]) / delta[axis]
			start = maxf(start, minf(first, last))
			finish = minf(finish, maxf(first, last))
	if finish - start < 0.001:
		return Vector2(-1, -1)
	return Vector2(start, finish)


func _append_wire_piece(fragments: Array[PackedVector2Array], a: Vector2, b: Vector2) -> void:
	if a.distance_to(b) < 0.01:
		return
	if not fragments.is_empty() and fragments[-1][-1].is_equal_approx(a):
		var joined := fragments[-1]
		joined.append(b)
		fragments[-1] = joined
	else:
		fragments.append(PackedVector2Array([a, b]))


func _find_short_pipe_bridge(cursor: Vector2) -> void:
	var pipes: Array[Node2D] = []
	for pipe in _free_buildings:
		if is_instance_valid(pipe) and not pipe.is_queued_for_deletion() and pipe.get_meta("building_id", &"") == &"pipe":
			for connection in _available_ends(pipe):
				if cursor.distance_to(connection.point) < 30.0:
					pipes.append(pipe)
					break
	var best_distance := 14.0
	for first_index in pipes.size():
		for second_index in range(first_index + 1, pipes.size()):
			var first := pipes[first_index]
			var second := pipes[second_index]
			for a in _available_ends(first):
				for b in _available_ends(second):
					var offset: Vector2 = b.point - a.point
					var length := offset.length()
					if length < 0.1 or length >= WIRE_STEP * 2.0:
						continue
					var direction := offset / length
					if direction.dot(a.direction) < 0.999 or direction.dot(b.direction) > -0.999:
						continue
					var distance := cursor.distance_to(Geometry2D.get_closest_point_to_segment(cursor, a.point, b.point))
					if distance >= best_distance:
						continue
					var points := PackedVector2Array([a.point, b.point])
					var excluded: Array[RID] = [first.get_rid(), second.get_rid()]
					if not _route_is_clear(points, excluded):
						continue
					if second.output_point().is_equal_approx(b.point):
						points.reverse()
					_wire_route = points
					_route_exclude = excluded
					best_distance = distance
