extends RefCounted

static func apply(button: Button, item_id: StringName, amount: int) -> void:
	var path := "res://data/items/%s.tres" % item_id
	var definition: Resource = load(path) if item_id != &"" and ResourceLoader.exists(path) else null
	button.icon = definition.icon if definition != null else null
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.add_theme_constant_override("icon_max_width", 48)
	button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if button.icon != null:
		button.text = ""
	if definition != null:
		button.tooltip_text = "%s × %d" % [definition.display_name, amount]

