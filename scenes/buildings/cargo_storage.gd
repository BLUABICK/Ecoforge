extends "res://scenes/buildings/building_interaction.gd"
const Inventory = preload("res://scenes/player/inventory.gd")
var inventory := Inventory.new()
func _init() -> void:
	inventory.capacity = 150
	inventory.slot_limit = 25