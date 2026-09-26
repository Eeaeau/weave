extends SceneTree
## Exercise the real spider rig's world-planted, alternating free-step targets.

const SPIDER_SCENE := preload("res://src/features/spiders/base_spider.tscn")
const GROUP_A := [
	"FootFrontLeft", "FootMidFrontRight", "FootMidBackLeft", "FootBackRight",
]
const GROUP_B := [
	"FootFrontRight", "FootMidFrontLeft", "FootMidBackRight", "FootBackLeft",
]
const FOOT_NAMES := [
	"FootFrontLeft", "FootFrontRight", "FootMidFrontLeft", "FootMidFrontRight",
	"FootMidBackLeft", "FootMidBackRight", "FootBackLeft", "FootBackRight",
]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var spider := SPIDER_SCENE.instantiate()
	root.add_child(spider)
	var controller := spider.get_node_or_null("SpiderRig/LegController") as Node3D
	if controller == null:
		_fail("Spider rig has no leg movement controller")
		return
	controller.set_process(false)
	await process_frame
	(spider.get_node("SpiderRig/AnimationPlayer") as AnimationPlayer).seek(0.0, true)
	controller.set("step_distance", 0.2)
	controller.set("step_lead", 0.1)
	var targets := spider.get_node("SpiderRig/FootTargets")
	if not _check_landings(controller, targets) or not _check_stationary(controller, targets):
		return
	if not _check_steps(controller, targets, spider):
		return
	spider.free()
	if not _check_turning():
		return
	if not _check_emergency_release():
		return
	if not _check_preview() or not _check_idle_pose_steps():
		return
	print("SPIDER FREE STEP PASS: planted feet and alternating diagonal steps")
	quit(0)


func _check_landings(controller: Node3D, targets: Node) -> bool:
	if not controller.has_method("can_land"):
		return _fail("Controller must validate non-crossing foot landings")
	var front_left := targets.get_node("FootFrontLeft") as Marker3D
	var front_right := targets.get_node("FootFrontRight") as Marker3D
	var back_left := targets.get_node("FootBackLeft") as Marker3D
	if controller.call("can_land", 0, front_right.global_position):
		return _fail("A left leg cannot land across the spider's body")
	if controller.call("can_land", 6, front_left.global_position):
		return _fail("A back leg cannot cross the other left legs to reach a front foot")
	if not controller.call("can_land", 6, back_left.global_position):
		return _fail("A back leg must be allowed to remain on its non-crossing target")
	return true


func _check_stationary(controller: Node3D, targets: Node) -> bool:
	var initial := _positions(targets)
	for frame in range(60):
		controller.call("advance", 0.016)
	if not _same_positions(targets, initial):
		return _fail("A stationary spider must keep all feet planted")
	for foot_index in range(FOOT_NAMES.size()):
		if controller.call("is_dangling", foot_index):
			return _fail("A stationary spider must not release a foot")
	return true


func _check_steps(controller: Node3D, targets: Node, spider: Node3D) -> bool:
	var initial := _positions(targets)
	spider.position.z += 0.14
	controller.call("advance", 0.016)
	var moved_during_short_travel := not _same_positions(targets, initial)
	controller.call("advance", 0.016)
	if moved_during_short_travel or not _same_positions(targets, initial):
		return _fail("Short movement must not step during travel or after stopping")
	spider.position.z += 0.14
	controller.call("advance", 0.05)
	if not _moved_group(targets, initial, GROUP_A):
		return _fail("First diagonal group did not start a step")
	if not _still_group(targets, initial, GROUP_B):
		return _fail("Opposite diagonal group moved at the same time")
	controller.call("advance", 0.5)
	controller.call("advance", 0.05)
	if not _moved_group(targets, initial, GROUP_B):
		return _fail("Second diagonal group did not follow the first")
	controller.call("advance", 0.5)
	for foot_index in range(8):
		var planted_foot := targets.get_node(FOOT_NAMES[foot_index]) as Marker3D
		if not controller.call("can_land", foot_index, planted_foot.global_position):
			return _fail("Stepping produced a crossing or overlapping leg target")
	return true


func _check_preview() -> bool:
	var path := "res://src/features/spiders/spider_gait_preview.tscn"
	if not ResourceLoader.exists(path):
		return _fail("Free-step preview scene is missing")
	var preview := (load(path) as PackedScene).instantiate()
	root.add_child(preview)
	var preview_spider := preview.get_node_or_null("Spider") as BaseSpider3D
	var preview_camera := preview.get_node_or_null("Camera3D") as Camera3D
	if preview_spider == null or preview_camera == null or not preview_camera.current:
		return _fail("Preview must contain the real spider and an active camera")
	var start := preview_spider.global_position
	var preview_targets := preview_spider.get_node("SpiderRig/FootTargets")
	var planted := _positions(preview_targets)
	var preview_controller := preview_spider.get_node("SpiderRig/LegController")
	preview_controller.set_process(false)
	preview.call("move_spider", Vector3.RIGHT, 0.25)
	if preview_spider.global_position.x <= start.x:
		return _fail("Preview must move the spider freely without a web")
	preview_controller.call("advance", 0.11)
	if _same_positions(preview_targets, planted):
		return _fail("Preview movement must drive the spider's feet")
	preview.free()
	return true


func _check_idle_pose_steps() -> bool:
	var spider := SPIDER_SCENE.instantiate()
	root.add_child(spider)
	var rig := spider.get_node("SpiderRig") as Node3D
	var controller := rig.get_node("LegController") as Node3D
	var player := rig.get_node("AnimationPlayer") as AnimationPlayer
	var imported := rig.get_node("ImportedRig") as Node3D
	var targets := rig.get_node("FootTargets")
	controller.set_process(false)
	player.seek(0.0, true)
	controller.call("advance", 0.016)
	var planted := _positions(targets)
	var root_position := rig.global_position
	player.seek(1.0, true)
	controller.call("advance", 0.05)
	if absf(imported.rotation.y) < 0.05:
		spider.free()
		return _fail("Idle body pose must rotate enough to stretch its legs")
	if not rig.global_position.is_equal_approx(root_position):
		spider.free()
		return _fail("Idle pose must not move the gameplay rig")
	if not _moved_group(targets, planted, GROUP_A):
		spider.free()
		return _fail("Body rotation must trigger a planted foot step")
	if not _still_group(targets, planted, GROUP_B):
		spider.free()
		return _fail("Idle pose must retain alternating leg groups")
	spider.free()
	return true


func _check_turning() -> bool:
	var spider := SPIDER_SCENE.instantiate()
	root.add_child(spider)
	var rig := spider.get_node("SpiderRig") as Node3D
	var controller := rig.get_node("LegController") as Node3D
	controller.set_process(false)
	controller.set("step_distance", 0.2)
	if not controller.has_method("is_dangling"):
		spider.free()
		return _fail("Controller must release a leg when no non-crossing landing exists")
	for direction in [Vector3.RIGHT, Vector3.FORWARD, Vector3.LEFT, Vector3.BACK]:
		rig.rotation.y = atan2(direction.x, direction.z)
		for frame in range(12):
			spider.position += direction * 0.035
			controller.call("advance", 0.016)
		for frame in range(30):
			controller.call("advance", 0.016)
		var invalid_foot := _first_invalid_landing(controller, rig.get_node("FootTargets"))
		if not invalid_foot.is_empty():
			spider.free()
			return _fail(
				"A turn or reverse move left crossing foot paths: "
				+ invalid_foot + " after " + str(direction)
			)
	spider.free()
	return true


func _check_emergency_release() -> bool:
	var spider := SPIDER_SCENE.instantiate()
	root.add_child(spider)
	var rig := spider.get_node("SpiderRig") as Node3D
	var controller := rig.get_node("LegController") as Node3D
	controller.set_process(false)
	var planted_height := (rig.get_node("FootTargets/FootFrontRight") as Marker3D).global_position.y
	rig.rotation.y = PI
	controller.call("advance", 0.016)
	if not controller.call("is_dangling", 1):
		spider.free()
		return _fail("A stranded leg must release after an impossible instant turn")
	var loose_foot := rig.get_node("FootTargets/FootFrontRight") as Marker3D
	if loose_foot.global_position.y < planted_height:
		spider.free()
		return _fail("A released foot must lift above its planted height")
	var before := loose_foot.global_position
	spider.position.x += 0.1
	controller.call("advance", 0.016)
	if loose_foot.global_position.distance_to(before) < 0.05:
		spider.free()
		return _fail("A released foot must follow its moving body")
	spider.free()
	return true


func _first_invalid_landing(controller: Node3D, targets: Node) -> String:
	for foot_index in range(FOOT_NAMES.size()):
		if controller.call("is_dangling", foot_index):
			continue
		var foot := targets.get_node(FOOT_NAMES[foot_index]) as Marker3D
		if not controller.call("can_land", foot_index, foot.global_position):
			return FOOT_NAMES[foot_index]
	return ""


func _positions(targets: Node) -> Dictionary:
	var positions := {}
	for target in targets.get_children():
		positions[target.name] = target.global_position
	return positions


func _same_positions(targets: Node, positions: Dictionary) -> bool:
	for target in targets.get_children():
		if target.global_position.distance_to(positions[target.name]) > 0.001:
			return false
	return true


func _moved_group(targets: Node, positions: Dictionary, names: Array) -> bool:
	for target_name in names:
		var target := targets.get_node(target_name) as Node3D
		if target.global_position.distance_to(positions[target_name]) < 0.01:
			return false
	return true


func _still_group(targets: Node, positions: Dictionary, names: Array) -> bool:
	for target_name in names:
		var target := targets.get_node(target_name) as Node3D
		if target.global_position.distance_to(positions[target_name]) > 0.001:
			return false
	return true


func _fail(message: String) -> bool:
	push_error("SPIDER FREE STEP FAIL: " + message)
	quit(1)
	return false
