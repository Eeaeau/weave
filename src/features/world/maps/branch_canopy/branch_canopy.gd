class_name BranchCanopy2D
extends Node2D
## Placeholder tree backdrop and starting branches for the first arena.


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(1280, 720)), Color("132b35"))
	for center in [Vector2(95, 108), Vector2(345, 55), Vector2(958, 80), Vector2(1180, 143)]:
		draw_circle(center, 110.0, Color("214a47"))
		draw_circle(center + Vector2(30, 20), 76.0, Color("2b5951"))
	var left_branch := PackedVector2Array([
		Vector2(0, 345), Vector2(245, 337), Vector2(436, 365),
		Vector2(442, 399), Vector2(260, 376), Vector2(0, 391),
	])
	var right_branch := PackedVector2Array([
		Vector2(1280, 345), Vector2(1035, 337), Vector2(844, 365),
		Vector2(838, 399), Vector2(1020, 376), Vector2(1280, 391),
	])
	draw_colored_polygon(left_branch, Color("755741"))
	draw_colored_polygon(right_branch, Color("755741"))
	draw_line(Vector2(0, 346), Vector2(260, 337), Color("ac8054"), 6.0)
	draw_line(Vector2(1280, 346), Vector2(1020, 337), Color("ac8054"), 6.0)
