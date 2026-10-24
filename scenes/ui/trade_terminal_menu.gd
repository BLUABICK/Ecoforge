extends Control
signal closed
var terminal: Node2D
var inventory: RefCounted
var catalog: Array[Resource] = []
var mode := 0
var selected := 0
var _tabs: Array[Button] = []
var _items: Array[Button] = []
var _list: VBoxContainer
var _name: Label
var _description: Label
var _available: Label
var _quantity: SpinBox
var _action: Button
var _note: Label
var _panel: PanelContainer

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0.015, 0.025, 0.035, 0.78)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", _style(Color("18262c"), Color("52646a")))
	add_child(_panel)
	resized.connect(_layout)
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	_panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	var title := _label("ТОРГОВЫЙ ТЕРМИНАЛ", 24, Color("e5e9e3"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close_button := _button("×")
	close_button.custom_minimum_size = Vector2(40, 36)
	close_button.pressed.connect(close_menu)
	header.add_child(close_button)
	column.add_child(_label("Рынок ресурсов", 16, Color("96aaa9")))
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 10)
	column.add_child(tabs)
	for index in 2:
		var tab := _button("Купить" if index == 0 else "Продать")
		tab.custom_minimum_size = Vector2(140, 42)
		tab.pressed.connect(select_mode.bind(index))
		tabs.add_child(tab)
		_tabs.append(tab)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 24)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(body)
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 270
	left.add_theme_constant_override("separation", 10)
	body.add_child(left)
	left.add_child(_label("РЕСУРСЫ", 13, Color("96aaa9")))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 8)
	scroll.add_child(_list)
	var divider := ColorRect.new()
	divider.color = Color("39494e")
	divider.custom_minimum_size.x = 1
	body.add_child(divider)
	var details := VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_theme_constant_override("separation", 12)
	body.add_child(details)
	_name = _label("", 23, Color("e5e9e3"))
	details.add_child(_name)
	_description = _label("", 16, Color("aebebb"))
	_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_description.custom_minimum_size.y = 32
	details.add_child(_description)
	_available = _label("", 16, Color("d8dfd6"))
	details.add_child(_available)
	var quantity_row := HBoxContainer.new()
	quantity_row.add_theme_constant_override("separation", 16)
	quantity_row.add_child(_label("Количество", 16, Color("aebebb")))
	_quantity = SpinBox.new()
	_quantity.min_value = 1
	_quantity.max_value = 999
	_quantity.step = 1
	_quantity.value = 1
	_quantity.custom_minimum_size = Vector2(120, 36)
	quantity_row.add_child(_quantity)
	details.add_child(quantity_row)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	details.add_child(spacer)
	_note = _label("Рынок пока не принимает заказы.", 15, Color("bdac88"))
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.add_child(_note)
	_action = _button("Купить")
	_action.custom_minimum_size.y = 44
	_action.disabled = true
	details.add_child(_action)
	column.add_child(_label("E / Esc / Tab — закрыть", 14, Color("7f9495")))
	_layout()
	hide()

func _layout() -> void:
	if not is_instance_valid(_panel):
		return
	var panel_size := Vector2(minf(860, maxf(600, size.x - 40)), minf(600, maxf(540, size.y - 32)))
	_panel.position = (size - panel_size) * 0.5
	_panel.size = panel_size

func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func _style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_content_margin_all(12)
	return style

func _button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 17)
	button.add_theme_stylebox_override("normal", _style(Color("22333a"), Color("465a60")))
	button.add_theme_stylebox_override("hover", _style(Color("2c454c"), Color("8fa99f")))
	button.add_theme_stylebox_override("pressed", _style(Color("40554c"), Color("b7b38d")))
	button.add_theme_stylebox_override("disabled", _style(Color("253036"), Color("39484c")))
	return button

func open_menu(source: Node2D, bag: RefCounted) -> void:
	terminal = source
	inventory = bag
	catalog = source.get_trade_catalog()
	selected = 0
	mode = 0
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	_items.clear()
	for index in catalog.size():
		var button := _button(catalog[index].display_name)
		button.custom_minimum_size.y = 66
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(select_item.bind(index))
		_list.add_child(button)
		_items.append(button)
	if not inventory.changed.is_connected(refresh):
		inventory.changed.connect(refresh)
	show()
	_layout()
	refresh()

func select_mode(index: int) -> void:
	mode = clampi(index, 0, 1)
	_quantity.value = 1
	refresh()

func select_item(index: int) -> void:
	selected = clampi(index, 0, maxi(0, catalog.size() - 1))
	_quantity.value = 1
	refresh()

func refresh() -> void:
	if not visible or catalog.is_empty() or inventory == null:
		return
	var definition := catalog[selected]
	var owned: int = inventory.quantity(definition.id)
	_name.text = definition.display_name
	_description.text = definition.description
	_available.text = "В рюкзаке: %d" % owned
	_quantity.max_value = maxi(1, owned) if mode == 1 else 999
	_quantity.editable = mode == 0 or owned > 0
	_quantity.value = minf(_quantity.value, _quantity.max_value)
	_action.text = "Купить" if mode == 0 else "Продать"
	_note.text = "Нет ресурса для продажи." if mode == 1 and owned == 0 else "Рынок пока не принимает заказы."
	_action.disabled = true
	for index in _tabs.size():
		_tabs[index].add_theme_stylebox_override("normal", _style(Color("40554c") if index == mode else Color("22333a"), Color("b7b38d") if index == mode else Color("465a60")))
	for index in _items.size():
		_items[index].text = "%s\nВ рюкзаке: %d" % [catalog[index].display_name, inventory.quantity(catalog[index].id)]
		_items[index].add_theme_stylebox_override("normal", _style(Color("314940") if index == selected else Color("22333a"), Color("a5b497") if index == selected else Color("465a60")))

func close_menu() -> void:
	if not visible:
		return
	hide()
	if inventory != null and inventory.changed.is_connected(refresh):
		inventory.changed.disconnect(refresh)
	terminal = null
	closed.emit()


func _process(_delta: float) -> void:
	if visible:
		_layout()
