extends Resource

@export var id: StringName
@export var display_name: String
@export var footprint := Vector2i(3, 2)
@export var scene: PackedScene
@export var icon: Texture2D
@export var preview_size := Vector2.ZERO
@export var free_placement: bool = false
@export var length_axis_snap: bool = false
