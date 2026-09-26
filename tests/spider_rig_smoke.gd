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
const EXPECTED_LEFT_LEG_ROOTS := {
	"DEF_leg_front_01.L": Vector3(-0.662302, 0.5, 0.544667),
	"DEF_leg_mid_front_01.L": Vector3(-0.732124, 0.5, 0.123694),
	"DEF_leg_mid_back_01.L": Vector3(-0.602005, 0.5, -0.366899),
	"DEF_leg_back_01.L": Vector3(-0.486562, 0.5, -0.656935),
}
const GAMEPLAY_SPIDER_SCENES := [
	"res://src/features/spiders/base_spider.tscn",
	"res://src/features/spiders/player_spider.tscn",
	"res://src/features/spiders/opponent_spider.tscn",
]
const IK_SPECS := [
	[
		"FrontLeft",
		"FootFrontLeft",
		"LiftFrontLeft",
		"DEF_leg_front_01.L",
		"DEF_leg_front_04.L",
		"DEF_leg_front_08.L",
		2,
		8,
		0.2471447,
	],
	[
		"FrontRight",
		"FootFrontRight",
		"LiftFrontRight",
		"DEF_leg_front_01.R",
		"DEF_leg_front_04.R",
		"DEF_leg_front_08.R",
		3,
		8,
		0.2471447,
	],
	[
		"MidFrontLeft",
		"FootMidFrontLeft",
		"LiftMidFrontLeft",
		"DEF_leg_mid_front_01.L",
		"DEF_leg_mid_front_04.L",
		"DEF_leg_mid_front_08.L",
		6,
		8,
		0.2464449,
	],
	[
		"MidFrontRight",
		"FootMidFrontRight",
		"LiftMidFrontRight",
		"DEF_leg_mid_front_01.R",
		"DEF_leg_mid_front_04.R",
		"DEF_leg_mid_front_08.R",
		7,
		8,
		0.2464449,
	],
	[
		"MidBackLeft",
		"FootMidBackLeft",
		"LiftMidBackLeft",
		"DEF_leg_mid_back_01.L",
		"DEF_leg_mid_back_04.L",
		"DEF_leg_mid_back_08.L",
		4,
		8,
		0.2512192,
	],
	[
		"MidBackRight",
		"FootMidBackRight",
		"LiftMidBackRight",
		"DEF_leg_mid_back_01.R",
		"DEF_leg_mid_back_04.R",
		"DEF_leg_mid_back_08.R",
		5,
		8,
		0.2512192,
	],
	[
		"BackLeft",
		"FootBackLeft",
		"LiftBackLeft",
		"DEF_leg_back_01.L",
		"DEF_leg_back_04.L",
		"DEF_leg_back_07.L",
		0,
		7,
		0.2292308,
	],
	[
		"BackRight",
		"FootBackRight",
		"LiftBackRight",
		"DEF_leg_back_01.R",
		"DEF_leg_back_04.R",
		"DEF_leg_back_07.R",
		1,
		7,
		0.2292308,
	],
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
	if not await _check_gameplay_spiders():
		return
	if not _check_player_faces_movement():
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
	var lift_targets := rig.get_node_or_null("LiftTargets")
	if lift_targets == null or lift_targets.get_child_count() != IK_SPECS.size():
		return _fail("Spider rig must expose exactly eight leg lift targets")
	for target_name in EXPECTED_FOOT_TARGETS:
		var target := rig.get_node_or_null("FootTargets/" + target_name) as Marker3D
		if target == null:
			return _fail("Missing external foot target: " + target_name)
	if not _check_body_attachment(rig, skeleton):
		return false
	return _check_leg_roots(skeleton)


func _check_body_attachment(rig: Node, skeleton: Skeleton3D) -> bool:
	var attachment := rig.get_node_or_null("BoneAttachment3D") as BoneAttachment3D
	if attachment == null or not attachment.use_external_skeleton:
		return _fail("Spider body must use an external Skeleton3D attachment")
	if attachment.external_skeleton != NodePath("../ImportedRig/RIG_spider/Skeleton3D"):
		return _fail("Spider body attachment must reference the imported skeleton")
	if attachment.bone_name != "CTRL_root":
		return _fail("Spider body attachment must follow CTRL_root")
	if attachment.get_skeleton() != skeleton:
		return _fail("Spider body attachment did not resolve its external skeleton")
	return true


func _check_leg_roots(skeleton: Skeleton3D) -> bool:
	for bone_name in EXPECTED_LEFT_LEG_ROOTS:
		var bone_index := skeleton.find_bone(bone_name)
		var rest_position := skeleton.get_bone_global_rest(bone_index).origin
		if not rest_position.is_equal_approx(EXPECTED_LEFT_LEG_ROOTS[bone_name]):
			return _fail("Imported leg root is stale: " + bone_name)
	return true


func _check_base_spider() -> bool:
	for scene_path in GAMEPLAY_SPIDER_SCENES:
		var scene := load(scene_path) as PackedScene
		var spider := scene.instantiate()
		if spider.get_node_or_null("SpiderRig") == null:
			spider.free()
			return _fail("Gameplay spider does not contain the armature wrapper")
		if spider.get_node_or_null("Sprite3D") != null:
			spider.free()
			return _fail("Gameplay spider still contains the legacy placeholder sprite")
		spider.free()
	return true


func _check_gameplay_spiders(scene_index: int = 0) -> bool:
	if scene_index >= GAMEPLAY_SPIDER_SCENES.size():
		return true
	var scene := load(GAMEPLAY_SPIDER_SCENES[scene_index]) as PackedScene
	var spider := scene.instantiate() as BaseSpider3D
	root.add_child(spider)
	await process_frame
	var body := spider.get_node_or_null(
		"SpiderRig/BoneAttachment3D/BodyOffset/Body"
	) as Sprite3D
	if body == null or not body.modulate.is_equal_approx(Color.WHITE):
		spider.queue_free()
		return _fail(
			"Gameplay spider must preserve the original body and eye colors: "
			+ GAMEPLAY_SPIDER_SCENES[scene_index]
		)
	spider.queue_free()
	await process_frame
	return await _check_gameplay_spiders(scene_index + 1)


func _check_player_faces_movement() -> bool:
	var scene := load("res://src/features/spiders/player_spider.tscn") as PackedScene
	var spider := scene.instantiate() as PlayerSpider3D
	root.add_child(spider)
	spider.set_process(false)
	spider.is_active = true
	var root_basis := spider.basis
	var directions := [
		["move_right", Vector3.RIGHT],
		["move_left", Vector3.LEFT],
		["move_up", Vector3.FORWARD],
		["move_down", Vector3.BACK],
	]
	for direction in directions:
		spider.remaining_movement = 10.0
		Input.action_press(direction[0])
		spider._process(0.1)
		Input.action_release(direction[0])
		var visual := spider.get_node("SpiderRig") as Node3D
		if visual.basis.z.normalized().dot(direction[1]) < 0.999:
			spider.free()
			return _fail("Spider rig did not face movement: " + direction[0])
	if not spider.basis.is_equal_approx(root_basis):
		spider.free()
		return _fail("Visual turning must not rotate the player gameplay root")
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
	var skeleton_path := "ImportedRig/RIG_spider/Skeleton3D/"
	var skeleton := rig.get_node("ImportedRig/RIG_spider/Skeleton3D") as Skeleton3D
	var modifier_count := 0
	for child in skeleton.get_children():
		if child is CCDIK3D:
			modifier_count += 1
	if modifier_count != IK_SPECS.size():
		return _fail("Spider rig must contain exactly one CCDIK modifier per leg")
	for spec in IK_SPECS:
		if not _check_ik_spec(rig, skeleton_path, spec):
			return false
	return true


func _check_ik_spec(rig: Node, skeleton_path: String, spec: Array) -> bool:
	var ik := rig.get_node_or_null(skeleton_path + "CCDIK3D_" + spec[0]) as CCDIK3D
	if ik == null or ik.setting_count != 2:
		return _fail("Each leg must have a two-stage CCDIK modifier: " + spec[0])
	if (ik.get("settings/0/root_bone_name") != spec[3]
		or ik.get("settings/0/end_bone_name") != spec[4]):
		return _fail("Wrong upper IK chain for " + spec[0])
	if (ik.get("settings/1/root_bone_name") != spec[4]
		or ik.get("settings/1/end_bone_name") != spec[5]):
		return _fail("Wrong lower IK chain for " + spec[0])
	return _check_ik_targets(ik, spec)


func _check_ik_targets(ik: CCDIK3D, spec: Array) -> bool:
	var lift_path := NodePath("../../../../LiftTargets/" + spec[2])
	var foot_path := NodePath("../../../../FootTargets/" + spec[1])
	if ik.get("settings/0/target_node") != lift_path:
		return _fail("Wrong lift target for " + spec[0])
	if ik.get("settings/1/target_node") != foot_path:
		return _fail("Wrong foot target for " + spec[0])
	if not ik.get("settings/1/extend_end_bone"):
		return _fail("Lower IK chain must extend to the foot target for " + spec[0])
	if ik.get("settings/1/end_bone/direction") != 6:
		return _fail("Lower IK chain must extend from the authored tail for " + spec[0])
	if not is_equal_approx(ik.get("settings/1/end_bone/length"), spec[8]):
		return _fail("Wrong lower IK tail length for " + spec[0])
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
	var body := eyes.get_node_or_null("Body") as Sprite3D
	var left_center := eyes.get_node_or_null("LeftEyeCenter") as Marker3D
	var right_center := eyes.get_node_or_null("RightEyeCenter") as Marker3D
	if (target == null or body == null or left_eye == null or right_eye == null
			or left_center == null or right_center == null):
		return _fail("Eye tracking requires two pupils and an animatable LookAtPos marker")
	var radius_value: Variant = eyes.get("eye_radius")
	if not radius_value is float or radius_value <= 0.0:
		return _fail("Eye movement radius must be adjustable")
	if not _check_eye_idle_animation(eyes, target):
		return false
	return await _check_eye_motion(eyes, radius_value)


func _check_eye_alignment(
	eyes: Node3D,
	body: Sprite3D,
	left_eye: Sprite3D,
	right_eye: Sprite3D,
) -> bool:
	for pupil in [left_eye, right_eye]:
		var property_name := "left_neutral_position"
		if pupil == right_eye:
			property_name = "right_neutral_position"
		var neutral: Vector3 = eyes.get(property_name)
		var neutral_plane := Vector2(neutral.x, neutral.z)
		var body_plane := Vector2(body.position.x, body.position.z)
		if neutral_plane.distance_to(body_plane) > 0.025:
			return _fail("Pupil neutral position must align with its socket artwork")
	return true


func _check_eye_idle_animation(eyes: Node3D, target: Marker3D) -> bool:
	var player := eyes.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if player == null or not player.has_animation("eye_idle"):
		return _fail("Spider eyes require an eye_idle animation")
	var idle := player.get_animation("eye_idle")
	if idle.loop_mode == Animation.LOOP_NONE:
		return _fail("Spider eye idle animation must loop")
	if not player.is_playing() or player.current_animation != "eye_idle":
		return _fail("Spider eye idle animation must autoplay")
	var initial_target := target.position
	player.advance(1.0)
	if target.position.is_equal_approx(initial_target):
		return _fail("Spider eye idle animation must move LookAtPos")
	return true


func _check_eye_motion(eyes: Node3D, eye_radius: float) -> bool:
	var body := eyes.get_node("Body") as Sprite3D
	var target := eyes.get_node("LookAtPos") as Marker3D
	var left_eye := eyes.get_node("LeftEye") as Sprite3D
	var right_eye := eyes.get_node("RightEye") as Sprite3D
	var left_center := eyes.get_node("LeftEyeCenter") as Marker3D
	var right_center := eyes.get_node("RightEyeCenter") as Marker3D
	if not _check_eye_alignment(eyes, body, left_eye, right_eye):
		return false
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
	return await _check_leg_stroke(rig, strokes, 0)


func _check_leg_stroke(rig: Node, strokes: MeshInstance3D, spec_index: int) -> bool:
	if spec_index >= IK_SPECS.size():
		return true
	var spec: Array = IK_SPECS[spec_index]
	if not await _check_lift_control(rig, strokes, spec):
		return false
	if not await _check_foot_control(rig, strokes, spec):
		return false
	return await _check_leg_stroke(rig, strokes, spec_index + 1)


func _check_lift_control(rig: Node, strokes: MeshInstance3D, spec: Array) -> bool:
	var lift := rig.get_node("LiftTargets/" + spec[2]) as Marker3D
	var original_position := lift.position
	var before := _ribbon_point(strokes.mesh, spec[6], 3)
	lift.position += Vector3.UP * 0.2
	await process_frame
	await process_frame
	var after := _ribbon_point(strokes.mesh, spec[6], 3)
	lift.position = original_position
	await process_frame
	await process_frame
	if before.distance_to(after) < 0.005:
		return _fail("Middle leg joint did not follow lift target for " + spec[0])
	return true


func _check_foot_control(rig: Node, strokes: MeshInstance3D, spec: Array) -> bool:
	var foot := rig.get_node("FootTargets/" + spec[1]) as Marker3D
	var original_position := foot.position
	var before := _ribbon_point(strokes.mesh, spec[6], spec[7] - 1)
	var tangent := Vector3(-foot.position.z, 0.0, foot.position.x).normalized()
	foot.position += tangent * 0.2
	await process_frame
	await process_frame
	var after := _ribbon_point(strokes.mesh, spec[6], spec[7] - 1)
	var rendered_tip := strokes.to_global(_ribbon_point(strokes.mesh, spec[6], spec[7]))
	var target_distance := rendered_tip.distance_to(foot.global_position)
	if target_distance > 0.03:
		return _fail(
			"Rendered leg missed foot target for %s by %.4f"
			% [spec[0], target_distance]
		)
	foot.position = original_position
	await process_frame
	await process_frame
	if before.distance_to(after) < 0.005:
		return _fail("End leg joint did not follow foot target for " + spec[0])
	return true


func _ribbon_point(mesh: Mesh, surface: int, point: int) -> Vector3:
	var arrays := mesh.surface_get_arrays(surface)
	var vertices := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
	return (vertices[point * 2] + vertices[point * 2 + 1]) * 0.5


func _fail(message: String) -> bool:
	push_error("SPIDER RIG FAIL: " + message)
	quit(1)
	return false
