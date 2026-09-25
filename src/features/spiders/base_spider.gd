class_name BaseSpider3D
extends Node3D
## Shared spider identity with a flat sprite in the 3D arena.

@export var team_name: String = "Team"
@export var body_color: Color = Color("b9d8a5")


func _ready() -> void:
	$Sprite3D.modulate = body_color
