extends "res://scenes/buildings/building_interaction.gd"

func get_trade_catalog() -> Array[Resource]:
	return [preload("res://data/items/iron_ore.tres"), preload("res://data/items/limestone.tres")]

func get_prompt() -> String:
	return "Торговый терминал | E — открыть рынок"
