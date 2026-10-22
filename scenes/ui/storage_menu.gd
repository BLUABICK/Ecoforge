extends Control
signal closed
const ItemSlotPresentation = preload("res://scenes/ui/item_slot_presentation.gd")
const ItemContextMenu = preload("res://scenes/ui/item_context_menu.gd")
var _item_context: Node
const Inventory = preload("res://scenes/player/inventory.gd")
const TRANSFER_HINT = "Перетащи · Shift+ЛКМ — стопка · Shift+ПКМ — 1 · Ctrl+ПКМ — количество"
var _quantity_dialog: ConfirmationDialog
var _quantity_slider: HSlider
var _quantity_label: Label
var _quantity_side: int = -1
var _quantity_index: int = -1
var _quantity_item: StringName = &""
var player_inventory: RefCounted
var hotbar: RefCounted
var _hotbar_slots: Array[Button] = []
var tools: RefCounted
var storage: Node2D
var _bag_slots: Array[Button] = []
var _tool_slots: Array[Button] = []
var _storage_slots: Array[Button] = []
var _bag_count: Label
var _storage_count: Label
var _message: Label
var _appearance: Tween

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.4)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.065, 0.075, 0.97)
	style.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	panel.add_child(layout)
	var header := HBoxContainer.new()
	layout.add_child(header)
	var title := Label.new()
	title.text = "Контейнер"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 20)
	header.add_child(title)
	var close_button := Button.new()
	close_button.text = "Закрыть · Esc"
	close_button.pressed.connect(close_menu)
	header.add_child(close_button)
	var sides := HBoxContainer.new()
	sides.add_theme_constant_override("separation", 18)
	layout.add_child(sides)
	var bag_column := VBoxContainer.new()
	bag_column.add_theme_constant_override("separation", 18)
	sides.add_child(bag_column)
	var main_section := VBoxContainer.new()
	main_section.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	bag_column.add_child(main_section)
	_bag_count = Label.new()
	main_section.add_child(_bag_count)
	_make_grid(main_section, 15, 5, _bag_slots, 0)
	var tools_section := VBoxContainer.new()
	bag_column.add_child(tools_section)
	var tools_title := Label.new()
	tools_title.text = "Инструменты героя"
	tools_section.add_child(tools_title)
	_make_grid(tools_section, 6, 6, _tool_slots, 1)
	var hotbar_section := VBoxContainer.new()
	hotbar_section.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	bag_column.add_child(hotbar_section)
	var hotbar_title := Label.new()
	hotbar_title.text = "Хотбар"
	hotbar_section.add_child(hotbar_title)
	_make_grid(hotbar_section, 5, 5, _hotbar_slots, 3)
	var chest_column := VBoxContainer.new()
	sides.add_child(chest_column)
	_storage_count = Label.new()
	chest_column.add_child(_storage_count)
	_make_grid(chest_column, 25, 5, _storage_slots, 2)
	_message = Label.new()
	_message.text = TRANSFER_HINT
	_message.add_theme_font_size_override("font_size", 11)
	layout.add_child(_message)
	_make_quantity_dialog()
	_item_context = ItemContextMenu.new()
	add_child(_item_context)
	hide()

func _make_grid(parent: Control, count: int, columns: int, slots: Array[Button], side: int) -> void:
	var grid := GridContainer.new()
	grid.columns = columns
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	parent.add_child(grid)
	for index in count:
		var button := Button.new()
		button.custom_minimum_size = Vector2(56, 56)
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_size_override("font_size", 12)
		button.clip_text = true
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.025, 0.035, 0.045, 0.9)

		for state in ["normal", "hover", "pressed", "focus", "disabled"]:
			var slot_style := style.duplicate()
			slot_style.bg_color = style.bg_color.lightened(0.07) if state == "hover" else style.bg_color
			button.add_theme_stylebox_override(state, slot_style)
		button.gui_input.connect(_slot_input.bind(side, index, button))
		button.set_drag_forwarding(_drag_data.bind(side, index, button), _slot_can_drop.bind(side, index), _slot_drop.bind(side, index))
		grid.add_child(button)
		slots.append(button)

func open_menu(source: RefCounted, tool_inventory: RefCounted, container: Node2D, hotbar_inventory: RefCounted = null) -> void:
	_disconnect_sources()
	player_inventory = source
	tools = tool_inventory
	hotbar = hotbar_inventory if hotbar_inventory != null else Inventory.new()
	storage = container
	for bag in [player_inventory, tools, hotbar, storage.inventory]:
		bag.changed.connect(refresh)
	_message.text = TRANSFER_HINT
	show()
	storage.set_opened(true)
	if _appearance != null:
		_appearance.kill()
	modulate.a = 0.0
	_appearance = create_tween()
	_appearance.tween_property(self, "modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	refresh()

func close_menu() -> void:
	if not visible:
		return
	if is_instance_valid(storage) and not storage.is_queued_for_deletion():
		storage.set_opened(false)
	if _appearance != null:
		_appearance.kill()
	_quantity_dialog.hide()
	_item_context.close_all()
	hide()
	_disconnect_sources()
	storage = null
	closed.emit()

func _disconnect_sources() -> void:
	var sources: Array = [player_inventory, tools, hotbar]
	if is_instance_valid(storage):
		sources.append(storage.inventory)
	for bag in sources:
		if bag != null and bag.changed.is_connected(refresh):
			bag.changed.disconnect(refresh)

func _process(_delta: float) -> void:
	if visible and (not is_instance_valid(storage) or storage.is_queued_for_deletion()):
		close_menu()

func refresh() -> void:
	if not is_instance_valid(storage):
		return
	_refresh_grid(_bag_slots, player_inventory)
	_refresh_grid(_tool_slots, tools)
	_refresh_grid(_hotbar_slots, hotbar)
	_refresh_grid(_storage_slots, storage.inventory)
	_bag_count.text = "Инвентарь героя · %d/%d" % [player_inventory.total(), player_inventory.capacity]
	_storage_count.text = "Контейнер · %d/%d" % [storage.inventory.total(), storage.inventory.capacity]

func _refresh_grid(slots: Array[Button], bag: RefCounted) -> void:
	for index in slots.size():
		var item_id: StringName = bag.item_at_slot(index)
		var title := item_name(item_id)
		slots[index].text = "" if item_id == &"" else "%s\n×%d" % [title.replace(" ", "\n"), bag.amount_at_slot(index)]
		slots[index].tooltip_text = "" if item_id == &"" else "%s × %d" % [title, bag.amount_at_slot(index)]
		ItemSlotPresentation.apply(slots[index], item_id, bag.amount_at_slot(index))

func _source(side: int) -> RefCounted:
	return player_inventory if side == 0 else (tools if side == 1 else (hotbar if side == 3 else storage.inventory))

func _destination_side(side: int, item_id: StringName) -> int:
	return 2 if side != 2 else (1 if Inventory.is_tool_item(item_id) else 0)

func transfer_slot(side: int, index: int, single: bool = false) -> void:
	_transfer_amount(side, index, 1 if single else _source(side).amount_at_slot(index))

func _transfer_amount(side: int, index: int, amount: int, destination_side: int = -1, destination_index: int = -1) -> void:
	if not visible or not is_instance_valid(storage) or storage.is_queued_for_deletion():
		return
	var source := _source(side)
	var item_id: StringName = source.item_at_slot(index)
	if item_id == &"":
		return
	if destination_side < 0:
		destination_side = _destination_side(side, item_id)
	if destination_side == 1 and not Inventory.is_tool_item(item_id):
		return
	var moved: int = source.transfer_slot_to(_source(destination_side), index, amount, destination_index)
	_message.text = "Переложено: %s × %d" % [item_name(item_id), moved] if moved > 0 else "Нет места: выбери пустую ячейку или такую же стопку"
	refresh()

func _slot_input(event: InputEvent, side: int, index: int, button: Control) -> void:
	if not event is InputEventMouseButton or not event.pressed or _quantity_dialog.visible:
		return
	if event.shift_pressed and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		transfer_slot(side, index, event.button_index == MOUSE_BUTTON_RIGHT)
		button.accept_event()
	elif event.ctrl_pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		_item_context.close_all()
		show_quantity(side, index)
		button.accept_event()
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		_item_context.open_for(_source(side), index, player_inventory, storage.inventory, button.get_global_transform() * event.position, tools, hotbar)
		button.accept_event()

func _drag_data(_position: Vector2, side: int, index: int, button: Control) -> Variant:
	if not visible or _quantity_dialog.visible or Input.is_key_pressed(KEY_SHIFT) or Input.is_key_pressed(KEY_CTRL):
		return null
	var item_id: StringName = _source(side).item_at_slot(index)
	if item_id == &"":
		return null
	var preview := Label.new()
	preview.text = "%s × %d" % [item_name(item_id), _source(side).amount_at_slot(index)]
	button.set_drag_preview(preview)
	return {"menu": self, "side": side, "index": index, "item": item_id}

func _slot_can_drop(_position: Vector2, data: Variant, side: int, index: int) -> bool:
	if not visible or _quantity_dialog.visible or not is_instance_valid(storage) or not data is Dictionary:
		return false
	if data.get("menu") != self or not data.has_all(["side", "index", "item"]):
		return false
	var source := _source(data.side)
	if source.item_at_slot(data.index) != data.item or (data.side == side and data.index == index):
		return false
	if side == 1 and not Inventory.is_tool_item(data.item):
		return false
	var destination := _source(side)
	var existing: StringName = destination.item_at_slot(index)
	if existing != &"" and existing != data.item:
		return false
	return destination.amount_at_slot(index) < Inventory.stack_limit_for(data.item) and (source == destination or destination.total() < destination.capacity)

func _slot_drop(position: Vector2, data: Variant, side: int, index: int) -> void:
	if _slot_can_drop(position, data, side, index):
		_transfer_amount(data.side, data.index, _source(data.side).amount_at_slot(data.index), side, index)

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
		_quantity_label.text = "%s · %d из %d" % [item_name(_quantity_item), int(value), int(_quantity_slider.max_value)])
	column.add_child(_quantity_slider)
	_quantity_dialog.add_child(column)
	_quantity_dialog.confirmed.connect(_confirm_quantity)
	add_child(_quantity_dialog)

func show_quantity(side: int, index: int) -> void:
	if not visible or not is_instance_valid(storage):
		return
	var source := _source(side)
	var item_id: StringName = source.item_at_slot(index)
	var amount: int = source.amount_at_slot(index)
	if item_id == &"" or amount <= 1 or Inventory.stack_limit_for(item_id) <= 1:
		return
	_quantity_side = side
	_quantity_index = index
	_quantity_item = item_id
	_quantity_slider.max_value = amount
	_quantity_slider.value = 1
	_quantity_label.text = "%s · 1 из %d" % [item_name(item_id), amount]
	_quantity_dialog.popup_centered()

func _confirm_quantity() -> void:
	if not visible or not is_instance_valid(storage) or _source(_quantity_side).item_at_slot(_quantity_index) != _quantity_item:
		return
	_transfer_amount(_quantity_side, _quantity_index, int(_quantity_slider.value))

static func item_name(item_id: StringName) -> String:
	var path := "res://data/items/%s.tres" % item_id
	return load(path).display_name if item_id != &"" and ResourceLoader.exists(path) else String(item_id)

















