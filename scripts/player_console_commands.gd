extends RefCounted
## Player tuning commands live outside the console UI; values belong to the scene.
var tree: SceneTree
const SETTINGS := {
 "hp": {"description": "Текущее HP; 0 — смерть, положительное значение оживляет.", "argument": "value"},
 "max_hp": {"description": "Максимум HP; текущее HP ограничивается новым максимумом.", "argument": "value"},
 "stamina": {"description": "Текущий запас стамины.", "argument": "value"},
 "max_stamina": {"description": "Максимальный запас стамины.", "argument": "value"},
 "stamina_drain": {"description": "Включить/выключить расход и ограничение бега запасом стамины.", "argument": "true|false"},
 "stamina_regen": {"description": "Скорость восстановления стамины, единиц/с (0 — без восстановления).", "argument": "value"},
 "stamina_enabled": {"description": "Включить/выключить систему стамины и её индикатор; запас сохраняется.", "argument": "true|false"},
 "sprint_enabled": {"description": "Включить/выключить возможность бега.", "argument": "true|false"},
 "sprint_speed": {"description": "Скорость бега, пикселей/с.", "argument": "value"},
}

func _init(scene_tree: SceneTree) -> void:
 tree = scene_tree

func register_commands(registry: RefCounted) -> void:
 for command in SETTINGS:
  var spec: Dictionary = SETTINGS[command]
  registry.register_command(command, _setting.bind(command), spec.description + " Без аргумента — текущее значение.", 0, 1, "%s [%s]" % [command, spec.argument])

func _player() -> Node:
 var scene := tree.current_scene
 if scene == null:
  return null
 for player in tree.get_nodes_in_group("player"):
  if scene == player or scene.is_ancestor_of(player):
   return player
 return null

func _setting(args: PackedStringArray, command: String) -> Dictionary:
 var player := _player()
 if player == null:
  return {"ok": false, "message": "В текущей сцене нет персонажа."}
 var vitals = player.get_node("Vitals")
 if args.is_empty():
  return _current_value(command, player, vitals)
 var value: Variant
 if SETTINGS[command].argument == "true|false":
  var option := args[0].to_lower()
  if option not in ["true", "false"]:
   return {"ok": false, "message": "Ожидается true или false."}
  value = option == "true"
 else:
  if not args[0].is_valid_float():
   return {"ok": false, "message": "Ожидается число."}
  value = args[0].to_float()
  var minimum := 1.0 if command in ["max_hp", "max_stamina", "sprint_speed"] else 0.0
  var maximum: float = vitals.max_health if command == "hp" else (vitals.max_stamina if command == "stamina" else (10000.0 if command == "sprint_speed" else 1000000.0))
  if not is_finite(value) or value < minimum or value > maximum:
   return {"ok": false, "message": "Допустимый диапазон: %s…%s." % [minimum, maximum]}
 match command:
  "hp": vitals.set_health(value)
  "max_hp": vitals.set_max_health(value)
  "stamina": vitals.set_stamina(value)
  "max_stamina": vitals.set_max_stamina(value)
  "stamina_drain": vitals.set_stamina_drain_enabled(value)
  "stamina_regen":
   vitals.stamina_recovery = value
   vitals.changed.emit()
  "stamina_enabled": vitals.set_stamina_enabled(value)
  "sprint_enabled": vitals.sprint_enabled = value
  "sprint_speed": player.sprint_multiplier = value / player.move_speed
 return _current_value(command, player, vitals)

func _current_value(command: String, player: Node, vitals: Node) -> Dictionary:
 var value: Variant
 match command:
  "hp": value = vitals.health
  "max_hp": value = vitals.max_health
  "stamina": value = vitals.stamina
  "max_stamina": value = vitals.max_stamina
  "stamina_drain": value = "true" if vitals.stamina_drain_enabled else "false"
  "stamina_regen": value = vitals.stamina_recovery
  "stamina_enabled": value = "true" if vitals.stamina_enabled else "false"
  "sprint_enabled": value = "true" if vitals.sprint_enabled else "false"
  "sprint_speed": value = player.move_speed * player.sprint_multiplier
 return {"ok": true, "message": "%s = %s" % [command, value]}
