extends RefCounted
var tree: SceneTree
const SETTINGS := {
 "build_speed": {"property": "build_speed", "description": "Множитель скорости строительства: 1 — обычно, 2 — вдвое быстрее.", "type": "number", "min": 0.01, "max": 1000.0},
 "demolition_speed": {"property": "demolition_speed", "description": "Множитель скорости кувалды и отвёртки.", "type": "number", "min": 0.01, "max": 1000.0},
 "build_instant": {"property": "build_instant", "description": "Строительство без задержки, включая появление сегментов.", "type": "bool"},
 "demolition_instant": {"property": "demolition_instant", "description": "Кувалда и отвёртка без задержки; действует и на очередь.", "type": "bool"},
 "build_range": {"property": "construction_reach", "description": "Радиус постановки и достройки, в пикселях. Достаточно попадания части постройки в радиус.", "type": "number", "min": 1.0, "max": 100000.0},
 "demolition_range": {"property": "demolition_reach", "description": "Радиус кувалды и отвёртки от края объекта, в пикселях.", "type": "number", "min": 1.0, "max": 100000.0},
 "cutter_range": {"property": "cutter_reach", "description": "Радиус кусачек, в пикселях.", "type": "number", "min": 1.0, "max": 100000.0},
 "build_range_enabled": {"property": "build_range_enabled", "description": "Ограничивать дальность постановки и достройки; false — без ограничения расстояния.", "type": "bool"},
 "demolition_range_enabled": {"property": "demolition_range_enabled", "description": "Ограничивать дальность всех инструментов, включая кусачки; false — без ограничения расстояния.", "type": "bool"},
}

func _init(scene_tree: SceneTree) -> void:
 tree = scene_tree

func register_commands(registry: RefCounted) -> void:
 for command in SETTINGS:
  var spec: Dictionary = SETTINGS[command]
  var argument := "true|false" if spec.type == "bool" else "value"
  registry.register_command(command, _setting.bind(command), spec.description + " Без аргумента — текущее значение.", 0, 1, "%s [%s]" % [command, argument])

func _controller() -> Node:
 var scene := tree.current_scene
 if scene == null:
  return null
 for controller in tree.get_nodes_in_group("construction_controller"):
  if scene == controller or scene.is_ancestor_of(controller):
   return controller
 return null

func _setting(args: PackedStringArray, command: String) -> Dictionary:
 var controller := _controller()
 if controller == null:
  return {"ok": false, "message": "В текущей сцене нет системы строительства."}
 var spec: Dictionary = SETTINGS[command]
 if not args.is_empty():
  var value: Variant
  if spec.type == "bool":
   if args[0].to_lower() not in ["true", "false"]:
    return {"ok": false, "message": "Ожидается true или false."}
   value = args[0].to_lower() == "true"
  else:
   if not args[0].is_valid_float():
    return {"ok": false, "message": "Ожидается число."}
   value = args[0].to_float()
   if not is_finite(value) or value < spec.min or value > spec.max:
    return {"ok": false, "message": "Допустимый диапазон: %s…%s." % [spec.min, spec.max]}
  controller.set(spec.property, value)
 var current: Variant = controller.get(spec.property)
 var text := ("true" if current else "false") if spec.type == "bool" else str(current)
 return {"ok": true, "message": "%s = %s" % [command, text]}
