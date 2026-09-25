class_name WindborneInsect2D
extends Collectible2D
## Insect visual; drifting and catching are not connected yet.


func _draw() -> void:
	super._draw()
	draw_circle(Vector2(-7, -5), 7.0, Color("b8d9a2"))
	draw_circle(Vector2(7, -5), 7.0, Color("b8d9a2"))
	draw_circle(Vector2.ZERO, 5.0, Color("5a7246"))
