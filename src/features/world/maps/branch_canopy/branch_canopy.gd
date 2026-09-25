class_name BranchCanopy3D
extends Node3D
## Temporary tree branches and foliage at several depths.


func _ready() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("142832")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("a5c9bb")
	environment.ambient_light_energy = 0.55
	$WorldEnvironment.environment = environment

	SceneGeometry3D.segment(self, Vector3(-10, -0.2, 0), Vector3(-4.5, 0, 0), 0.42, Color("79583d"))
	SceneGeometry3D.segment(self, Vector3(10, -0.2, 0), Vector3(4.5, 0, 0), 0.42, Color("79583d"))
	var far_foliage := [
		Vector3(-8, -2, -7), Vector3(-3, -3, -9), Vector3(4, -3, -9), Vector3(9, -2, -7),
	]
	for center in far_foliage:
		SceneGeometry3D.sphere(self, center, 2.3, Color("315a4e"))
	for center in [Vector3(-10, 1, 5), Vector3(10, 1, 5)]:
		SceneGeometry3D.sphere(self, center, 1.5, Color("244c42"))
