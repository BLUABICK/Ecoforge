extends Node2D

signal mode_changed(active: bool)
signal feedback(message: String)
signal building_placed(building: Node2D)
signal wire_cut(length: float)
var _last_cut_cursor := Vector2.ZERO
var _cut_preview := PackedVector2Array()
var _cut_preview_width: float = WIRE_STEP

const WorkVisual = preload("res://scenes/buildings/building_work_visual.gd")
const BUILD_SECONDS_PER_CELL := 0.5
@export var construction_reach: float = 128.0
# Temporarily disabled features; preserve implementations for later use.
@export var area_selection_enabled := false
@export var remote_placement_enabled := false
var build_speed := 1.0
var demolition_speed := 1.0
var build_instant := false
var demolition_instant := false
var build_range_enabled := true
var demolition_range_enabled := true
var demolition_reach := 36.0
var cutter_reach := 128.0
var _construction_jobs: Array[Node2D] = []
const SEGMENT_REVEAL_STEP := 0.06
var _segment_reveals: Array[Dictionary] = []
var _cut_tasks: Array[Dictionary] = []
var _demolition_queue: Array[Node2D] = []
var _cut_dragging := false
var _cut_drag_start := Vector2.ZERO
var _cut_drag_end := Vector2.ZERO

const PipeGeometry = preload("res://scenes/buildings/wire.gd")
const CELL_SIZE: int = 32
const MAX_CONNECTION_LENGTH: float = CELL_SIZE
const WIRE_STEP: float = CELL_SIZE / 4.0
const MAX_WIRE_CELLS: int = 4
var _drawing_wire := false
var _wire_start := Vector2.ZERO
const END_SNAP_RADIUS := 10.0
var _wire_start_connected := false
var _wire_start_source: Node2D
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


func _ready() -> void:
	add_to_group("construction_controller")


func begin(source: Resource) -> void:
	_clear_cut_selection()
	_drawing_wire = false
	_wire_start_source = null
	_wire_start_connected = false
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


func register_existing(building: Node2D, source: Resource, origin: Vector2i) -> void:
	building.set_meta("building_id", source.id)
	building.position = Vector2(origin * CELL_SIZE) + Vector2(source.footprint * CELL_SIZE) * 0.5
	for x in source.footprint.x:
		for y in source.footprint.y:
			_occupied[origin + Vector2i(x, y)] = building


func pick_building(cursor: Vector2) -> bool:
	if not is_instance_valid(actor) or actor.menu_open or actor.vitals.health <= 0.0:
		return false
	var query := PhysicsPointQueryParameters2D.new()
	query.position = cursor
	for hit in get_world_2d().direct_space_state.intersect_point(query, 256):
		var building = hit.collider
		if building.is_queued_for_deletion() or not building.visible or (not _free_buildings.has(building) and not _occupied.values().has(building)):
			continue
		var path := "res://data/buildings/%s.tres" % building.get_meta("building_id", &"")
		if ResourceLoader.exists(path):
			_using_tool = false
			_reset_demolition()
			begin(load(path))
			update_preview(cursor)
			return true
	return false


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
	can_place = _valid_location()
	if definition != null and definition.id in [&"wire", &"pipe"] and _wire_route.is_empty():
		can_place = _wire_marker_is_clear()
	_last_preview_turns = turns
	queue_redraw()


func _process(_delta: float) -> void:
	advance_construction(_delta)
	if active:
		update_preview(get_global_mouse_position())
	elif selected_tool == 2:
		_update_cut_preview(get_global_mouse_position())


func _wire_marker_is_clear() -> bool:
	var marker_size := Vector2(WIRE_STEP, WIRE_STEP)
	if definition.id == &"pipe":
		marker_size = Vector2.ONE * definition.preview_size.x
	var marker := _cursor_position if free_build_mode else (_cursor_position / WIRE_STEP).floor() * WIRE_STEP + marker_size * 0.5
	var snap := _start_snap(_cursor_position)
	if not snap.is_empty():
		marker = snap.point + snap.source.connection_ends()[1].direction * marker_size.x * 0.5
	placement_position = marker
	if not bounds.encloses(Rect2(marker - marker_size * 0.5, marker_size)) or not _placement_in_reach(Rect2(marker - marker_size * 0.5, marker_size)):
		return false
	var shape := RectangleShape2D.new()
	shape.size = marker_size - Vector2.ONE * 0.2
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0, marker)
	for hit in get_world_2d().direct_space_state.intersect_shape(query, 256):
		if not _free_buildings.has(hit.collider) or hit.collider.get_meta("building_id", &"") not in [&"wire", &"pipe"]:
			return false
	return true


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
	if _wire_start_connected and is_instance_valid(_wire_start_source):
		var previous_direction: Vector2 = _wire_start_source.connection_ends()[1].direction
		if absf(previous_direction.dot(direction)) < 0.01:
			# Finish the previous grid cell before turning into the next row.
			var half_width: float = definition.preview_size.x * 0.5
			var corner := start + previous_direction * half_width
			_wire_route = PackedVector2Array([start, corner, corner + direction * (length - half_width)])
	placement_position = (_wire_route[0] + _wire_route[1]) * 0.5


func _start_snap(cursor: Vector2) -> Dictionary:
	var result := {}
	if free_build_mode:
		return result
	var nearest := END_SNAP_RADIUS
	for wire in _free_buildings:
		if not is_instance_valid(wire) or wire.is_queued_for_deletion() or not wire.visible or wire.get_meta("building_id", &"") != definition.id:
			continue
		for connection in _available_ends(wire):
			var distance: float = cursor.distance_to(connection.point)
			if distance < nearest:
				nearest = distance
				result = {"point": connection.point, "source": wire}
	return result


func _start_wire_drawing(cursor: Vector2) -> void:
	var snap := _start_snap(cursor)
	_wire_start_connected = not snap.is_empty()
	_wire_start_source = snap.get("source")
	_wire_start = snap.get("point", cursor if free_build_mode else (cursor / WIRE_STEP).floor() * WIRE_STEP + Vector2.ONE * WIRE_STEP * 0.5)
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
	if not wire.connected_outputs.is_empty():
		return []
	return [wire.connection_ends()[1]]


func _valid_location() -> bool:
	if definition == null:
		return false
	if not _wire_route.is_empty():
		if definition.id in [&"wire", &"pipe"]:
			var length := 0.0
			for index in _wire_route.size() - 1:
				length += _wire_route[index].distance_to(_wire_route[index + 1])
			var minimum_length: float = WIRE_STEP * 2.0 if definition.id == &"pipe" else WIRE_STEP
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
	if not bounds.encloses(rect) or not _placement_in_reach(rect):
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
	if definition.id in [&"wire", &"pipe"] and not _wire_route.is_empty():
		return _confirm_segments()
	var building := definition.scene.instantiate() as Node2D
	var size_cells := dimensions()
	building.position = placement_position if definition.free_placement or free_build_mode else Vector2(cell * CELL_SIZE) + Vector2(size_cells * CELL_SIZE) / 2.0
	building.rotation = turns * PI / 2.0
	building.set_meta("building_id", definition.id)
	if not _wire_route.is_empty():
		building.position = Vector2.ZERO
		building.rotation = 0.0
		building.route = _wire_route.duplicate()
	if definition.id in [&"wire", &"pipe"]:
		if _wire_start_connected and is_instance_valid(_wire_start_source):
			building.set_meta("connection_source", _wire_start_source.get_instance_id())
	get_parent().add_child(building)
	if definition.free_placement or free_build_mode:
		_free_buildings.append(building)
	else:
		for x in size_cells.x:
			for y in size_cells.y:
				_occupied[cell + Vector2i(x, y)] = building
	_refresh_wire_connections()
	_start_construction(building, maxf(0.5, definition.footprint.x * definition.footprint.y * BUILD_SECONDS_PER_CELL))
	if build_instant:
		advance_construction(0.0)
	building_placed.emit(building)
	feedback.emit("Здание установлено")
	_drawing_wire = false
	update_preview(_cursor_position)
	return true


func _confirm_segments() -> bool:
	var routes: Array[PackedVector2Array] = []
	var total := 0.0
	for index in _wire_route.size() - 1:
		total += _wire_route[index].distance_to(_wire_route[index + 1])
	var minimum := WIRE_STEP * 2.0 if definition.id == &"pipe" else WIRE_STEP
	var segment_index := 0
	var start := _wire_route[0]
	while total > 0.01:
		var length := minf(total, WIRE_STEP * MAX_WIRE_CELLS)
		if total > length and total - length < minimum:
			length -= minimum - (total - length)
		var remaining := length
		var points := PackedVector2Array([start])
		while remaining > 0.01:
			var end := _wire_route[segment_index + 1]
			var distance := start.distance_to(end)
			if distance <= remaining + 0.001:
				points.append(end)
				start = end
				segment_index += 1
				remaining -= distance
			else:
				start = start.move_toward(end, remaining)
				points.append(start)
				remaining = 0.0
		routes.append(points)
		total -= length
	var source: Node2D = _wire_start_source if _wire_start_connected and is_instance_valid(_wire_start_source) else null
	var placed: Array[Node2D] = []
	for points in routes:
		var segment := definition.scene.instantiate() as Node2D
		segment.route = points
		segment.set_meta("building_id", definition.id)
		if source != null:
			segment.set_meta("connection_source", source.get_instance_id())
		get_parent().add_child(segment)
		_free_buildings.append(segment)
		placed.append(segment)
		source = segment
	_refresh_wire_connections()
	for index in placed.size():
		var segment := placed[index]
		if (index > 0 and not build_instant) or not _can_continue_construction(segment):
			segment.hide()
			_segment_reveals.append({"building": segment, "remaining": index * SEGMENT_REVEAL_STEP})
		building_placed.emit(segment)
	feedback.emit("Здание установлено")
	_drawing_wire = false
	update_preview(_cursor_position)
	return true


func _work_visual(building: Node2D) -> Node2D:
	var visual := building.get_node_or_null("WorkVisual")
	if visual == null:
		visual = WorkVisual.new()
		visual.name = "WorkVisual"
		visual.z_index = 20
		building.add_child(visual)
	return visual


func _start_construction(building: Node2D, duration: float) -> void:
	building.set_meta("construction_remaining", duration)
	building.set_meta("construction_duration", duration)
	building.modulate.a = 0.4
	_construction_jobs.append(building)
	var visual = _work_visual(building)
	visual.build_progress = 0.0
	visual.queue_redraw()


func _can_continue_construction(building: Node2D) -> bool:
	if not is_instance_valid(actor) or actor.menu_open or actor.vitals.health <= 0.0:
		return false
	var rect := _building_world_rect(building)
	var point := actor.global_position.clamp(rect.position + Vector2.ONE * 0.1, rect.end - Vector2.ONE * 0.1)
	if build_range_enabled and actor.global_position.distance_to(point) > construction_reach:
		return false
	if actor.global_position.distance_to(point) < 0.1:
		return true
	var ray := PhysicsRayQueryParameters2D.create(actor.global_position, point)
	ray.exclude = [actor.get_rid()]
	if building.get_meta("building_id", &"") in [&"wire", &"pipe"]:
		var exclusions: Array[RID] = [actor.get_rid()]
		for segment in _free_buildings:
			if is_instance_valid(segment) and segment != building and segment.get_meta("building_id", &"") in [&"wire", &"pipe"]:
				exclusions.append(segment.get_rid())
		ray.exclude = exclusions
	var hit := get_world_2d().direct_space_state.intersect_ray(ray)
	return hit.is_empty() or hit.collider == building


func advance_construction(delta: float) -> void:
	queue_redraw()
	for reveal in _segment_reveals.duplicate():
		if not is_instance_valid(reveal.building) or reveal.building.is_queued_for_deletion():
			_segment_reveals.erase(reveal)
			continue
		if not _can_continue_construction(reveal.building):
			continue
		reveal.remaining = 0.0 if build_instant else reveal.remaining - maxf(delta, 0.0) * build_speed
		if reveal.remaining <= 0.0:
			reveal.building.show()
			_segment_reveals.erase(reveal)
	for building in _construction_jobs.duplicate():
		if not is_instance_valid(building) or building.is_queued_for_deletion():
			_construction_jobs.erase(building)
			continue
		if not _can_continue_construction(building):
			continue
		var remaining := 0.0 if build_instant else maxf(0.0, float(building.get_meta("construction_remaining")) - maxf(delta, 0.0) * build_speed)
		building.set_meta("construction_remaining", remaining)
		var progress := 1.0 - remaining / float(building.get_meta("construction_duration"))
		building.modulate.a = 0.4 + progress * 0.6
		var visual = _work_visual(building)
		visual.build_progress = progress
		visual.queue_redraw()
		if remaining <= 0.0:
			building.modulate.a = 1.0
			_construction_jobs.erase(building)


func _draw() -> void:
	_draw_construction_queue()
	if not active and selected_tool in [0, 1, 2]:
		for building in _demolition_queue:
			if is_instance_valid(building) and not building.is_queued_for_deletion():
				var rect := _building_world_rect(building).grow(2.0)
				draw_rect(rect, Color(1.0, 0.2, 0.12, 0.15))
				_draw_queue_outline(rect, Color(1.0, 0.35, 0.25, 0.95))
		for task in _cut_tasks:
			var rect := Rect2((task.point / task.size).floor() * task.size, Vector2.ONE * task.size)
			draw_rect(rect, Color(1.0, 0.2, 0.12, 0.3))
		if _cut_dragging:
			var selection := Rect2(_cut_drag_start, _cut_drag_end - _cut_drag_start).abs()
			draw_rect(selection, Color(1.0, 0.25, 0.15, 0.12))
			draw_rect(selection, Color(1.0, 0.5, 0.25, 0.9), false, 1.0)
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
			var marker := placement_position
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
	if not active and selected_tool in [0, 1, 2]:
		if event is InputEventMouseMotion and _cut_dragging:
			_cut_drag_end = get_canvas_transform().affine_inverse() * event.position
			queue_redraw()
			get_viewport().set_input_as_handled()
			return
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			_clear_cut_selection()
			get_viewport().set_input_as_handled()
			return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_MIDDLE:
		if pick_building(get_canvas_transform().affine_inverse() * event.position):
			get_viewport().set_input_as_handled()
		return
	if not active and selected_tool == 2 and event is InputEventMouseMotion and _using_tool and Input.is_physical_key_pressed(KEY_X):
		_sweep_cut_wires(get_canvas_transform().affine_inverse() * event.position)
		get_viewport().set_input_as_handled()
		return
	if not active and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not is_instance_valid(actor) or actor.menu_open or actor.vitals.health <= 0.0 or selected_tool not in [0, 1, 2]:
			return
		_clear_cut_selection()
		var cursor: Vector2 = get_canvas_transform().affine_inverse() * event.position
		if area_selection_enabled and (event.ctrl_pressed or Input.is_physical_key_pressed(KEY_CTRL)):
			_cut_dragging = true
			_cut_drag_start = cursor
			_cut_drag_end = cursor
		else:
			_using_tool = true
			if selected_tool == 2:
				_last_cut_cursor = cursor
				cut_wire_at(cursor)
		get_viewport().set_input_as_handled()
		return
	if not active or not event is InputEventMouseButton or not event.pressed:
		return
	if event.button_index == MOUSE_BUTTON_LEFT:
		var cursor: Vector2 = get_canvas_transform().affine_inverse() * event.position
		if definition.id in [&"wire", &"pipe"]:
			update_preview(cursor)
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
		if _cut_dragging:
			_cut_drag_end = get_canvas_transform().affine_inverse() * event.position
			if selected_tool == 2:
				queue_cut_area(_cut_drag_start, _cut_drag_end)
			else:
				queue_demolition_area(_cut_drag_start, _cut_drag_end)
			_cut_dragging = false
			_using_tool = false
			advance_cut_selection()
			get_viewport().set_input_as_handled()
			return
		if active and _drawing_wire:
			update_preview(get_canvas_transform().affine_inverse() * event.position)
			confirm()
			_drawing_wire = false
			update_preview(_cursor_position)
			get_viewport().set_input_as_handled()
		_using_tool = false
		_reset_demolition()


func _physics_process(delta: float) -> void:
	if not area_selection_enabled and (_cut_dragging or not _cut_tasks.is_empty() or not _demolition_queue.is_empty()):
		_clear_cut_selection()
	if selected_tool == 2:
		advance_cut_selection()
		if _using_tool and Input.is_physical_key_pressed(KEY_X):
			_sweep_cut_wires(get_global_mouse_position())
		return
	if not _demolition_queue.is_empty():
		advance_demolition_queue(delta)
	else:
		advance_demolition(delta, get_global_mouse_position(), _using_tool)


func advance_demolition(delta: float, cursor: Vector2, held: bool) -> void:
	if not held or active or not is_instance_valid(actor) or actor.menu_open or actor.vitals.health <= 0.0 or selected_tool < 0 or selected_tool > 1 or get_viewport().gui_get_hovered_control() != null:
		_reset_demolition()
		return
	var point := PhysicsPointQueryParameters2D.new()
	point.position = cursor
	var candidate: Node2D
	for hit in get_world_2d().direct_space_state.intersect_point(point, 32):
		if hit.collider.get_meta("building_id", &"") in [&"wire", &"pipe"]:
			continue
		if _occupied.values().has(hit.collider) or _free_buildings.has(hit.collider):
			candidate = hit.collider
			break
	if candidate == null or not _within_tool_reach(candidate, cursor):
		_reset_demolition()
		return
	if candidate != _demolition_target:
		_reset_demolition()
		_demolition_target = candidate
	_demolition_elapsed += maxf(delta, 0.0) * demolition_speed
	var duration := 0.6 if selected_tool == 0 else 3.0
	var visual = _work_visual(candidate)
	visual.demolition_progress = 1.0 if demolition_instant else minf(1.0, _demolition_elapsed / duration)
	candidate.modulate.a = 1.0 - visual.demolition_progress * 0.6
	visual.queue_redraw()
	var verb := "Разрушение" if selected_tool == 0 else "Разборка"
	demolition_progress.emit("%s: %d%%" % [verb, mini(100, int(_demolition_elapsed / duration * 100.0))])
	if demolition_instant or _demolition_elapsed >= duration:
		remove_building(candidate)
		feedback.emit("Постройка разрушена" if selected_tool == 0 else "Постройка разобрана")
		_using_tool = false
		_reset_demolition()


func _within_tool_reach(building: Node2D, cursor: Vector2) -> bool:
	if demolition_range_enabled:
		var rect := _building_world_rect(building)
		var closest := actor.global_position.clamp(rect.position, rect.end)
		if actor.global_position.distance_to(closest) > demolition_reach:
			return false
	var ray := PhysicsRayQueryParameters2D.create(actor.global_position, cursor)
	ray.exclude = [actor.get_rid()]
	var obstruction := get_world_2d().direct_space_state.intersect_ray(ray)
	return not obstruction.is_empty() and obstruction.collider == building


func remove_building(building: Node2D) -> void:
	_construction_jobs.erase(building)
	for reveal in _segment_reveals.duplicate():
		if not is_instance_valid(reveal.building) or reveal.building == building:
			_segment_reveals.erase(reveal)
	_free_buildings.erase(building)
	for occupied_cell in _occupied.keys():
		if _occupied[occupied_cell] == building:
			_occupied.erase(occupied_cell)
	building.queue_free()
	_refresh_wire_connections()


func _reset_demolition() -> void:
	if is_instance_valid(_demolition_target):
		_demolition_target.modulate.a = 0.4 + 0.6 * (1.0 - float(_demolition_target.get_meta("construction_remaining", 0.0)) / maxf(0.001, float(_demolition_target.get_meta("construction_duration", 1.0))))
	if is_instance_valid(_demolition_target):
		var visual = _demolition_target.get_node_or_null("WorkVisual")
		if visual != null:
			visual.demolition_progress = 0.0
			visual.queue_redraw()
	_demolition_target = null
	_demolition_elapsed = 0.0
	demolition_progress.emit("")


func set_tool(index: int) -> void:
	if index != selected_tool:
		_clear_cut_selection()
	_cut_preview.clear()
	queue_redraw()
	selected_tool = index
	_using_tool = false
	_reset_demolition()
















func _route_is_clear(points: PackedVector2Array, _excluded: Array[RID]) -> bool:
	for index in points.size() - 1:
		var delta := points[index + 1] - points[index]
		if delta.length() < 0.01:
			return false
		var shape := RectangleShape2D.new()
		shape.size = Vector2(delta.length() - 0.1, definition.preview_size.x - 0.2)
		var query := PhysicsShapeQueryParameters2D.new()
		query.shape = shape
		query.transform = Transform2D(delta.angle(), (points[index] + points[index + 1]) * 0.5)
		var extent: Vector2 = Vector2(absf(delta.x), absf(delta.y)) * 0.5 + Vector2.ONE * definition.preview_size.x * 0.5
		if not bounds.encloses(Rect2(query.transform.origin - extent, extent * 2)) or not _placement_in_reach(Rect2(query.transform.origin - extent, extent * 2)):
			return false
		for hit in get_world_2d().direct_space_state.intersect_shape(query, 256):
			var collider = hit.collider
			if collider.is_queued_for_deletion():
				continue
			if not _free_buildings.has(collider) or collider.get_meta("building_id", &"") not in [&"wire", &"pipe"]:
				return false
			# Allow only the shared joint when continuing from the source endpoint.
			if collider == _wire_start_source and _wire_start_connected and delta.normalized().dot(collider.connection_ends()[1].direction) >= -0.01:
				continue
			return false
	return true


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
			if target.get_meta("connection_source", 0) == source.get_instance_id() and source.output_point().distance_to(target.input_point()) < 0.15:
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


func cut_wire_at(cursor: Vector2, cut_size: float = 0.0) -> bool:
	var plan := _wire_cut_plan(cursor, cut_size)
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
		if replacement.input_point().is_equal_approx(wire.input_point()) and wire.has_meta("connection_source"):
			replacement.set_meta("connection_source", wire.get_meta("connection_source"))
		for next in wire.connected_outputs:
			if is_instance_valid(next) and next.input_point().is_equal_approx(replacement.output_point()):
				next.set_meta("connection_source", replacement.get_instance_id())
	remove_building(wire)
	wire_cut.emit(plan.removed)
	feedback.emit("Труба срезана" if wire.get_meta("building_id") == &"pipe" else "Провод срезан")
	_update_cut_preview(cursor)
	return true


func _wire_cut_plan(cursor: Vector2, requested_size: float = 0.0) -> Dictionary:
	if active or selected_tool != 2 or not is_instance_valid(actor) or actor.menu_open or actor.vitals.health <= 0 or get_viewport().gui_get_hovered_control() != null:
		return {}
	if not _cutter_in_reach(cursor):
		return {}
	var cut_size: float = requested_size if requested_size > 0.0 else (WIRE_STEP if Input.is_physical_key_pressed(KEY_X) else CELL_SIZE)
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
				if not _cutter_in_reach(before) or not _cutter_in_reach(after):
					_append_wire_piece(fragments, a, b)
					continue
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

func _clear_cut_selection() -> void:
	_reset_demolition()
	_using_tool = false
	_demolition_queue.clear()
	_cut_tasks.clear()
	_cut_dragging = false
	queue_redraw()


func queue_cut_area(start: Vector2, finish: Vector2) -> void:
	if not area_selection_enabled:
		return
	if active or selected_tool != 2 or not is_instance_valid(actor) or actor.menu_open or actor.vitals.health <= 0.0:
		return
	var selection := Rect2(start, finish - start).abs()
	if start.distance_to(finish) < 4.0:
		selection = Rect2((start / CELL_SIZE).floor() * CELL_SIZE, Vector2.ONE * CELL_SIZE)
	else:
		var origin := (selection.position / WIRE_STEP).floor() * WIRE_STEP
		var end := (selection.end / WIRE_STEP).ceil() * WIRE_STEP
		selection = Rect2(origin, end - origin)
	selection = selection.intersection(bounds).grow(0.01)
	var added := {}
	for wire in _free_buildings:
		if not is_instance_valid(wire) or wire.is_queued_for_deletion() or not wire.visible or wire.get_meta("building_id", &"") not in [&"wire", &"pipe"]:
			continue
		var points := _segment_world_points(wire)
		for index in points.size() - 1:
			var a := points[index]
			var b := points[index + 1]
			var interval := _segment_cell_interval(a, b, selection)
			if interval.x < 0:
				continue
			var first := a.lerp(b, interval.x)
			var last := a.lerp(b, interval.y)
			var steps := maxi(1, ceili(first.distance_to(last) / (WIRE_STEP * 0.5)))
			for step in steps:
				var sample := first.lerp(last, (float(step) + 0.5) / steps)
				var cell_origin := (sample / WIRE_STEP).floor() * WIRE_STEP
				var key := "%s:%s" % [wire.get_instance_id(), cell_origin]
				if added.has(key):
					continue
				var cell_interval := _segment_cell_interval(a, b, Rect2(cell_origin, Vector2.ONE * WIRE_STEP).grow(0.01))
				if cell_interval.x < 0:
					continue
				added[key] = true
				_cut_tasks.append({"point": a.lerp(b, (cell_interval.x + cell_interval.y) * 0.5), "size": WIRE_STEP})
	queue_redraw()


func _segment_world_points(wire: Node2D) -> PackedVector2Array:
	if wire.route.is_empty():
		return PackedVector2Array([wire.input_point(), wire.output_point()])
	var points := PackedVector2Array()
	for point in wire.route:
		points.append(wire.to_global(point))
	return points


func _cut_target_exists(cursor: Vector2) -> bool:
	for wire in _free_buildings:
		if not is_instance_valid(wire) or wire.is_queued_for_deletion() or wire.get_meta("building_id", &"") not in [&"wire", &"pipe"]:
			continue
		var points := _segment_world_points(wire)
		for index in points.size() - 1:
			if cursor.distance_to(Geometry2D.get_closest_point_to_segment(cursor, points[index], points[index + 1])) < wire.route_width * 0.5:
				return true
	return false


func advance_cut_selection() -> void:
	if not area_selection_enabled:
		return
	if active or selected_tool != 2 or not is_instance_valid(actor) or actor.menu_open or actor.vitals.health <= 0.0:
		return
	var operations := 0
	for task in _cut_tasks.duplicate():
		if not _cut_target_exists(task.point):
			_cut_tasks.erase(task)
		elif _cutter_in_reach(task.point):
			if cut_wire_at(task.point, task.size):
				operations += 1
				if not _cut_target_exists(task.point):
					_cut_tasks.erase(task)
		if operations >= 64:
			break
	queue_redraw()


func _building_world_rect(building: Node2D) -> Rect2:
	var result := Rect2()
	var found := false
	for child in building.get_children():
		if child is CollisionShape2D and child.shape is RectangleShape2D:
			var half: Vector2 = child.shape.size * 0.5
			for corner in [Vector2(-half.x, -half.y), Vector2(half.x, -half.y), half, Vector2(-half.x, half.y)]:
				var point: Vector2 = child.global_transform * corner
				if not found:
					result = Rect2(point, Vector2.ZERO)
					found = true
				else:
					result = result.expand(point)
	return result


func queue_demolition_area(start: Vector2, finish: Vector2) -> void:
	if not area_selection_enabled:
		return
	if active or selected_tool not in [0, 1] or not is_instance_valid(actor) or actor.menu_open or actor.vitals.health <= 0.0:
		return
	var selection := Rect2(start, finish - start).abs()
	selection.size = selection.size.max(Vector2.ONE)
	var shape := RectangleShape2D.new()
	shape.size = selection.size
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, selection.get_center())
	for hit in get_world_2d().direct_space_state.intersect_shape(query, 4096):
		var building = hit.collider
		if building.get_meta("building_id", &"") in [&"wire", &"pipe"]:
			continue
		if not building.is_queued_for_deletion() and (_free_buildings.has(building) or _occupied.values().has(building)) and not _demolition_queue.has(building):
			_demolition_queue.append(building)
	queue_redraw()


func _demolition_work_point(building: Node2D) -> Vector2:
	if building.get_meta("building_id", &"") not in [&"wire", &"pipe"]:
		return building.global_position
	var points := _segment_world_points(building)
	var nearest := points[0]
	for index in points.size() - 1:
		var candidate := Geometry2D.get_closest_point_to_segment(actor.global_position, points[index], points[index + 1])
		if candidate.distance_squared_to(actor.global_position) < nearest.distance_squared_to(actor.global_position):
			nearest = candidate
	return nearest


func advance_demolition_queue(delta: float) -> void:
	if not area_selection_enabled:
		return
	if active or selected_tool not in [0, 1] or not is_instance_valid(actor) or actor.menu_open or actor.vitals.health <= 0.0 or _cut_dragging:
		_reset_demolition()
		return
	var target: Node2D
	var nearest := INF
	for building in _demolition_queue.duplicate():
		if not is_instance_valid(building) or building.is_queued_for_deletion():
			_demolition_queue.erase(building)
			continue
		if building.get_meta("building_id", &"") in [&"wire", &"pipe"]:
			_demolition_queue.erase(building)
			continue
		var point := _demolition_work_point(building)
		if not building.visible or not _within_tool_reach(building, point):
			continue
		if building == _demolition_target:
			target = building
			break
		var distance := actor.global_position.distance_squared_to(point)
		if distance < nearest:
			nearest = distance
			target = building
	if target == null:
		_reset_demolition()
	else:
		advance_demolition(delta, _demolition_work_point(target), true)
		if target.is_queued_for_deletion():
			_demolition_queue.erase(target)
	queue_redraw()


func _cutter_in_reach(point: Vector2) -> bool:
	return not demolition_range_enabled or actor.global_position.distance_to(point) <= cutter_reach


func _draw_construction_queue() -> void:
	var color := Color(0.35, 0.85, 1.0, 0.95)
	for building in _construction_jobs:
		if not is_instance_valid(building) or building.is_queued_for_deletion() or _demolition_queue.has(building) or building == _demolition_target:
			continue
		var rect := _building_world_rect(building).grow(2.0)
		_draw_queue_outline(rect, color)
	for reveal in _segment_reveals:
		if not is_instance_valid(reveal.building):
			continue
		var building: Node2D = reveal.building
		if not is_instance_valid(building) or building.is_queued_for_deletion() or _demolition_queue.has(building) or building == _demolition_target:
			continue
		var points := _segment_world_points(building)
		# The ghost is drawn by the controller, independently of the hidden segment.
		for index in points.size() - 1:
			draw_line(points[index], points[index + 1], Color(0.25, 0.8, 1.0, 0.25), building.route_width)
			draw_dashed_line(points[index], points[index + 1], color, 1.0, 3.0)


func _draw_queue_outline(rect: Rect2, color: Color) -> void:
	var corners := PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y), rect.position])
	for index in 4:
		draw_dashed_line(corners[index], corners[index + 1], color, 1.5, 4.0)


func _placement_in_reach(rect: Rect2) -> bool:
	if remote_placement_enabled or not build_range_enabled:
		return true
	if not is_instance_valid(actor) or actor.menu_open or actor.vitals.health <= 0.0:
		return false
	var closest := actor.global_position.clamp(rect.position, rect.end)
	return actor.global_position.distance_to(closest) <= construction_reach
