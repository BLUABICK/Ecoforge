extends RefCounted
signal changed
var capacity: int = 30
var slot_limit: int = 0
var _slots: Dictionary[int, StringName] = {}
var _amounts: Dictionary[int, int] = {}

func total() -> int:
	var result := 0
	for amount in _amounts.values():
		result += amount
	return result

func quantity(item_id: StringName) -> int:
	var result := 0
	for index in _slots:
		if _slots[index] == item_id:
			result += amount_at_slot(index)
	return result

func contents() -> Dictionary[StringName, int]:
	var result: Dictionary[StringName, int] = {}
	for index in _slots:
		var item_id: StringName = _slots[index]
		result[item_id] = result.get(item_id, 0) + amount_at_slot(index)
	return result

static func stack_limit_for(item_id: StringName) -> int:
	var path := "res://data/items/%s.tres" % item_id
	return maxi(1, int(load(path).stack_limit)) if ResourceLoader.exists(path) else 100000

static func is_tool_item(item_id: StringName) -> bool:
	var path := "res://data/items/%s.tres" % item_id
	return bool(load(path).is_tool) if ResourceLoader.exists(path) else false

func _free_slot() -> int:
	var index := 0
	while _slots.has(index):
		index += 1
	return index if slot_limit <= 0 or index < slot_limit else -1

func add(item_id: StringName, amount: int) -> int:
	if item_id == &"" or amount <= 0:
		return 0
	var remaining := mini(amount, maxi(0, capacity - total()))
	var accepted := 0
	var limit := stack_limit_for(item_id)
	for index in _slots.keys():
		if _slots[index] == item_id:
			var count := mini(remaining, maxi(0, limit - amount_at_slot(index)))
			_amounts[index] = amount_at_slot(index) + count
			remaining -= count
			accepted += count
	while remaining > 0:
		var index := _free_slot()
		if index < 0:
			break
		var count := mini(remaining, limit)
		_slots[index] = item_id
		_amounts[index] = count
		remaining -= count
		accepted += count
	if accepted > 0:
		changed.emit()
	return accepted

func _remove_from_slot(index: int, amount: int) -> void:
	_amounts[index] = amount_at_slot(index) - amount
	if _amounts[index] <= 0:
		_slots.erase(index)
		_amounts.erase(index)

func remove(item_id: StringName, amount: int) -> int:
	var remaining := maxi(0, amount)
	var removed := 0
	for index in _slots.keys():
		if _slots[index] == item_id:
			var count := mini(remaining, amount_at_slot(index))
			_remove_from_slot(index, count)
			remaining -= count
			removed += count
	if removed > 0:
		changed.emit()
	return removed

func transfer_to(destination: RefCounted) -> int:
	if destination == self:
		return 0
	var moved := 0
	for item_id in contents().keys():
		moved += transfer_item_to(destination, item_id, quantity(item_id))
	return moved

func item_at_slot(index: int) -> StringName:
	return _slots.get(index, &"")

func amount_at_slot(index: int) -> int:
	return _amounts.get(index, 0)

func transfer_item_to(destination: RefCounted, item_id: StringName, amount: int) -> int:
	if destination == null or destination == self or amount <= 0:
		return 0
	var accepted: int = destination.add(item_id, mini(amount, quantity(item_id)))
	remove(item_id, accepted)
	return accepted

func transfer_slot_to(destination: RefCounted, source_index: int, amount: int, destination_index: int = -1) -> int:
	if destination == null or amount <= 0 or item_at_slot(source_index) == &"":
		return 0
	if destination_index < 0:
		if destination == self:
			return 0
		var moved: int = destination.add(item_at_slot(source_index), mini(amount, amount_at_slot(source_index)))
		if moved > 0:
			_remove_from_slot(source_index, moved)
			changed.emit()
		return moved
	if (destination.slot_limit > 0 and destination_index >= destination.slot_limit) or (destination == self and source_index == destination_index):
		return 0
	var item_id := item_at_slot(source_index)
	var existing: StringName = destination.item_at_slot(destination_index)
	if existing != &"" and existing != item_id:
		return 0
	var room: int = stack_limit_for(item_id) - destination.amount_at_slot(destination_index)
	if destination != self:
		room = mini(room, maxi(0, destination.capacity - destination.total()))
	var moved := mini(mini(amount, amount_at_slot(source_index)), maxi(0, room))
	if moved <= 0:
		return 0
	destination._slots[destination_index] = item_id
	destination._amounts[destination_index] = destination.amount_at_slot(destination_index) + moved
	_remove_from_slot(source_index, moved)
	changed.emit()
	if destination != self:
		destination.changed.emit()
	return moved

