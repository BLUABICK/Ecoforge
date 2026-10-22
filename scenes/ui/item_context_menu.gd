extends Node
const Inventory = preload("res://scenes/player/inventory.gd")
var popup: PopupMenu
var info: AcceptDialog
var split_dialog: ConfirmationDialog
var split_slider: HSlider
var split_label: Label
var source: RefCounted
var main_inventory: RefCounted
var tools_inventory: RefCounted
var hotbar_inventory: RefCounted
var container_inventory: RefCounted
var slot_index: int = -1
var item_id: StringName = &""

func _ready() -> void:
	popup = PopupMenu.new()
	popup.add_item("Информация", 0)
	popup.add_item("Переместить в основной инвентарь", 1)
	popup.add_item("Переместить в контейнер", 2)
	popup.add_item("Разделить", 3)
	popup.add_separator()
	popup.add_item("Выбросить", 4)
	popup.set_item_disabled(popup.get_item_index(4), true)
	popup.set_item_tooltip(popup.get_item_index(4), "Выброс предметов будет добавлен позже")
	popup.id_pressed.connect(_action)
	add_child(popup)
	info = AcceptDialog.new()
	info.title = "Информация о предмете"
	info.min_size = Vector2i(380, 180)
	add_child(info)
	split_dialog = ConfirmationDialog.new()
	split_dialog.title = "Разделить стопку"
	split_dialog.ok_button_text = "Разделить"
	split_dialog.cancel_button_text = "Отмена"
	split_dialog.min_size = Vector2i(380, 150)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	split_label = Label.new()
	column.add_child(split_label)
	split_slider = HSlider.new()
	split_slider.min_value = 1
	split_slider.step = 1
	split_slider.custom_minimum_size = Vector2(340, 32)
	split_slider.value_changed.connect(_split_label)
	column.add_child(split_slider)
	split_dialog.add_child(column)
	split_dialog.confirmed.connect(_confirm_split)
	add_child(split_dialog)
	get_parent().visibility_changed.connect(func() -> void:
		if not get_parent().is_visible_in_tree():
			close_all())

func open_for(bag: RefCounted, index: int, main_bag: RefCounted, chest_bag: RefCounted = null, at_position: Vector2 = Vector2(-1, -1), tool_bag: RefCounted = null, hotbar_bag: RefCounted = null) -> void:
	close_all()
	if bag == null or bag.item_at_slot(index) == &"":
		return
	source = bag
	slot_index = index
	item_id = source.item_at_slot(index)
	main_inventory = main_bag
	container_inventory = chest_bag
	tools_inventory = tool_bag
	hotbar_inventory = hotbar_bag
	var splittable: bool = source.amount_at_slot(slot_index) > 1 and Inventory.stack_limit_for(item_id) > 1
	popup.clear()
	popup.add_item("Информация", 0)
	if source != main_inventory:
		popup.add_item("Переместить в основной инвентарь", 1)
		popup.set_item_disabled(popup.get_item_index(1), main_inventory == null)
	if source != container_inventory:
		popup.add_item("Переместить в контейнер", 2)
		popup.set_item_disabled(popup.get_item_index(2), container_inventory == null)
	if source != tools_inventory:
		popup.add_item("Переместить в инвентарь инструментов", 5)
		popup.set_item_disabled(popup.get_item_index(5), tools_inventory == null or not Inventory.is_tool_item(item_id))
	if source != hotbar_inventory:
		popup.add_item("Переместить в хотбар", 6)
		popup.set_item_disabled(popup.get_item_index(6), hotbar_inventory == null)
	if splittable:
		popup.add_item("Разделить", 3)
		popup.set_item_disabled(popup.get_item_index(3), _empty_slot() < 0)
		popup.set_item_tooltip(popup.get_item_index(3), "Нужна свободная ячейка" if _empty_slot() < 0 else "Отделить часть в новую ячейку")
	popup.add_separator()
	popup.add_item("Выбросить", 4)
	popup.set_item_disabled(popup.get_item_index(4), true)
	popup.set_item_tooltip(popup.get_item_index(4), "Выброс предметов будет добавлен позже")
	popup.position = Vector2i(at_position if at_position.x >= 0 else get_viewport().get_mouse_position())
	popup.reset_size()
	popup.popup()

func _valid() -> bool:
	return source != null and source.item_at_slot(slot_index) == item_id and item_id != &"" and get_parent().is_visible_in_tree()

func _empty_slot() -> int:
	if source == null:
		return -1
	return source._free_slot()

func _action(id: int) -> void:
	popup.hide()
	if not _valid():
		return
	match id:
		0:
			var path := "res://data/items/%s.tres" % item_id
			var definition: Resource = load(path) if ResourceLoader.exists(path) else null
			var title: String = definition.display_name if definition != null else String(item_id)
			var description: String = definition.description if definition != null else ""
			info.title = title
			info.dialog_text = "%s\n\nВ ячейке: %d\nТип: %s\nМаксимум в стопке: %d" % [description, source.amount_at_slot(slot_index), "Инструмент" if Inventory.is_tool_item(item_id) else "Предмет", Inventory.stack_limit_for(item_id)]
			info.popup_centered()
		1, 2, 5, 6:
			var destination := main_inventory if id == 1 else (container_inventory if id == 2 else (tools_inventory if id == 5 else hotbar_inventory))
			if id == 5 and not Inventory.is_tool_item(item_id):
				return
			if destination == null or destination == source:
				return
			var moved: int = source.transfer_slot_to(destination, slot_index, source.amount_at_slot(slot_index))
			if moved == 0:
				info.title = "Перемещение"
				info.dialog_text = "Нет места в выбранном инвентаре."
				info.popup_centered()
		3:
			var count: int = source.amount_at_slot(slot_index)
			if count <= 1 or Inventory.stack_limit_for(item_id) <= 1 or _empty_slot() < 0:
				return
			split_slider.max_value = count - 1
			split_slider.value = maxi(1, count / 2)
			_split_label(split_slider.value)
			split_dialog.popup_centered()

func _split_label(value: float) -> void:
	if _valid():
		split_label.text = "В новую ячейку: %d · останется: %d" % [int(value), source.amount_at_slot(slot_index) - int(value)]

func _confirm_split() -> void:
	if not _valid():
		return
	var target := _empty_slot()
	var amount := mini(int(split_slider.value), source.amount_at_slot(slot_index) - 1)
	if target >= 0 and amount > 0:
		source.transfer_slot_to(source, slot_index, amount, target)

func close_all() -> void:
	popup.hide()
	info.hide()
	split_dialog.hide()




