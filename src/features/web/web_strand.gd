class_name WebStrand2D
extends Node2D
## A visual strand. Durability is data only until web rules are implemented.

@export var endpoint_a: Vector2 = Vector2.ZERO
@export var endpoint_b: Vector2 = Vector2(100, 0)
@export_range(1, 100) var durability: int = 3


func _draw() -> void:
	draw_line(endpoint_a, endpoint_b, Color(0.77, 0.89, 0.88, 0.85), 3.0, true)
