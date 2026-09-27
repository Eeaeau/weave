@tool
extends StaticBody3D
## Keeps each blocker instance's visible capsule and collision capsule in sync.

@export_range(0.05, 1.0, 0.005) var capsule_radius := 0.125:
	set(value):
		capsule_radius = value
		if is_node_ready():
			_apply_dimensions()
@export_range(0.25, 5.0, 0.05) var capsule_height := 0.5:
	set(value):
		capsule_height = value
		if is_node_ready():
			_apply_dimensions()


func _ready() -> void:
	var collision_shape := $CollisionShape3D as CollisionShape3D
	var visual_capsule := $VisualCapsule as MeshInstance3D
	collision_shape.shape = collision_shape.shape.duplicate()
	visual_capsule.mesh = visual_capsule.mesh.duplicate()
	_apply_dimensions()


func _apply_dimensions() -> void:
	var collision_shape := $CollisionShape3D.shape as CapsuleShape3D
	var visual_mesh := $VisualCapsule.mesh as CapsuleMesh
	var height := maxf(capsule_height, capsule_radius * 2.0)
	collision_shape.height = height
	collision_shape.radius = capsule_radius
	visual_mesh.height = height
	visual_mesh.radius = capsule_radius
