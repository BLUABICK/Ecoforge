extends StaticBody2D

signal selection_changed(selected: bool)


func _ready() -> void:
	add_to_group("interactables")
	if is_in_group("buildings"):
		for child in get_children():
			if child is Label:
				child.hide()


func set_selected(selected: bool) -> void:
	selection_changed.emit(selected)


func get_prompt() -> String:
	return ""


func interact(_inventory: RefCounted, _secondary: bool = false) -> String:
	return ""


func can_interact_from(world_position: Vector2) -> bool:
	if float(get_meta("construction_remaining", 0.0)) > 0.0:
		return false
	if not is_in_group("buildings") or not has_node("Direction"):
		return true
	var collision := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision == null or not collision.shape is RectangleShape2D:
		return false
	# Arrows point up in the unrotated scene; to_local accounts for building rotation.
	var local_position := to_local(world_position)
	var half_size: Vector2 = collision.shape.size * 0.5
	var front_y := collision.position.y - half_size.y
	return local_position.y <= front_y and absf(local_position.x - collision.position.x) <= half_size.x + 12.0
