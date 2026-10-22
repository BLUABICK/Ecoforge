extends Control

signal building_selected(definition: Resource)
signal inventory_slot_selected(index: int)
signal hotbar_slot_selected(index: int)
signal tool_slot_selected(index: int)
const ItemSlotPresentation = preload("res://scenes/ui/item_slot_presentation.gd")
const Inventory = preload("res://scenes/player/inventory.gd")
var hotbar: RefCounted
var tools: RefCounted
var _hotbar_slots: Array[Button] = []
var _tool_slots: Array[Button] = []
var _inventory_extras: Array[Control] = []
var _quantity_dialog: ConfirmationDialog
var _quantity_slider: HSlider
var _quantity_label: Label
var _quantity_side: int = 0
var _quantity_index: int = 0
var _quantity_item: StringName = &""

const ItemContextMenu = preload("res://scenes/ui/item_context_menu.gd")
var _item_context: Node
const COLUMNS: int = 5
const ROWS: int = 3
var inventory: RefCounted
var active_tab: int = 0
var selected_slot: int = 0
var selected_hotbar: int = 0
var _catalog: Array[Resource] = []
var _building_slots: Array[Button] = []
var _tabs: Array[Button] = []
var _pages: Array[Control] = []
var _inventory_slots: Array[Button] = []
var _equipment_slots: Array[Button] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.0, 0.22)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var panel := PanelContainer.new()
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.055, 0.065, 0.075, 0.90)
	background.content_margin_left = 24
	background.content_margin_right = 24
	background.content_margin_top = 24
	background.content_margin_bottom = 24
	panel.add_theme_stylebox_override("panel", background)
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 20)
	panel.add_child(column)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	column.add_child(tabs)
	var names := ["Инвентарь", "Снаряжение", "Строительство"]
	for index in 3:
		var tab := Button.new()
		tab.text = names[index]
		tab.custom_minimum_size = Vector2(160, 44)
		tab.focus_mode = Control.FOCUS_NONE
		tab.pressed.connect(_select_tab.bind(index))
		tabs.add_child(tab)
		_tabs.append(tab)
	var pages := Control.new()
	pages.custom_minimum_size = Vector2(500, 400)
	column.add_child(pages)
	for page_index in 3:
		if page_index == 1:
			var equipment := Control.new()
			equipment.size = Vector2(500, 400)
			pages.add_child(equipment)
			_pages.append(equipment)
			var positions: Array[Vector2] = [
				Vector2(52, 48), Vector2(52, 192), Vector2(52, 336),
				Vector2(448, 48), Vector2(448, 192), Vector2(448, 336),
				Vector2(250, 108), Vector2(182, 192), Vector2(318, 192), Vector2(250, 276),
			]
			for index in positions.size():
				var slot := Button.new()
				slot.size = Vector2(72, 72)
				slot.custom_minimum_size = Vector2(72, 72)
				slot.position = positions[index] - Vector2(36, 36)
				slot.focus_mode = Control.FOCUS_NONE
				_style(slot, Color(0.025, 0.035, 0.045, 0.64))
				equipment.add_child(slot)
				_equipment_slots.append(slot)
				if index < 6:
					_tool_slots.append(slot)
					slot.clip_text = true
					slot.gui_input.connect(_item_input.bind(index, slot, 2))
					slot.set_drag_forwarding(_drag_slot.bind(2, index, slot), _can_drop_slot.bind(2, index), _drop_slot.bind(2, index))
					slot.pressed.connect(func() -> void: tool_slot_selected.emit(index))
			continue
		var grid := GridContainer.new()
		grid.columns = COLUMNS
		grid.add_theme_constant_override("h_separation", 10)
		grid.add_theme_constant_override("v_separation", 10)
		grid.position = Vector2(50, 38)
		pages.add_child(grid)
		_pages.append(grid)
		for index in COLUMNS * ROWS:
			var slot := Button.new()
			slot.custom_minimum_size = Vector2(72, 72)
			slot.focus_mode = Control.FOCUS_NONE
			_style(slot, Color(0.025, 0.035, 0.045, 0.64))
			grid.add_child(slot)
			if page_index == 0:
				_inventory_slots.append(slot)
				slot.pressed.connect(_select_slot.bind(index))
				slot.gui_input.connect(_item_input.bind(index, slot, 0))
				slot.set_drag_forwarding(_drag_slot.bind(0, index, slot), _can_drop_slot.bind(0, index), _drop_slot.bind(0, index))
			elif page_index == 2:
				_building_slots.append(slot)
				slot.pressed.connect(_choose_building.bind(index))
			else:
				# Equipment is a placeholder.
				slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add_section_label(pages, "Основной инвентарь", Vector2(50, 4))
	var footer := Control.new()
	footer.custom_minimum_size = Vector2(500, 106)
	column.add_child(footer)
	_add_section_label(footer, "Хотбар", Vector2(50, 0), true)
	_make_extra_grid(footer, _hotbar_slots, 5, Vector2(50, 32), 1)
	_make_quantity_dialog()
	visibility_changed.connect(func() -> void:
		if not visible:
			_quantity_dialog.hide())
	_item_context = ItemContextMenu.new()
	add_child(_item_context)
	_select_tab(0)
	hide()


func bind(source: RefCounted, hotbar_source: RefCounted = null, tool_source: RefCounted = null) -> void:
	inventory = source
	hotbar = hotbar_source if hotbar_source != null else Inventory.new()
	tools = tool_source if tool_source != null else Inventory.new()
	hotbar.changed.connect(refresh)
	tools.changed.connect(refresh)
	inventory.changed.connect(refresh)
	refresh()


func _select_tab(index: int) -> void:
	active_tab = index
	for extra in _inventory_extras:
		extra.visible = index == 0
	for tab_index in _tabs.size():
		_pages[tab_index].visible = tab_index == index
		_style(_tabs[tab_index], Color(0.18, 0.20, 0.22, 0.85) if tab_index == index else Color(0.07, 0.08, 0.09, 0.7))


func _select_slot(index: int) -> void:
	selected_slot = index
	inventory_slot_selected.emit(index)
	refresh()


func refresh() -> void:
	_refresh_extra(_hotbar_slots, hotbar)
	_refresh_extra(_tool_slots, tools)
	for index in _inventory_slots.size():
		_style(_inventory_slots[index], Color(0.08, 0.095, 0.105, 0.72) if index == selected_slot else Color(0.025, 0.035, 0.045, 0.64))
		if inventory != null:
			var item_id: StringName = inventory.item_at_slot(index)
			var title := String(item_id)
			var path := "res://data/items/%s.tres" % item_id
			if item_id != &"" and ResourceLoader.exists(path):
				title = load(path).display_name
			_inventory_slots[index].add_theme_font_size_override("font_size", 12)
			_inventory_slots[index].text = "" if item_id == &"" else "%s\n×%d" % [title.replace(" ", "\n"), inventory.amount_at_slot(index)]
			_inventory_slots[index].tooltip_text = "" if item_id == &"" else "%s × %d" % [title, inventory.amount_at_slot(index)]
			ItemSlotPresentation.apply(_inventory_slots[index], item_id, inventory.amount_at_slot(index))


func _style(button: Button, color: Color) -> void:
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = color.lightened(0.04) if state == "hover" else color
		button.add_theme_stylebox_override(state, style)


func set_catalog(buildings: Array[Resource]) -> void:
	_catalog = buildings
	for index in _building_slots.size():
		var available := index < _catalog.size()
		_building_slots[index].disabled = not available
		_building_slots[index].text = _catalog[index].display_name if available else ""
		_building_slots[index].icon = _catalog[index].icon if available else null
		_building_slots[index].expand_icon = true
		_building_slots[index].add_theme_constant_override("icon_max_width", 48)
		_building_slots[index].texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_building_slots[index].tooltip_text = _catalog[index].display_name if available else ""


func _choose_building(index: int) -> void:
	if index < _catalog.size():
		building_selected.emit(_catalog[index])







func _item_input(event: InputEvent, index: int, button: Control, side: int = 0) -> void:
	if not event is InputEventMouseButton or not event.pressed or _quantity_dialog.visible:
		return
	if event.shift_pressed and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		_quick_transfer(side, index, 1 if event.button_index == MOUSE_BUTTON_RIGHT else _bag_for(side).amount_at_slot(index))
		button.accept_event()
	elif event.ctrl_pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		_item_context.close_all()
		show_quantity(side, index)
		button.accept_event()
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		_item_context.open_for(_bag_for(side), index, inventory, null, button.get_global_transform() * event.position, tools, hotbar)
		button.accept_event()

func _add_section_label(parent: Control, text: String, point: Vector2, persistent: bool = false) -> void:
	var label := Label.new()
	label.text = text
	label.position = point
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	if not persistent:
		_inventory_extras.append(label)

func _make_extra_grid(parent: Control, slots: Array[Button], count: int, point: Vector2, side: int) -> void:
	var grid := GridContainer.new()
	grid.columns = count
	grid.position = point
	grid.add_theme_constant_override("h_separation", 10)
	parent.add_child(grid)
	if side != 1:
		_inventory_extras.append(grid)
	for index in count:
		var slot := Button.new()
		slot.custom_minimum_size = Vector2(72, 72)
		slot.focus_mode = Control.FOCUS_NONE
		slot.clip_text = true
		_style(slot, Color(0.025, 0.035, 0.045, 0.64))
		slot.gui_input.connect(_item_input.bind(index, slot, side))
		slot.set_drag_forwarding(_drag_slot.bind(side, index, slot), _can_drop_slot.bind(side, index), _drop_slot.bind(side, index))
		if side == 1:
			slot.pressed.connect(func() -> void: hotbar_slot_selected.emit(index))
		grid.add_child(slot)
		slots.append(slot)

func _refresh_extra(slots: Array[Button], bag: RefCounted) -> void:
	if bag == null:
		return
	for index in slots.size():
		if bag == hotbar:
			_style(slots[index], Color(0.08, 0.095, 0.105, 0.72) if index == selected_hotbar else Color(0.025, 0.035, 0.045, 0.64))
		var item_id: StringName = bag.item_at_slot(index)
		var path := "res://data/items/%s.tres" % item_id
		var title: String = load(path).display_name if item_id != &"" and ResourceLoader.exists(path) else String(item_id)
		slots[index].add_theme_font_size_override("font_size", 12)
		slots[index].text = "%s\n×%d" % [title.replace(" ", "\n"), bag.amount_at_slot(index)] if item_id != &"" else ""
		slots[index].tooltip_text = title
		ItemSlotPresentation.apply(slots[index], item_id, bag.amount_at_slot(index))

func _bag_for(side: int) -> RefCounted:
	return inventory if side == 0 else (hotbar if side == 1 else tools)

func _drag_slot(_position: Vector2, side: int, index: int, button: Control) -> Variant:
	var bag := _bag_for(side)
	if not visible or not _side_visible(side) or _quantity_dialog.visible or bag.item_at_slot(index) == &"" or Input.is_key_pressed(KEY_SHIFT) or Input.is_key_pressed(KEY_CTRL):
		return null
	if button.icon != null:
		var preview := TextureRect.new()
		preview.texture = button.icon
		preview.custom_minimum_size = Vector2(48, 48)
		preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		button.set_drag_preview(preview)
	else:
		var label := Label.new()
		label.text = button.text
		button.set_drag_preview(label)
	return {"menu": self, "side": side, "index": index, "item": bag.item_at_slot(index)}

func _can_drop_slot(_position: Vector2, data: Variant, side: int, index: int) -> bool:
	if not visible or not _side_visible(side) or _quantity_dialog.visible or not data is Dictionary or data.get("menu") != self:
		return false
	if not _side_visible(data.side):
		return false
	var bag := _bag_for(data.side)
	var target := _bag_for(side)
	if bag.item_at_slot(data.index) != data.item or (bag == target and data.index == index):
		return false
	if side == 2 and not Inventory.is_tool_item(data.item):
		return false
	var existing: StringName = target.item_at_slot(index)
	return (existing == &"" or existing == data.item) and target.amount_at_slot(index) < Inventory.stack_limit_for(data.item) and (bag == target or target.total() < target.capacity)

func _drop_slot(position: Vector2, data: Variant, side: int, index: int) -> void:
	if _can_drop_slot(position, data, side, index):
		var bag := _bag_for(data.side)
		bag.transfer_slot_to(_bag_for(side), data.index, bag.amount_at_slot(data.index), index)




func _side_visible(side: int) -> bool:
	return side == 1 or (side == 0 and active_tab == 0) or (side == 2 and active_tab == 1)

func _quick_transfer(side: int, index: int, amount: int) -> void:
	if not visible or not _side_visible(side):
		return
	var source := _bag_for(side)
	var destination: RefCounted = hotbar if side == 0 else inventory
	source.transfer_slot_to(destination, index, amount)

func _make_quantity_dialog() -> void:
	_quantity_dialog = ConfirmationDialog.new()
	_quantity_dialog.title = "Сколько переложить?"
	_quantity_dialog.ok_button_text = "Переложить"
	_quantity_dialog.cancel_button_text = "Отмена"
	_quantity_dialog.min_size = Vector2i(360, 150)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	_quantity_label = Label.new()
	column.add_child(_quantity_label)
	_quantity_slider = HSlider.new()
	_quantity_slider.min_value = 1
	_quantity_slider.step = 1
	_quantity_slider.custom_minimum_size = Vector2(320, 32)
	_quantity_slider.value_changed.connect(func(value: float) -> void:
		_quantity_label.text = "%d из %d" % [int(value), int(_quantity_slider.max_value)])
	column.add_child(_quantity_slider)
	_quantity_dialog.add_child(column)
	_quantity_dialog.confirmed.connect(func() -> void:
		if _bag_for(_quantity_side).item_at_slot(_quantity_index) == _quantity_item:
			_quick_transfer(_quantity_side, _quantity_index, int(_quantity_slider.value)))
	add_child(_quantity_dialog)

func show_quantity(side: int, index: int) -> void:
	var source := _bag_for(side)
	var amount: int = source.amount_at_slot(index)
	var item_id: StringName = source.item_at_slot(index)
	if not visible or not _side_visible(side) or amount <= 1 or Inventory.stack_limit_for(item_id) <= 1:
		return
	_quantity_side = side
	_quantity_index = index
	_quantity_item = item_id
	_quantity_slider.max_value = amount
	_quantity_slider.value = 1
	_quantity_label.text = "1 из %d" % amount
	_quantity_dialog.popup_centered()




