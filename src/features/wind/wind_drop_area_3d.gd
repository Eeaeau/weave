@tool
class_name WindDropArea3D
extends Node3D
## Move and scale this area in the editor to set wind entry and contact bounds.


func _ready() -> void:
	if Engine.is_editor_hint():
		_create_editor_preview()


func sample_world_point(random: RandomNumberGenerator, side: int,
		upper_half: bool = false) -> Vector3:
	var min_x := -0.5 if side == 0 else 0.0
	var max_x := 0.0 if side == 0 else 0.5
	var max_z := 0.0 if upper_half else 0.5
	return to_global(Vector3(
		random.randf_range(min_x, max_x),
		0.0,
		random.randf_range(-0.5, max_z),
	))


func _create_editor_preview() -> void:
	if get_node_or_null("EditorDropArea") != null:
		return
	var preview := Node3D.new()
	preview.name = "EditorDropArea"
	add_child(preview)

	var fill := MeshInstance3D.new()
	fill.name = "Fill"
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE
	fill.mesh = plane
	var fill_material := StandardMaterial3D.new()
	fill_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fill_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fill_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	fill_material.no_depth_test = true
	fill_material.albedo_color = Color(0.9, 0.7, 0.22, 0.18)
	fill.material_override = fill_material
	preview.add_child(fill)

	var outline := MeshInstance3D.new()
	outline.name = "Outline"
	var lines := ImmediateMesh.new()
	lines.surface_begin(Mesh.PRIMITIVE_LINES)
	var corners := [
		Vector3(-0.5, 0.0, -0.5), Vector3(0.5, 0.0, -0.5),
		Vector3(0.5, 0.0, 0.5), Vector3(-0.5, 0.0, 0.5),
	]
	for index in range(corners.size()):
		lines.surface_add_vertex(corners[index])
		lines.surface_add_vertex(corners[(index + 1) % corners.size()])
	lines.surface_end()
	outline.mesh = lines
	var line_material := StandardMaterial3D.new()
	line_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	line_material.no_depth_test = true
	line_material.albedo_color = Color(1.0, 0.76, 0.27)
	outline.material_override = line_material
	preview.add_child(outline)
