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
			or not _check_base_spider()):
		return
	rig.free()
	print("SPIDER RIG PASS: 71 bones, 8 foot targets, and 8 adjustable leg strokes")
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


func _fail(message: String) -> bool:
	push_error("SPIDER RIG FAIL: " + message)
	quit(1)
	return false
