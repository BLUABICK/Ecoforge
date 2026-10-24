extends Control

const SLOT_COUNT: int = 5
const TOOL_SLOT_COUNT: int = 6
const SLOT_SIZE: float = 72.0
const SLOT_GAP: float = 10.0
const HOTBAR_WIDTH: float = SLOT_COUNT * SLOT_SIZE + (SLOT_COUNT - 1) * SLOT_GAP

const ItemSlotPresentation = preload("res://scenes/ui/item_slot_presentation.gd")
const ItemContextMenu = preload("res://scenes/ui/item_context_menu.gd")
var _item_context: Node
const InventoryMenu = preload("res://scenes/ui/inventory_menu.gd")
const StorageMenu = preload("res://scenes/ui/storage_menu.gd")
var _storage_menu: Control
const TradeMenu = preload("res://scenes/ui/trade_terminal_menu.gd")
var _trade_menu: Control
var tools: RefCounted
var _inventory_menu: Control
var _player: Node
var _construction: Node2D

var hotbar: RefCounted
var inventory: RefCounted
var vitals: Node
var selected_slot: int = 0
var selected_tool: int = 0
var _hotbar_row: Control
var _slots: Array[Button] = []
var _tool_slots: Array[Button] = []
var _health_bar: ProgressBar
var _stamina_bar: ProgressBar
var _tool_panel: Control
var _tool_status: Label
var _tools_button: Button


func bind(player: Node) -> void:
	_player = player
	inventory = player.get_node("Interaction").inventory
	hotbar = player.get_node("Interaction").hotbar
	hotbar.changed.connect(_refresh_slots)
	_inventory_menu.bind(inventory, hotbar, player.get_node("Interaction").tools)
	vitals = player.get_node("Vitals")
	tools = player.get_node("Interaction").tools
	tools.changed.connect(_on_tools_changed)
	player.get_node("Interaction").storage_requested.connect(_open_storage)
	player.get_node("Interaction").trade_requested.connect(_open_trade)
	inventory.changed.connect(_refresh)
	_refresh_tools()
	vitals.changed.connect(_refresh_vitals)
	_refresh()


func _ready() -> void:
	theme = Theme.new()
	theme.default_font_size = 18
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	_hotbar_row = row
	row.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	row.offset_left = -HOTBAR_WIDTH / 2.0
	row.offset_right = HOTBAR_WIDTH / 2.0
	row.offset_top = -24.0 - SLOT_SIZE
	row.offset_bottom = -24.0
	row.add_theme_constant_override("separation", int(SLOT_GAP))
	add_child(row)
	for index in SLOT_COUNT:
		var slot := _make_slot()
		slot.pressed.connect(_select.bind(index))
		slot.gui_input.connect(_item_input.bind(false, index, slot))
		row.add_child(slot)
		_slots.append(slot)
		var number := Label.new()
		number.text = str(index + 1)
		number.add_theme_font_size_override("font_size", 12)
		number.add_theme_color_override("font_color", Color(0.88, 0.91, 0.93, 0.4))
		number.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
		number.offset_left = -18
		number.offset_top = -20
		number.offset_right = -5
		number.offset_bottom = -4
		number.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		number.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(number)

	_health_bar = _make_bar(12.0, 24.0, Color(0.69, 0.27, 0.30, 0.86))
	_stamina_bar = _make_bar(7.0, 46.0, Color(0.44, 0.69, 0.61, 0.80))
	_tools_button = _make_slot()
	_tools_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_tools_button.offset_left = -24.0 - SLOT_SIZE
	_tools_button.offset_right = -24.0
	_tools_button.offset_top = -24.0 - SLOT_SIZE
	_tools_button.offset_bottom = -24.0
	_tools_button.tooltip_text = "Инструменты"
	_tools_button.pressed.connect(_toggle_tools)
	add_child(_tools_button)

	_tool_panel = VBoxContainer.new()
	_tool_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_tool_panel.offset_left = -24.0 - SLOT_SIZE
	_tool_panel.offset_right = -24.0
	_tool_panel.offset_top = -24.0 - SLOT_SIZE - 12.0 - (TOOL_SLOT_COUNT * SLOT_SIZE + (TOOL_SLOT_COUNT - 1) * SLOT_GAP)
	_tool_panel.offset_bottom = -24.0 - SLOT_SIZE - 12.0
	_tool_panel.add_theme_constant_override("separation", int(SLOT_GAP))
	add_child(_tool_panel)
	_tool_slots.resize(TOOL_SLOT_COUNT)
	for offset in TOOL_SLOT_COUNT:
		var index := TOOL_SLOT_COUNT - 1 - offset
		var slot := _make_slot()
		slot.pressed.connect(_select_tool.bind(index))
		slot.gui_input.connect(_item_input.bind(true, index, slot))
		_tool_panel.add_child(slot)
		_tool_slots[index] = slot
	_tool_panel.hide()
	_tool_status = Label.new()
	_tool_status.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_tool_status.offset_left = -310
	_tool_status.offset_right = -106
	_tool_status.offset_top = -94
	_tool_status.offset_bottom = -24
	_tool_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_tool_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tool_status.add_theme_font_size_override("font_size", 15)
	add_child(_tool_status)
	resized.connect(_layout_bars)
	_layout_bars()
	_refresh_slots()
	_refresh_tools()
	_inventory_menu = InventoryMenu.new()
	_inventory_menu.hotbar_slot_selected.connect(_on_inventory_slot_selected)
	_inventory_menu.tool_slot_selected.connect(_select_tool)
	add_child(_inventory_menu)
	_storage_menu = StorageMenu.new()
	_storage_menu.closed.connect(_on_storage_closed)
	add_child(_storage_menu)
	_trade_menu = TradeMenu.new()
	_trade_menu.closed.connect(_on_storage_closed)
	add_child(_trade_menu)
	_item_context = ItemContextMenu.new()
	add_child(_item_context)


func _make_slot() -> Button:
	var slot := Button.new()
	slot.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
	slot.focus_mode = Control.FOCUS_NONE
	_style_slot(slot, Color(0.035, 0.045, 0.055, 0.62))
	return slot


func _style_slot(slot: Button, color: Color, outlined: bool = false) -> void:
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = color.lightened(0.12 if outlined else 0.06) if state == "hover" else (color.lightened(0.08) if outlined else color)
		slot.add_theme_stylebox_override(state, style)


func _make_bar(height: float, bottom: float, color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	bar.offset_left = 24
	bar.offset_right = 244
	bar.offset_top = -bottom - height
	bar.offset_bottom = -bottom
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	bar.add_theme_stylebox_override("fill", fill)
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.035, 0.045, 0.055, 0.5)
	bar.add_theme_stylebox_override("background", background)
	add_child(bar)
	return bar


func _layout_bars() -> void:
	var width := minf(264.0, maxf(64.0, (size.x - HOTBAR_WIDTH) / 2.0 - 48.0))
	_health_bar.offset_right = 24.0 + width
	_stamina_bar.offset_right = 24.0 + width


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if _trade_menu.visible or _storage_menu.visible or _inventory_menu.visible or (is_instance_valid(_construction) and _construction.active):
		return
	if event.physical_keycode == KEY_Q:
		_cycle_tool()
		get_viewport().set_input_as_handled()
	elif event.physical_keycode >= KEY_1 and event.physical_keycode <= KEY_5:
		_select(event.physical_keycode - KEY_1)
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_ESCAPE:
		_tool_panel.hide()


func _input(event: InputEvent) -> void:
	var window_mode := get_node_or_null("/root/WindowMode")
	if window_mode != null and window_mode.handle_shortcut(event):
		get_viewport().set_input_as_handled()
		return
	if is_instance_valid(_trade_menu) and _trade_menu.visible:
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode in [KEY_ESCAPE, KEY_TAB] or event.physical_keycode == KEY_E:
				_trade_menu.close_menu()
			get_viewport().set_input_as_handled()
		return
	if is_instance_valid(_storage_menu) and _storage_menu.visible:
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode in [KEY_ESCAPE, KEY_TAB] or event.physical_keycode == KEY_E:
				_storage_menu.close_menu()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_Z:
			var already_open: bool = _inventory_menu.visible and _inventory_menu.active_tab == 2
			_set_inventory_open(not already_open)
			_inventory_menu._select_tab(2)
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_TAB:
			_set_inventory_open(not _inventory_menu.visible)
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_ESCAPE and _inventory_menu.visible:
			_set_inventory_open(false)
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseButton and event.pressed and not _inventory_menu.visible:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			var step := -1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1
			_select(posmod(selected_slot + step, SLOT_COUNT))
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseButton and event.pressed and _tool_panel.visible:
		if not _tool_panel.get_global_rect().has_point(event.position) and not _tools_button.get_global_rect().has_point(event.position):
			_tool_panel.hide()


func _select(index: int) -> void:
	selected_slot = index
	if is_instance_valid(_inventory_menu):
		_inventory_menu.selected_hotbar = index
		_inventory_menu.refresh()
	_refresh_slots()


func _toggle_tools() -> void:
	_tool_panel.visible = not _tool_panel.visible


func _select_tool(index: int) -> void:
	selected_tool = index
	if is_instance_valid(_construction):
		_sync_tool()
	_refresh_tools()
	_tool_panel.hide()


func _refresh_tools() -> void:
	var item_id: StringName = tools.item_at_slot(selected_tool) if tools != null else &""
	var title := _item_name(item_id) if item_id != &"" else ""
	_tools_button.text = title
	_tools_button.add_theme_font_size_override("font_size", 12)
	ItemSlotPresentation.apply(_tools_button, item_id, 1)
	_tools_button.tooltip_text = "Универсальный секатор — ЛКМ: одна большая клетка; X + ЛКМ: срезать по одной маленькой клетке" if item_id == &"wire_cutters" else (title + " — удерживай ЛКМ на постройке" if not title.is_empty() else "Пустой слот инструмента")
	for index in _tool_slots.size():
		var slot_item: StringName = tools.item_at_slot(index) if tools != null else &""
		_tool_slots[index].text = _item_name(slot_item) if slot_item != &"" else ""
		_tool_slots[index].add_theme_font_size_override("font_size", 12)
		_tool_slots[index].tooltip_text = "Кувалда — разрушить за 0,6 с" if slot_item == &"sledgehammer" else ("Отвёртка — разобрать за 3 с" if slot_item == &"screwdriver" else ("Универсальный секатор — ЛКМ: одна большая клетка; X + ЛКМ: срезать по одной маленькой клетке" if slot_item == &"wire_cutters" else "Пустой слот"))
		_style_slot(_tool_slots[index], Color(0.11, 0.13, 0.15, 0.72), index == selected_tool)
		ItemSlotPresentation.apply(_tool_slots[index], slot_item, 1)

func _sync_tool() -> void:
	if not is_instance_valid(_construction) or tools == null:
		return
	var tool_id: StringName = tools.item_at_slot(selected_tool)
	_construction.set_tool(0 if tool_id == &"sledgehammer" else (1 if tool_id == &"screwdriver" else (2 if tool_id == &"wire_cutters" else -1)))


func _on_tools_changed() -> void:
	_refresh_tools()
	_sync_tool()

func _refresh() -> void:
	_refresh_slots()
	_refresh_vitals()


func _refresh_slots() -> void:
	for index in _slots.size():
		var color := Color(0.075, 0.09, 0.10, 0.67) if index == selected_slot else Color(0.035, 0.045, 0.055, 0.62)
		_style_slot(_slots[index], color)
		if hotbar != null:
			var item_id: StringName = hotbar.item_at_slot(index)
			_slots[index].add_theme_font_size_override("font_size", 12)
			_slots[index].text = "" if item_id == &"" else "%s\n×%d" % [_item_name(item_id).replace(" ", "\n"), hotbar.amount_at_slot(index)]
			_slots[index].tooltip_text = "" if item_id == &"" else "%s × %d" % [_item_name(item_id), hotbar.amount_at_slot(index)]
			ItemSlotPresentation.apply(_slots[index], item_id, hotbar.amount_at_slot(index))


func _refresh_vitals() -> void:
	if vitals == null:
		return
	_health_bar.max_value = vitals.max_health
	_health_bar.value = vitals.health
	_stamina_bar.max_value = vitals.max_stamina
	_stamina_bar.value = vitals.stamina


func _item_name(item_id: StringName) -> String:
	var definition_path := "res://data/items/%s.tres" % item_id
	if ResourceLoader.exists(definition_path):
		return load(definition_path).display_name
	return String(item_id)


func _set_inventory_open(open: bool) -> void:
	_item_context.close_all()
	if open and is_instance_valid(_trade_menu) and _trade_menu.visible:
		_trade_menu.close_menu()
	if open and is_instance_valid(_storage_menu) and _storage_menu.visible:
		_storage_menu.close_menu()
	_inventory_menu.visible = open
	_hotbar_row.visible = not open
	_tool_panel.hide()
	if open and is_instance_valid(_construction) and _construction.active:
		_construction.cancel()
	if is_instance_valid(_player):
		_player.set_menu_open(open)


func _on_inventory_slot_selected(index: int) -> void:
	if index < SLOT_COUNT:
		_select(index)



func bind_construction(controller: Node2D, buildings: Array[Resource]) -> void:
	_construction = controller
	_construction.actor = _player
	_sync_tool()
	_construction.demolition_progress.connect(func(text: String) -> void: _tool_status.text = text)
	_inventory_menu.set_catalog(buildings)
	_inventory_menu.building_selected.connect(_on_building_selected)
	_construction.mode_changed.connect(_on_construction_mode_changed)


func _on_building_selected(definition: Resource) -> void:
	_set_inventory_open(false)
	_construction.begin(definition)


func _on_construction_mode_changed(active: bool) -> void:
	_player.get_node("Interaction").input_blocked = active or _inventory_menu.visible




func _open_storage(storage: Node2D) -> void:
	_set_inventory_open(false)
	_tool_panel.hide()
	if is_instance_valid(_construction):
		_construction.cancel()
	_storage_menu.open_menu(inventory, tools, storage, hotbar)
	_hotbar_row.hide()
	_player.set_menu_open(true)


func _on_storage_closed() -> void:
	_hotbar_row.show()
	_player.set_menu_open(false)
	_player.get_node("Interaction")._cooldown = 0.4


func _process(_delta: float) -> void:
	if is_instance_valid(_trade_menu) and _trade_menu.visible:
		if vitals.health <= 0.0 or not is_instance_valid(_trade_menu.terminal) or _player.get_node("Interaction").target != _trade_menu.terminal:
			_trade_menu.close_menu()
	if is_instance_valid(_storage_menu) and _storage_menu.visible:
		if vitals.health <= 0.0 or _player.get_node("Interaction").target != _storage_menu.storage:
			_storage_menu.close_menu()





func _item_input(event: InputEvent, tool_slot: bool, index: int, button: Control) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT and not event.shift_pressed and not event.ctrl_pressed:
		_item_context.open_for(tools if tool_slot else hotbar, index, inventory, null, button.get_global_transform() * event.position, tools, hotbar)
		button.accept_event()






func _cycle_tool() -> void:
	var choices: Array[int] = []
	if tools != null:
		for index in TOOL_SLOT_COUNT:
			if tools.item_at_slot(index) != &"":
				choices.append(index)
	# Empty hands are available even when every physical slot is occupied.
	choices.append(-1)
	var current := choices.find(selected_tool)
	_select_tool(choices[(current + 1) % choices.size()])






func _open_trade(terminal: Node2D) -> void:
	_set_inventory_open(false)
	if _storage_menu.visible:
		_storage_menu.close_menu()
	_tool_panel.hide()
	if is_instance_valid(_construction):
		_construction.cancel()
	_trade_menu.open_menu(terminal, inventory)
	_hotbar_row.hide()
	_player.set_menu_open(true)
