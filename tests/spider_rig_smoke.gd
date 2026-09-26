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


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var wrapper := load("res://src/features/spiders/spider_rig.tscn") as PackedScene
	if wrapper == null:
		_fail("Spider rig wrapper did not load")
		return
	var rig := wrapper.instantiate()
	root.add_child(rig)
	var skeleton := rig.get_node_or_null("ImportedRig/RIG_spider/Skeleton3D") as Skeleton3D
	if skeleton == null or skeleton.get_bone_count() != 71:
		_fail("Imported Blender rig must expose its 71-bone Skeleton3D")
		return
	for target_name in EXPECTED_FOOT_TARGETS:
		if not rig.get_node_or_null("FootTargets/" + target_name) is Marker3D:
			_fail("Missing external foot target: " + target_name)
			return
	var base_scene := load("res://src/features/spiders/base_spider.tscn") as PackedScene
	var spider := base_scene.instantiate()
	if spider.get_node_or_null("SpiderRig") == null:
		_fail("Base spider does not contain the armature wrapper")
		return
	spider.free()
	rig.free()
	print("SPIDER RIG PASS: 71 bones and 8 external foot targets")
	quit(0)


func _fail(message: String) -> void:
	push_error("SPIDER RIG FAIL: " + message)
	quit(1)
