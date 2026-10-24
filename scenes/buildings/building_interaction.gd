extends "res://scenes/resources/interactable.gd"
## Directional selection and activation for prototype buildings. Production menus can subscribe later.
signal interaction_requested(building: Node2D)

func _ready() -> void:
	super._ready()
	selection_changed.connect(func(selected: bool) -> void:
		modulate = Color(1.12, 1.12, 1.12) if selected else Color.WHITE)

func _title() -> String:
	var caption := get_node_or_null("Name") as Label
	return caption.text if caption != null else name

func get_prompt() -> String:
	return "%s | E — взаимодействовать" % _title()

func interact(_inventory: RefCounted, _secondary: bool = false) -> String:
	interaction_requested.emit(self)
	return _title()
