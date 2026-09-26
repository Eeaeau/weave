class_name ShadowComponent extends Node3D

@export var mesh: MeshInstance3D

var initial_radius: float
var cylinder: CylinderMesh


func _ready() -> void:
	assert(mesh.mesh is CylinderMesh, "shadow must be a cylinder")
	cylinder = mesh.mesh
	initial_radius = cylinder.top_radius


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	global_position.y = 0
	var parent_height = get_parent_node_3d().position.y
	var radius = min(initial_radius, initial_radius / parent_height)
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
