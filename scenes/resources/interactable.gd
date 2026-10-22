extends StaticBody2D

signal selection_changed(selected: bool)


func _ready() -> void:
	add_to_group("interactables")


func set_selected(selected: bool) -> void:
	selection_changed.emit(selected)


func get_prompt() -> String:
	return ""


func interact(_inventory: RefCounted, _secondary: bool = false) -> String:
	return ""
