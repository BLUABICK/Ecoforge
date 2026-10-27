extends Control
signal closed
var terminal: Node2D
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.4)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(460, 220)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.065, 0.075, 0.97)
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		style.set_content_margin(side, 24)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 24)
	panel.add_child(layout)
	var title := Label.new()
	title.text = "Терминал"
	title.add_theme_font_size_override("font_size", 24)
	layout.add_child(title)
	var status := Label.new()
	status.text = "Состояние: готов к работе"
	status.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(status)
	var close := Button.new()
	close.text = "Закрыть · E / Esc"
	close.pressed.connect(close_menu)
	layout.add_child(close)
	hide()
func open_menu(source: Node2D) -> void:
	terminal = source
	show()
func close_menu() -> void:
	if not visible:
		return
	hide()
	terminal = null
	closed.emit()