extends "res://scenes/resources/interactable.gd"

const ItemDefinition = preload("res://data/definitions/item_definition.gd")

signal depleted
signal stock_changed

@export var item: ItemDefinition
@export_range(0, 100000, 1) var remaining: int = 20


func get_prompt() -> String:
	if remaining <= 0:
		return "%s — залежь истощена" % item.display_name
	return "%s: %d ед. | Удерживай E — добывать" % [item.display_name, remaining]


func interact(inventory: RefCounted, secondary: bool = false) -> String:
	if secondary:
		return "Для добычи используй E"
	if remaining <= 0:
		return "Залежь истощена"
	var accepted: int = inventory.add(item.id, 1)
	if accepted == 0:
		return "Инвентарь заполнен — отнеси ресурсы в контейнер"
	remaining -= accepted
	stock_changed.emit()
	if remaining == 0:
		depleted.emit()
	return "+1 %s" % item.display_name
