class_name WindborneInsect3D
extends Collectible3D
## Temporary insect shape; wind behavior is planned separately.


func _ready() -> void:
	SceneGeometry3D.sphere(self, Vector3.ZERO, 0.12, Color("5a7246"))
	SceneGeometry3D.sphere(self, Vector3(-0.17, 0.03, 0), 0.14, Color("b8d9a2"))
	SceneGeometry3D.sphere(self, Vector3(0.17, 0.03, 0), 0.14, Color("b8d9a2"))
