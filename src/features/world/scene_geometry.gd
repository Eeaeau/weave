class_name SceneGeometry3D
extends RefCounted
## Small reusable meshes for temporary 3D arena art.


static func material(color: Color) -> StandardMaterial3D:
	var surface := StandardMaterial3D.new()
	surface.albedo_color = color
	surface.roughness = 1.0
	return surface


static func sphere(parent: Node3D, center: Vector3, radius: float, color: Color) -> MeshInstance3D:
	var shape := SphereMesh.new()
	shape.radius = radius
	shape.height = radius * 2.0
	var instance := MeshInstance3D.new()
	instance.mesh = shape
	instance.material_override = material(color)
	instance.position = center
	parent.add_child(instance)
	return instance


static func segment(
	parent: Node3D, start: Vector3, finish: Vector3, radius: float, color: Color
) -> MeshInstance3D:
	var shape := CylinderMesh.new()
	shape.top_radius = radius
	shape.bottom_radius = radius
	shape.height = start.distance_to(finish)
	var instance := MeshInstance3D.new()
	instance.mesh = shape
	instance.material_override = material(color)
	instance.position = (start + finish) * 0.5
	instance.quaternion = Quaternion(Vector3.UP, (finish - start).normalized())
	parent.add_child(instance)
	return instance
