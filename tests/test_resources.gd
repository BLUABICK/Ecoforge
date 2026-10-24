extends SceneTree

const Inventory = preload("res://scenes/player/inventory.gd")
const Deposit = preload("res://scenes/resources/resource_deposit.gd")
var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var bag := Inventory.new()
	bag.capacity = 3
	_check(bag.add(&"iron_ore", -2) == 0 and bag.total() == 0, "Negative additions rejected")
	_check(bag.add(&"iron_ore", 5) == 3 and bag.total() == 3, "Capacity limits additions")
	_check(bag.add(&"limestone", 1) == 0, "Full mixed inventory rejects items")
	_check(bag.remove(&"iron_ore", -1) == 0, "Negative removal rejected")
	var chest := Inventory.new()
	chest.capacity = 2
	_check(bag.transfer_to(chest) == 2 and chest.total() == 2 and bag.total() == 1, "Partial transfer conserves resources")
	_check(chest.transfer_to(chest) == 0 and chest.total() == 2, "Self transfer does not destroy resources")
	_check(bag.remove(&"iron_ore", 10) == 1 and bag.total() == 0, "Cannot remove more than available")
	var deposit := Deposit.new()
	deposit.item = preload("res://data/items/iron_ore.tres")
	deposit.remaining = 2
	bag.capacity = 1
	deposit.interact(bag)
	deposit.interact(bag)
	_check(deposit.remaining == 1 and bag.total() == 1, "Full inventory does not consume deposit")
	bag.remove(&"iron_ore", 1)
	deposit.interact(bag)
	bag.remove(&"iron_ore", 1)
	deposit.interact(bag)
	_check(deposit.remaining == 0 and bag.total() == 0, "Depleted deposit cannot generate items")
	deposit.free()

	var world := preload("res://tests/playgrounds/resource_playground.tscn").instantiate()
	world.spawn_test_deposits = true
	root.add_child(world)
	var player := world.get_node("Player2d") as CharacterBody2D
	var interaction := player.get_node("Interaction")
	interaction.set_physics_process(false)
	await physics_frame
	await physics_frame
	await physics_frame
	player.position = Vector2(448, 380)
	await physics_frame
	await physics_frame
	await physics_frame
	interaction.refresh_target()
	_check(is_instance_valid(interaction.target) and interaction.target is Deposit, "Nearby deposit selected")
	interaction.interact()
	_check(interaction.inventory.quantity(&"iron_ore") == 1, "Interaction mines one item")
	interaction.interact()
	_check(interaction.inventory.quantity(&"iron_ore") == 1, "Cooldown prevents instant repeat mining")
	player.position = Vector2(920, 1100)
	await physics_frame
	await physics_frame
	await physics_frame
	interaction._cooldown = 0.0
	interaction.interact()
	_check(interaction.target == null and interaction.inventory.total() == 1, "Cannot mine remotely")
	player.position = world._storage.position + Vector2(0, -40)
	await physics_frame
	await physics_frame
	await physics_frame
	interaction.refresh_target()
	_check(interaction.target == world._storage, "Storage selected nearby")
	interaction._cooldown = 0.0
	interaction.interact()
	var storage_menu = world.get_node("HUD/PlayerHUD")._storage_menu
	_check(storage_menu.visible and interaction.inventory.total() == 1, "Storage interaction opens menu without moving items")
	storage_menu.transfer_slot(0, 0)
	_check(interaction.inventory.total() == 0 and world._storage.inventory.total() == 1, "Deposit into storage")
	interaction._cooldown = 0.0
	storage_menu.transfer_slot(2, 0)
	_check(interaction.inventory.total() == 1 and world._storage.inventory.total() == 0, "Withdraw from storage")

	storage_menu.close_menu()
	var blocked := Deposit.new()
	blocked.item = preload("res://data/items/iron_ore.tres")
	world._add_fixture(blocked, Vector2(680, 440), "Blocked", Color.WHITE)
	player.position = Vector2(620, 440)
	await physics_frame
	await physics_frame
	await physics_frame
	interaction.refresh_target()
	_check(interaction.target == null, "Walls block interaction")
	world.queue_free()
	await process_frame
	print("Resource checks finished. Failures: ", failures)
	quit(1 if failures else 0)


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error(description)




