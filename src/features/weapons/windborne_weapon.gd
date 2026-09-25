class_name WindborneWeapon2D
extends Node2D
## Visual marker for a weapon arriving on the wind; spawning comes later.

@export var weapon: WeaponData


func _draw() -> void:
	var points := PackedVector2Array([
		Vector2(0, -13), Vector2(13, 0), Vector2(0, 13), Vector2(-13, 0),
	])
	draw_colored_polygon(points, Color("f3d977"))
	draw_line(Vector2(-36, 0), Vector2(-20, 0), Color("b7d9de"), 2.0)
	draw_line(Vector2(-49, -9), Vector2(-27, -9), Color("b7d9de"), 2.0)
