extends Resource

@export var id: StringName
@export var display_name: String

@export var stack_limit: int = 100000
@export var is_tool: bool = false

@export_multiline var description: String = ""

@export var icon: Texture2D
