extends SceneTree
## Verify the Blender-authored rig is wrapped with external foot targets.

const EXPECTED_FOOT_TARGETS := [
	"FootBackLeft",
	"FootBackRight",
	"FootFrontLeft",
	"FootFrontRight",
	"FootMidBackLeft",
	"FootMidBackRight",
	"FootMidFrontLeft",
	"FootMidFrontRight",
]
const TARGET_BONES := {
	"FootBackLeft": "CTRL_foot_back.L",
	"FootBackRight": "CTRL_foot_back.R",
	"FootFrontLeft": "CTRL_foot_front.L",
	"FootFrontRight": "CTRL_foot_front.R",
	"FootMidBackLeft": "CTRL_foot_mid_back.L",
	"FootMidBackRight": "CTRL_foot_mid_back.R",
	"FootMidFrontLeft": "CTRL_foot_mid_front.L",
	"FootMidFrontRight": "CTRL_foot_mid_front.R",
}
const EXPECTED_LEFT_LEG_ROOTS := {
	"DEF_leg_front_01.L": Vector3(-0.662302, 0.5, 0.544667),
	"DEF_leg_mid_front_01.L": Vector3(-0.732124, 0.5, 0.123694),
	"DEF_leg_mid_back_01.L": Vector3(-0.602005, 0.5, -0.366899),
	"DEF_leg_back_01.L": Vector3(-0.486562, 0.5, -0.656935),
}
const IK_SPECS := [
	["FootFrontLeft", "DEF_leg_front_01.L", "DEF_leg_front_08.L", 2],
	["FootFrontRight", "DEF_leg_front_01.R", "DEF_leg_front_08.R", 3],
	["FootMidFrontLeft", "DEF_leg_mid_front_01.L", "DEF_leg_mid_front_08.L", 6],
	["FootMidFrontRight", "DEF_leg_mid_front_01.R", "DEF_leg_mid_front_08.R", 7],
	["FootMidBackLeft", "DEF_leg_mid_back_01.L", "DEF_leg_mid_back_08.L", 4],
	["FootMidBackRight", "DEF_leg_mid_back_01.R", "DEF_leg_mid_back_08.R", 5],
	["FootBackLeft", "DEF_leg_back_01.L", "DEF_leg_back_07.L", 0],
	["FootBackRight", "DEF_leg_back_01.R", "DEF_leg_back_07.R", 1],
]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var wrapper := load("res://src/features/spiders/spider_rig.tscn") as PackedScene
	if wrapper == null:
		_fail("Spider rig wrapper did not load")
		return
	var rig := wrapper.instantiate()
	root.add_child(rig)
	await process_frame
	if (not _check_imported_rig(rig)
			or not _check_leg_strokes(rig)
			or not _check_ik_setup(rig)
			or not _check_base_spider()):
		return
	if not await _check_eye_tracking(rig):
		return
	if not await _check_ik_strokes(rig):
		return
	rig.free()
	print("SPIDER RIG PASS: armature, IK-driven leg strokes, and animated eye tracking")
	quit(0)


func _check_imported_rig(rig: Node) -> bool:
	var skeleton := rig.get_node_or_null("ImportedRig/RIG_spider/Skeleton3D") as Skeleton3D
	if skeleton == null or skeleton.get_bone_count() != 71:
		return _fail("Imported Blender rig must expose its 71-bone Skeleton3D")
	var targets := rig.get_node("FootTargets")
	if targets.get_child_count() != EXPECTED_FOOT_TARGETS.size():
		return _fail("Spider rig must expose exactly eight foot targets")
	for target_name in EXPECTED_FOOT_TARGETS:
		var target := rig.get_node_or_null("FootTargets/" + target_name) as Marker3D
		if target == null:
			return _fail("Missing external foot target: " + target_name)
		var bone_index := skeleton.find_bone(TARGET_BONES[target_name])
		if bone_index < 0:
			return _fail("Missing controller bone for target: " + target_name)
		var rest_position := skeleton.get_bone_global_rest(bone_index).origin
		if not target.position.is_equal_approx(rest_position):
			return _fail("Foot target no longer matches controller rest pose: " + target_name)
	return _check_leg_roots(skeleton)


func _check_leg_roots(skeleton: Skeleton3D) -> bool:
	for bone_name in EXPECTED_LEFT_LEG_ROOTS:
		var bone_index := skeleton.find_bone(bone_name)
		var rest_position := skeleton.get_bone_global_rest(bone_index).origin
		if not rest_position.is_equal_approx(EXPECTED_LEFT_LEG_ROOTS[bone_name]):
			return _fail("Imported leg root is stale: " + bone_name)
	return true


func _check_base_spider() -> bool:
	var base_scene := load("res://src/features/spiders/base_spider.tscn") as PackedScene
	var spider := base_scene.instantiate()
	if spider.get_node_or_null("SpiderRig") == null:
		return _fail("Base spider does not contain the armature wrapper")
	spider.free()
	return true


func _check_leg_strokes(rig: Node) -> bool:
	var strokes := rig.get_node_or_null("LegStrokes") as MeshInstance3D
	if strokes == null or strokes.mesh == null:
		return _fail("Spider rig must draw its leg strokes from the armature")
	if strokes.mesh.get_surface_count() != EXPECTED_FOOT_TARGETS.size():
		return _fail("Spider rig must draw exactly eight leg strokes")
	var width_value: Variant = strokes.get("stroke_width")
	if not width_value is float or width_value <= 0.0:
		return _fail("Leg stroke thickness must be adjustable")
	var arrays := strokes.mesh.surface_get_arrays(0)
	var vertices := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
	if vertices.size() < 2:
		return _fail("Leg stroke geometry must contain a ribbon")
	var rendered_width := vertices[0].distance_to(vertices[1])
	if not is_equal_approx(rendered_width, width_value):
		return _fail("Leg ribbon width must match the Inspector stroke width")
	return true


func _check_ik_setup(rig: Node) -> bool:
	var ik := rig.get_node_or_null(
		"ImportedRig/RIG_spider/Skeleton3D/CCDIK3D"
	) as CCDIK3D
	if ik == null or ik.setting_count != IK_SPECS.size():
		return _fail("Spider rig must configure one CCDIK setting per leg")
	for setting_index in range(IK_SPECS.size()):
		var spec: Array = IK_SPECS[setting_index]
		var prefix := "settings/%d/" % setting_index
		if ik.get(prefix + "root_bone_name") != spec[1]:
			return _fail("Wrong IK root bone for " + spec[0])
		if ik.get(prefix + "end_bone_name") != spec[2]:
			return _fail("Wrong IK end bone for " + spec[0])
		var expected_path := NodePath("../../../../FootTargets/" + spec[0])
		if ik.get(prefix + "target_node") != expected_path:
			return _fail("Wrong IK foot target for " + spec[0])
	return true


func _check_eye_tracking(rig: Node) -> bool:
	var eyes := rig.get_node_or_null("BoneAttachment3D/BodyOffset") as Node3D
	if eyes == null or eyes.get_script() == null:
		return _fail("Spider body must have a valid eye-tracking script")
	if not eyes.get_script().is_tool():
		return _fail("Spider eyes must preview while editing the scene")
	var target := eyes.get_node_or_null("LookAtPos") as Marker3D
	var left_eye := eyes.get_node_or_null("LeftEye") as Sprite3D
	var right_eye := eyes.get_node_or_null("RightEye") as Sprite3D
	var left_center := eyes.get_node_or_null("LeftEyeCenter") as Marker3D
	var right_center := eyes.get_node_or_null("RightEyeCenter") as Marker3D
	if (target == null or left_eye == null or right_eye == null
			or left_center == null or right_center == null):
		return _fail("Eye tracking requires two pupils and an animatable LookAtPos marker")
	var radius_value: Variant = eyes.get("eye_radius")
	if not radius_value is float or radius_value <= 0.0:
		return _fail("Eye movement radius must be adjustable")
	return await _check_eye_motion(eyes, radius_value)


func _check_eye_motion(eyes: Node3D, eye_radius: float) -> bool:
	var target := eyes.get_node("LookAtPos") as Marker3D
	var left_eye := eyes.get_node("LeftEye") as Sprite3D
	var right_eye := eyes.get_node("RightEye") as Sprite3D
	var left_center := eyes.get_node("LeftEyeCenter") as Marker3D
	var right_center := eyes.get_node("RightEyeCenter") as Marker3D
	eyes.set("influence", 0.0)
	await process_frame
	var left_neutral := left_eye.position
	var right_neutral := right_eye.position
	target.position = (left_center.position + right_center.position) * 0.5
	eyes.set("influence", 1.0)
	await process_frame
	var left_offset := left_eye.position - left_neutral
	var right_offset := right_eye.position - right_neutral
	if left_offset.x <= 0.0 or right_offset.x >= 0.0:
		return _fail("Pupils must converge toward a nearby centered target")
	if (not is_equal_approx(left_offset.length(), eye_radius)
			or not is_equal_approx(right_offset.length(), eye_radius)):
		return _fail(
			"Each pupil must clamp to the configured movement radius"
		)
	eyes.set("influence", 0.0)
	await process_frame
	if (not left_eye.position.is_equal_approx(left_neutral)
			or not right_eye.position.is_equal_approx(right_neutral)):
		return _fail("Pupils must return to their neutral positions")
	return true


func _check_ik_strokes(rig: Node) -> bool:
	var strokes := rig.get_node("LegStrokes") as MeshInstance3D
	var before_points: Array[Vector3] = []
	var original_positions: Array[Vector3] = []
	for spec in IK_SPECS:
		var target := rig.get_node("FootTargets/" + spec[0]) as Marker3D
		var surface: int = spec[3]
		before_points.append(_ribbon_point(strokes.mesh, surface, 4))
		original_positions.append(target.position)
		var tangent := Vector3(-target.position.z, 0.0, target.position.x).normalized()
		target.position += tangent * 0.3
	await process_frame
	await process_frame
	for spec_index in range(IK_SPECS.size()):
		var spec: Array = IK_SPECS[spec_index]
		var target := rig.get_node("FootTargets/" + spec[0]) as Marker3D
		var surface: int = spec[3]
		var after := _ribbon_point(strokes.mesh, surface, 4)
		if before_points[spec_index].distance_to(after) < 0.01:
			return _fail("Middle leg-stroke joint did not follow IK for " + spec[0])
		target.position = original_positions[spec_index]
	return true


func _ribbon_point(mesh: Mesh, surface: int, point: int) -> Vector3:
	var arrays := mesh.surface_get_arrays(surface)
	var vertices := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
	return (vertices[point * 2] + vertices[point * 2 + 1]) * 0.5


func _fail(message: String) -> bool:
	push_error("SPIDER RIG FAIL: " + message)
	quit(1)
	return false
