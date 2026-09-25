class_name BaseSpider3D
extends Node3D
## Shared spider identity and temporary 3D body.

@export var team_name: String = "Team"
@export var body_color: Color = Color("b9d8a5")


func _ready() -> void:
	SceneGeometry3D.sphere(self, Vector3(0, 0.18, 0), 0.19, body_color)
	for side in [-1.0, 1.0]:
		for leg in 4:
			var z: float = (float(leg) - 1.5) * 0.16
			SceneGeometry3D.segment(
				self, Vector3(side * 0.1, 0.16, z), Vector3(side * 0.37, 0.04, z * 1.7),
				0.025, body_color
			)
