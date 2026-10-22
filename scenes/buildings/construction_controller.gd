extends Node2D

signal mode_changed(active: bool)
signal feedback(message: String)
signal building_placed(building: Node2D)

const CELL_SIZE: int = 32
var bounds := Rect2(Vector2.ZERO, Vector2(1920, 1280))
var definition: Resource
var active: bool = false
var turns: int = 0
var cell := Vector2i.ZERO
var can_place: bool = false
signal demolition_progress(text: String)
var actor: CharacterBody2D
var selected_tool: int = 0
var _using_tool: bool = false
var _demolition_target: Node2D
var _demolition_elapsed: float = 0.0

var _occupied: Dictionary[Vector2i, Node2D] = {}


func begin(source: Resource) -> void:
	definition = source
	turns = 0
	active = true
	update_preview(get_global_mouse_position())
	mode_changed.emit(true)


func cancel() -> void:
	active = false
	can_place = false
	queue_redraw()
	mode_changed.emit(false)


func dimensions() -> Vector2i:
	return Vector2i(definition.footprint.y, definition.footprint.x) if turns % 2 == 1 else definition.footprint


func update_preview(world_position: Vector2) -> void:
	cell = Vector2i((world_position / CELL_SIZE).floor())
	can_place = _valid_location()
	queue_redraw()


func _process(_delta: float) -> void:
	if active:
		update_preview(get_global_mouse_position())


func _unhandled_key_input(event: InputEvent) -> void:
	if not active or not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.physical_keycode == KEY_R:
		turns = (turns + 1) % 4
		can_place = _valid_location()
		queue_redraw()
	elif event.keycode == KEY_ESCAPE:
		cancel()
	else:
		return
	get_viewport().set_input_as_handled()


func _valid_location() -> bool:
	if definition == null:
		return false
	var size_cells := dimensions()
	var rect := Rect2(Vector2(cell * CELL_SIZE), Vector2(size_cells * CELL_SIZE))
	if not bounds.encloses(rect):
		return false
	for x in size_cells.x:
		for y in size_cells.y:
			if _occupied.has(cell + Vector2i(x, y)):
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
	building.position = Vector2(cell * CELL_SIZE) + Vector2(size_cells * CELL_SIZE) / 2.0
	building.rotation = turns * PI / 2.0
	get_parent().add_child(building)
	for x in size_cells.x:
		for y in size_cells.y:
			_occupied[cell + Vector2i(x, y)] = building
	building_placed.emit(building)
	feedback.emit("Здание установлено")
	cancel()
	return true


func _draw() -> void:
	if not active or definition == null:
		return
	var size_cells := dimensions()
	var origin := Vector2(cell * CELL_SIZE)
	var tint := Color(0.5, 0.9, 0.7, 0.8) if can_place else Color(0.95, 0.35, 0.35, 0.8)
	for x in range(-1, size_cells.x + 2):
		draw_line(origin + Vector2(x * CELL_SIZE, -CELL_SIZE), origin + Vector2(x * CELL_SIZE, (size_cells.y + 1) * CELL_SIZE), Color(0.8, 0.85, 0.85, 0.25))
	for y in range(-1, size_cells.y + 2):
		draw_line(origin + Vector2(-CELL_SIZE, y * CELL_SIZE), origin + Vector2((size_cells.x + 1) * CELL_SIZE, y * CELL_SIZE), Color(0.8, 0.85, 0.85, 0.25))
	var rect := Rect2(origin, Vector2(size_cells * CELL_SIZE))
	draw_rect(rect, Color(tint, 0.2))
	draw_rect(rect, tint, false, 2.0)
	var center := rect.get_center()
	var direction := Vector2.UP.rotated(turns * PI / 2.0)
	draw_line(center, center + direction * 20.0, tint, 3.0)
	draw_circle(center + direction * 20.0, 4.0, tint)


func _unhandled_input(event: InputEvent) -> void:
	if not active and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_using_tool = true
		return
	if not active or not event is InputEventMouseButton or not event.pressed:
		return
	if event.button_index == MOUSE_BUTTON_LEFT:
		update_preview(get_canvas_transform().affine_inverse() * event.position)
		confirm()
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		cancel()
	else:
		return
	get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_using_tool = false
		_reset_demolition()


func _physics_process(delta: float) -> void:
	advance_demolition(delta, get_global_mouse_position(), _using_tool)


func advance_demolition(delta: float, cursor: Vector2, held: bool) -> void:
	if not held or active or not is_instance_valid(actor) or actor.menu_open or actor.vitals.health <= 0.0 or selected_tool < 0 or selected_tool > 1 or get_viewport().gui_get_hovered_control() != null:
		_reset_demolition()
		return
	var point := PhysicsPointQueryParameters2D.new()
	point.position = cursor
	var candidate: Node2D
	for hit in get_world_2d().direct_space_state.intersect_point(point, 32):
		if _occupied.values().has(hit.collider):
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
	for occupied_cell in _occupied.keys():
		if _occupied[occupied_cell] == building:
			_occupied.erase(occupied_cell)
	building.queue_free()


func _reset_demolition() -> void:
	_demolition_target = null
	_demolition_elapsed = 0.0
	demolition_progress.emit("")


func set_tool(index: int) -> void:
	selected_tool = index
	_using_tool = false
	_reset_demolition()

