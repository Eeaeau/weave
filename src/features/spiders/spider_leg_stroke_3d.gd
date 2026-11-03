@tool
class_name SpiderLegStroke3D
extends MeshInstance3D
## Draws camera-facing pen strokes through the spider's posed leg bones.

signal pose_drawn

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

var _body: Sprite3D
var _gait: SpiderLegController3D
var _walking_plane := Plane()
var _skeleton: Skeleton3D
var _foot_targets: Node3D
var _leg_bone_indices: Array[PackedInt32Array] = []
var _tip_lengths: Array[float] = []
var _stroke_mesh := ImmediateMesh.new()
var _material := StandardMaterial3D.new()
var _web_deformation: Node
var _tip_contact: Dictionary = {}
var _body_warp := Vector3.ZERO
var _foot_warp := Vector3.ZERO
var _drawing_warp := Vector3.ZERO
var _posed_legs: Array[PackedVector3Array] = []
var _draw_queued := false
var _pose_dirty := true
var _render_frame := -1


func _ready() -> void:
	mesh = _stroke_mesh
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_configure_material()
	_resolve_rig()
	_rebuild()


func _process(_delta: float) -> void:
	if not is_instance_valid(_skeleton) or not is_instance_valid(_foot_targets):
		_resolve_rig()
	var deforming := (_gait != null and _gait.has_method("get_deformation")
		and _gait.get_deformation() != null)
	if _pose_dirty or deforming:
		_queue_redraw()


func _exit_tree() -> void:
	if (is_instance_valid(_skeleton)
			and _skeleton.skeleton_updated.is_connected(_on_skeleton_updated)):
		_skeleton.skeleton_updated.disconnect(_on_skeleton_updated)


func _configure_material() -> void:
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS
	_material.vertex_color_use_as_albedo = true
	_material.albedo_color = stroke_color
	material_override = _material


func _resolve_rig() -> bool:
	_body = get_node_or_null("../BoneAttachment3D/BodyOffset/Body") as Sprite3D
	if not Engine.is_editor_hint():
		_gait = get_node_or_null("../LegController") as SpiderLegController3D
	var resolved_skeleton := get_node_or_null(skeleton_path) as Skeleton3D
	if is_instance_valid(_skeleton) and _skeleton != resolved_skeleton:
		if _skeleton.skeleton_updated.is_connected(_on_skeleton_updated):
			_skeleton.skeleton_updated.disconnect(_on_skeleton_updated)
	_skeleton = resolved_skeleton
	_foot_targets = get_node_or_null(foot_targets_path) as Node3D
	_leg_bone_indices.clear()
	_tip_lengths.clear()
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
		var solver := _skeleton.get_node("CCDIK3D_" + str(spec[3]).trim_prefix("Foot"))
		_tip_lengths.append(float(solver.get("settings/1/end_bone/length")))
	return true


func _on_skeleton_updated() -> void:
	if is_inside_tree():
		_capture_pose()
		_queue_redraw()


func _capture_pose() -> void:
	_posed_legs.clear()
	for indices in _leg_bone_indices:
		var points := PackedVector3Array()
		for bone_index in indices:
			var bone_pose := _skeleton.get_bone_global_pose(bone_index)
			var bone_transform := _skeleton.global_transform * bone_pose
			points.append(to_local(bone_transform.origin))
		_posed_legs.append(points)
	_pose_dirty = true


func _queue_redraw() -> void:
	if not _draw_queued and _render_frame != Engine.get_process_frames():
		_draw_queued = true
		call_deferred("_rebuild")


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
	_draw_queued = false
	if not is_inside_tree():
		return
	if _render_frame == Engine.get_process_frames():
		return
	if not is_instance_valid(_stroke_mesh):
		return
	_stroke_mesh.clear_surfaces()
	if _leg_bone_indices.size() != LEG_SPECS.size():
		return
	if is_instance_valid(_body):
		var rig := get_parent_node_3d()
		var plane := rig.get_parent_node_3d()
		var normal := (rig if plane == null else plane).global_basis.y.normalized()
		var depth := INF
		var bounds := _body.get_aabb()
		for corner in range(8):
			depth = minf(depth, (_body.global_transform * bounds.get_endpoint(corner)).dot(normal))
		_walking_plane = Plane(normal, depth - 0.01)
	if _posed_legs.size() != LEG_SPECS.size():
		_capture_pose()
	var camera_position := _camera_position()
	for leg_index in range(LEG_SPECS.size()):
		var points := _collect_leg_points(leg_index)
		if points.size() >= 2:
			_add_leg_surface(points, leg_index, camera_position)
	_render_frame = Engine.get_process_frames()
	_pose_dirty = false
	pose_drawn.emit()


func _collect_leg_points(leg_index: int) -> PackedVector3Array:
	_tip_contact = {}
	var points := _posed_legs[leg_index].duplicate()
	var target_name: String = LEG_SPECS[leg_index][3]
	var foot_target := _foot_targets.get_node_or_null(target_name) as Node3D
	if foot_target != null:
		var end := to_global(points[-1])
		var length := _tip_lengths[leg_index] * _skeleton.global_basis.y.length()
		points.append(to_local(end.move_toward(foot_target.global_position, length)))
	_web_deformation = null
	_body_warp = Vector3.ZERO
	_foot_warp = Vector3.ZERO
	if _gait != null and _gait.has_method("get_deformation"):
		_web_deformation = _gait.get_deformation()
	if _web_deformation != null and not points.is_empty():
		var foot_index: int = _gait.FOOT_NAMES.find(target_name)
		var actor := _gait.get_parent().get_parent() as Node3D
		_body_warp = _web_deformation.displacement_at(actor.global_position)
		var raw_tip := to_global(points[-1])
		_foot_warp = _body_warp
		if not _gait.is_carried(foot_index):
			_foot_warp = _web_deformation.displacement_at(raw_tip)
		_web_deformation.observe_foot(_gait, foot_index, raw_tip)
		_tip_contact = _web_deformation.contact_target(_gait, foot_index)
		if not _tip_contact.is_empty():
			if raw_tip.distance_to(_tip_contact.anchor) <= _web_deformation.maximum_contact_gap:
				var correction: Vector3 = _tip_contact.base - raw_tip
				_foot_warp = _tip_contact.warp
				for distance in range(mini(3, points.size())):
					var point_index := points.size() - 1 - distance
					var influence := 1.0 - float(distance) / 3.0
					var adjusted := to_global(points[point_index]) + correction * influence
					points[point_index] = to_local(adjusted)
			else:
				_tip_contact = {}
	return points


func _add_leg_surface(
	points: PackedVector3Array, leg_index: int, camera_position: Vector3
) -> void:
	var foot_index: int = _gait.FOOT_NAMES.find(LEG_SPECS[leg_index][3]) if _gait != null else -1
	var walking := _gait == null or not _gait.is_carried(foot_index)
	_stroke_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for point_index in range(points.size()):
		var along := float(point_index) / maxf(points.size() - 1, 1)
		_drawing_warp = _body_warp.lerp(_foot_warp, smoothstep(0.0, 1.0, along))
		var tangent := _point_tangent(points, point_index)
		var side := _stroke_side(points[point_index], tangent, camera_position)
		var center := points[point_index]
		if point_index > 0 and point_index < points.size() - 1:
			center += side * _rough_offset(leg_index, point_index)
		_stroke_mesh.surface_set_color(Color.WHITE)
		_stroke_mesh.surface_add_vertex(_layer_vertex(center - side * stroke_width * 0.5, walking))
		_stroke_mesh.surface_set_color(Color.WHITE)
		_stroke_mesh.surface_add_vertex(_layer_vertex(center + side * stroke_width * 0.5, walking))
	_stroke_mesh.surface_end()


func _layer_vertex(point: Vector3, walking: bool) -> Vector3:
	# Walking legs stay behind the flat body art; carrying hands retain real depth.
	var world_point := to_global(point)
	if walking:
		world_point -= _walking_plane.normal * maxf(0.0, _walking_plane.distance_to(world_point))
	world_point += _drawing_warp
	return to_local(world_point)


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
