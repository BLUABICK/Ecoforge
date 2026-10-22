extends Node2D
## Temporary representation shared by test deposits and storage.

@export var tint := Color("cb9b52")
@export var title: String = ""
var _selected: bool = false


func _ready() -> void:
	get_parent().selection_changed.connect(_on_selection_changed)
	var label := Label.new()
	label.text = title
	label.position = Vector2(-75, 36)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)


func _on_selection_changed(selected: bool) -> void:
	_selected = selected
	queue_redraw()


func _draw() -> void:
	draw_circle(Vector2.ZERO, 30.0, tint)
	if _selected:
		draw_arc(Vector2.ZERO, 37.0, 0, TAU, 48, Color("f7e8a4"), 3.0)
