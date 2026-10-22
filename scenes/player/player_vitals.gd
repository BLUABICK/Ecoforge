extends Node

signal changed
signal died

@export var max_health: float = 100.0
@export var max_stamina: float = 100.0
@export var sprint_drain: float = 20.0
@export var stamina_recovery: float = 18.0
@export var recovery_delay: float = 0.7
var health: float = 100.0
var stamina: float = 100.0
var exhausted: bool = false
var _recovery_wait: float = 0.0


func _ready() -> void:
	health = max_health
	stamina = max_stamina


func update_sprint(delta: float, moving: bool, requested: bool) -> bool:
	if health <= 0.0:
		return false
	var sprinting := requested and moving and not exhausted and stamina > 0.0
	if sprinting:
		stamina = maxf(0.0, stamina - sprint_drain * delta)
		_recovery_wait = recovery_delay
		if stamina <= 0.0:
			exhausted = true
			sprinting = false
	else:
		var recovery_time := maxf(0.0, delta - _recovery_wait)
		_recovery_wait = maxf(0.0, _recovery_wait - delta)
		stamina = minf(max_stamina, stamina + stamina_recovery * recovery_time)
		if exhausted and stamina >= max_stamina * 0.25:
			exhausted = false
	changed.emit()
	return sprinting


func take_damage(amount: float) -> void:
	if amount <= 0.0 or health <= 0.0:
		return
	health = maxf(0.0, health - amount)
	changed.emit()
	if health == 0.0:
		died.emit()


func heal(amount: float) -> void:
	if amount <= 0.0 or health <= 0.0:
		return
	health = minf(max_health, health + amount)
	changed.emit()
