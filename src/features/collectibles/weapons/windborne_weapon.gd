class_name WindborneWeapon3D
extends Collectible3D
## Temporary weapon shape; wind behavior is planned separately.


func _ready() -> void:
	SceneGeometry3D.sphere(self, Vector3.ZERO, 0.22, Color("f3d977"))
