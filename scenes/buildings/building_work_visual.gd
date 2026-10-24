extends Node2D
## Temporary work overlay; replace with finished animations later.
var build_progress := 1.0
var demolition_progress := 0.0

func _draw() -> void:
 var building := get_parent() as Node2D
 var rect := Rect2()
 var found := false
 for child in building.get_children():
  if child is CollisionShape2D and child.shape is RectangleShape2D:
   var half: Vector2 = child.shape.size * 0.5
   for corner in [Vector2(-half.x, -half.y), Vector2(half.x, -half.y), half, Vector2(-half.x, half.y)]:
    var point: Vector2 = child.transform * corner
    if not found:
     rect = Rect2(point, Vector2.ZERO)
     found = true
    else:
     rect = rect.expand(point)
 if not found:
  return
 if build_progress < 1.0:
  draw_rect(rect, Color(0.3, 0.85, 1.0, 0.18))
  draw_rect(rect, Color(0.5, 0.9, 1.0, 0.9), false, 1.0)
  var bar := Rect2(rect.position + Vector2(0, -6), Vector2(rect.size.x, 3))
  draw_rect(bar, Color(0.05, 0.1, 0.15, 0.9))
  bar.size.x *= build_progress
  draw_rect(bar, Color(0.4, 0.95, 1.0))
 if demolition_progress > 0.0:
  draw_rect(rect, Color(1.0, 0.12, 0.06, 0.18))
  draw_rect(rect, Color(1.0, 0.35, 0.22, 0.9), false, 1.0)
  var bar := Rect2(rect.position + Vector2(0, -6), Vector2(rect.size.x, 3))
  draw_rect(bar, Color(0.15, 0.04, 0.03, 0.9))
  bar.size.x *= demolition_progress
  draw_rect(bar, Color(1.0, 0.4, 0.25))
