@tool
class_name SpiderLegStroke3D
extends MeshInstance3D
## Draws camera-facing pen strokes through the spider's posed leg bones.

const LEG_SPECS := [
	["back", ".L", 7, "FootBackLeft"],
	["back", ".R", 7, "FootBackRight"],
	["front", ".L", 8, "FootFrontLeft"],
	["front", ".R", 8, "FootFrontRight"],
	["mid_back", ".L", 8, "FootMidBackLeft"],
	["mid_back", ".R", 8, "FootMidBackRight"],
	["mid_front", ".L", 8, "FootMidFrontLeft"],
	["mid_front", ".R", 8, "FootMidFrontRight"],
]

@export_node_path("Skeleton3D") var skeleton_path := NodePath(
	"../ImportedRig/RIG_spider/Skeleton3D"
)
@export_node_path("Node3D") var foot_targets_path := NodePath("../FootTargets")
@export_range(0.005, 0.5, 0.005, "or_greater") var stroke_width := 0.08:
	set(value):
		stroke_width = maxf(value, 0.005)
		_rebuild()
@export var stroke_color := Color("171313"):
	set(value):
		stroke_color = value
		if is_instance_valid(_material):
			_material.albedo_color = stroke_color
@export_range(0.0, 0.25, 0.005) var roughness := 0.015:
	set(value):
		roughness = maxf(value, 0.0)
		_rebuild()

var _skeleton: Skeleton3D
var _foot_targets: Node3D
var _leg_bone_indices: Array[PackedInt32Array] = []
var _stroke_mesh := ImmediateMesh.new()
var _material := StandardMaterial3D.new()


func _ready() -> void:
	mesh = _stroke_mesh
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_configure_material()
	_resolve_rig()
	_rebuild()


func _process(_delta: float) -> void:
	if not is_instance_valid(_skeleton) or not is_instance_valid(_foot_targets):
		_resolve_rig()


func _exit_tree() -> void:
	if (is_instance_valid(_skeleton)
			and _skeleton.skeleton_updated.is_connected(_on_skeleton_updated)):
		_skeleton.skeleton_updated.disconnect(_on_skeleton_updated)


func _configure_material() -> void:
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.vertex_color_use_as_albedo = true
	_material.albedo_color = stroke_color
	material_override = _material


func _resolve_rig() -> bool:
	var resolved_skeleton := get_node_or_null(skeleton_path) as Skeleton3D
	if is_instance_valid(_skeleton) and _skeleton != resolved_skeleton:
		if _skeleton.skeleton_updated.is_connected(_on_skeleton_updated):
			_skeleton.skeleton_updated.disconnect(_on_skeleton_updated)
	_skeleton = resolved_skeleton
	_foot_targets = get_node_or_null(foot_targets_path) as Node3D
	_leg_bone_indices.clear()
	if _skeleton == null or _foot_targets == null:
		return false
	if not _skeleton.skeleton_updated.is_connected(_on_skeleton_updated):
		_skeleton.skeleton_updated.connect(_on_skeleton_updated)
	for spec in LEG_SPECS:
		var indices := _resolve_leg_bones(spec)
		if indices.is_empty():
			_leg_bone_indices.clear()
			return false
		_leg_bone_indices.append(indices)
	return true


func _on_skeleton_updated() -> void:
	if is_inside_tree():
		_rebuild()


func _resolve_leg_bones(spec: Array) -> PackedInt32Array:
	var indices := PackedInt32Array()
	var group: String = spec[0]
	var suffix: String = spec[1]
	var bone_count: int = spec[2]
	for bone_number in range(1, bone_count + 1):
		var bone_name := "DEF_leg_%s_%02d%s" % [group, bone_number, suffix]
		var bone_index := _skeleton.find_bone(bone_name)
		if bone_index < 0:
			return PackedInt32Array()
		indices.append(bone_index)
	return indices


func _rebuild() -> void:
	if not is_instance_valid(_stroke_mesh):
		return
	_stroke_mesh.clear_surfaces()
	if _leg_bone_indices.size() != LEG_SPECS.size():
		return
	var camera_position := _camera_position()
	for leg_index in range(LEG_SPECS.size()):
		var points := _collect_leg_points(leg_index)
		if points.size() >= 2:
			_add_leg_surface(points, leg_index, camera_position)


func _collect_leg_points(leg_index: int) -> PackedVector3Array:
	var points := PackedVector3Array()
	for bone_index in _leg_bone_indices[leg_index]:
		var bone_transform := _skeleton.global_transform * _skeleton.get_bone_global_pose(
			bone_index
		)
		points.append(to_local(bone_transform.origin))
	var target_name: String = LEG_SPECS[leg_index][3]
	var foot_target := _foot_targets.get_node_or_null(target_name) as Node3D
	if foot_target != null:
		points.append(to_local(foot_target.global_position))
	return points


func _add_leg_surface(
	points: PackedVector3Array, leg_index: int, camera_position: Vector3
) -> void:
	_stroke_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for point_index in range(points.size()):
		var tangent := _point_tangent(points, point_index)
		var side := _stroke_side(points[point_index], tangent, camera_position)
		var center := points[point_index]
		if point_index > 0 and point_index < points.size() - 1:
			center += side * _rough_offset(leg_index, point_index)
		_stroke_mesh.surface_set_color(Color.WHITE)
		_stroke_mesh.surface_add_vertex(center - side * stroke_width * 0.5)
		_stroke_mesh.surface_set_color(Color.WHITE)
		_stroke_mesh.surface_add_vertex(center + side * stroke_width * 0.5)
	_stroke_mesh.surface_end()


func _point_tangent(points: PackedVector3Array, point_index: int) -> Vector3:
	if point_index == 0:
		return (points[1] - points[0]).normalized()
	if point_index == points.size() - 1:
		return (points[-1] - points[-2]).normalized()
	return (points[point_index + 1] - points[point_index - 1]).normalized()


func _stroke_side(point: Vector3, tangent: Vector3, camera_position: Vector3) -> Vector3:
	var view_direction := (camera_position - point).normalized()
	var side := view_direction.cross(tangent).normalized()
	if side.is_zero_approx():
		side = Vector3.UP.cross(tangent).normalized()
	if side.is_zero_approx():
		side = Vector3.RIGHT
	return side


func _camera_position() -> Vector3:
	var camera := get_viewport().get_camera_3d()
	if camera != null:
		return to_local(camera.global_position)
	return Vector3(0.0, 8.0, 12.0)


func _rough_offset(leg_index: int, point_index: int) -> float:
	var noise_input := float((leg_index + 1) * 97 + (point_index + 1) * 53)
	return sin(noise_input * 12.9898) * roughness
