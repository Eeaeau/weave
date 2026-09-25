class_name BaseSpider2D
extends Node2D
## Shared identity and placeholder art for a spider in the match.

@export var team_name: String = "Team"
@export var body_color: Color = Color("b9d8a5")


func _draw() -> void:
	for side in [-1, 1]:
		for leg in 3:
			var start := Vector2(side * 7, (leg - 1) * 5)
			var tip := Vector2(side * (23 + leg * 3), (leg - 1) * 11)
			draw_line(start, tip, body_color, 3.0)
	draw_circle(Vector2.ZERO, 14.0, body_color)
	draw_circle(Vector2(-5, -3), 2.0, Color("14252a"))
	draw_circle(Vector2(5, -3), 2.0, Color("14252a"))
