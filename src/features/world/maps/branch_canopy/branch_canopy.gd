class_name BranchCanopy3D
extends Node3D
## Layered 2D artwork placed at several depths in the 3D arena.


func _ready() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("142832")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("a5c9bb")
	environment.ambient_light_energy = 0.55
	$WorldEnvironment.environment = environment
