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
var stamina_enabled := true
var stamina_drain_enabled := true
var sprint_enabled := true
var exhausted: bool = false
var _recovery_wait: float = 0.0


func _ready() -> void:
	health = max_health
	stamina = max_stamina


func update_sprint(delta: float, moving: bool, requested: bool) -> bool:
	if health <= 0.0:
		return false
	if not stamina_enabled:
		return requested and moving and sprint_enabled
	var sprinting := requested and moving and sprint_enabled and (not stamina_drain_enabled or (not exhausted and stamina > 0.0))
	if sprinting and stamina_drain_enabled:
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


func set_health(value: float) -> void:
	var was_alive := health > 0.0
	health = clampf(value, 0.0, max_health)
	changed.emit()
	if was_alive and health <= 0.0:
		died.emit()


func set_max_health(value: float) -> void:
	max_health = maxf(1.0, value)
	health = minf(health, max_health)
	changed.emit()


func set_stamina(value: float) -> void:
	stamina = clampf(value, 0.0, max_stamina)
	exhausted = stamina <= 0.0 or (exhausted and stamina < max_stamina * 0.25)
	_recovery_wait = 0.0
	changed.emit()


func set_max_stamina(value: float) -> void:
	max_stamina = maxf(1.0, value)
	set_stamina(minf(stamina, max_stamina))


func set_stamina_enabled(value: bool) -> void:
	stamina_enabled = value
	changed.emit()


func set_stamina_drain_enabled(value: bool) -> void:
	stamina_drain_enabled = value
	changed.emit()
