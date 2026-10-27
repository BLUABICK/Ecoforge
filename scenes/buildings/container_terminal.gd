extends "res://scenes/buildings/building_interaction.gd"
const Inventory = preload("res://scenes/player/inventory.gd")
signal menu_requested(storage: Node2D)
var inventory := Inventory.new()
var mount_host: Node2D
func attach_to_container(host: Node2D) -> void:
	mount_host = host
	inventory = host.inventory
	host.set_meta("mounted_terminal", get_instance_id())
	z_index = 1
func can_interact_from(world_position: Vector2) -> bool:
	if float(get_meta("construction_remaining", 0.0)) > 0.0:
		return false
	if is_instance_valid(mount_host):
		return not mount_host.is_queued_for_deletion() and mount_host.can_interact_from(world_position)
	return super.can_interact_from(world_position)
func get_interaction_exclusions() -> Array[RID]:
	return [mount_host.get_rid()] if is_instance_valid(mount_host) else []
func get_prompt() -> String:
	return "Терминал грузового контейнера | E — открыть" if is_instance_valid(mount_host) else "Терминал | E — открыть"
func set_opened(_opened: bool) -> void:
	pass
func interact(_inventory: RefCounted, _secondary: bool = false) -> String:
	menu_requested.emit(self)
	return "Терминал открыт"
func get_storage_host() -> Node2D:
	var host: Node2D = mount_host if is_instance_valid(mount_host) and not mount_host.is_queued_for_deletion() else preload("res://scenes/buildings/terminal_wire_network.gd").find_storage(self)
	if is_instance_valid(host):
		inventory = host.inventory
	return host