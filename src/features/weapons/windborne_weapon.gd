class_name WindborneWeapon2D
extends Collectible2D
## Visual marker for a weapon arriving on the wind; spawning comes later.


func _draw() -> void:
	super._draw()
	var points := PackedVector2Array([
		Vector2(0, -13), Vector2(13, 0), Vector2(0, 13), Vector2(-13, 0),
	])
	draw_colored_polygon(points, Color("f3d977"))
