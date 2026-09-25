class_name Collectible2D
extends Node2D
## Shared world marker for catchable weapons and insects.

@export var collectible: CollectibleData


func _draw() -> void:
	draw_line(Vector2(-36, 0), Vector2(-20, 0), Color("b7d9de"), 2.0)
	draw_line(Vector2(-49, -9), Vector2(-27, -9), Color("b7d9de"), 2.0)
