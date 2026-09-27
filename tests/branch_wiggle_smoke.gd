extends SceneTree
## Verify wind moves branch artwork while blockers stay fixed and the artwork settles.

const BRANCH_SCENE := preload(
	"res://src/features/world/maps/branch_canopy/branch_canopy.tscn"
)

var _canopy: BranchCanopy3D
var _event: WindEvent3D
var _left_foreground: Node3D
var _right_foreground: Node3D
var _left_blocker: StaticBody3D
var _right_blocker: StaticBody3D
var _left_artwork_rest: Transform3D
var _right_artwork_rest: Transform3D
var _left_blocker_rest: Transform3D
var _right_blocker_rest: Transform3D


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if not await _prepare_canopy():
		_fail("Both branches need visible foreground sprites and static blockers")
		return
	_event.start_round(1)
	await create_timer(1.0).timeout
	if not _check_active_wiggle():
		return
	if not await _check_smooth_return():
		return
	_cleanup()
	await create_timer(0.5).timeout
	print("BRANCH WIGGLE PASS: subtle wind motion, fixed blockers, and smooth return")
	quit(0)


func _prepare_canopy() -> bool:
	_canopy = BRANCH_SCENE.instantiate() as BranchCanopy3D
	var ambience := _canopy.get_node("CanopyAmbience")
	_canopy.remove_child(ambience)
	ambience.free()
	_event = _canopy.get_node("WindEvent") as WindEvent3D
	var gust := _event.get_node("Gust") as WindGust
	gust.level_db = -60.0
	root.add_child(_canopy)
	await process_frame
	var left_branch := _canopy.get_node("LeftBranch") as Node3D
	var right_branch := _canopy.get_node("RightBranch") as Node3D
	_left_foreground = left_branch.find_child("Foreground", true, false) as Node3D
	_right_foreground = right_branch.find_child("Foreground", true, false) as Node3D
	_left_blocker = _canopy.get_node("LeftBranchBlocker") as StaticBody3D
	_right_blocker = _canopy.get_node("RightBranchBlocker") as StaticBody3D
	if (_left_foreground == null or _right_foreground == null
			or _left_blocker == null or _right_blocker == null):
		return false
	_left_artwork_rest = _left_foreground.global_transform
	_right_artwork_rest = _right_foreground.global_transform
	_left_blocker_rest = _left_blocker.global_transform
	_right_blocker_rest = _right_blocker.global_transform
	return true


func _check_active_wiggle() -> bool:
	var left_wind_angle := _angle_between(_left_artwork_rest, _left_foreground.global_transform)
	var right_wind_angle := _angle_between(_right_artwork_rest, _right_foreground.global_transform)
	if left_wind_angle < 0.001 or right_wind_angle < 0.001:
		_fail("A wind event must visibly wiggle both branch layers")
		return false
	if left_wind_angle > deg_to_rad(2.0) or right_wind_angle > deg_to_rad(2.0):
		_fail("Branch wiggle must remain subtle")
		return false
	if not _blockers_are_resting():
		_fail("Wind must not move branch collision blockers")
		return false
	return true


func _check_smooth_return() -> bool:
	var left_pose_at_end := _left_foreground.global_transform
	var right_pose_at_end := _right_foreground.global_transform
	_event._finish_event()
	if (not _left_foreground.global_transform.is_equal_approx(left_pose_at_end)
			or not _right_foreground.global_transform.is_equal_approx(right_pose_at_end)):
		_fail("Finishing wind must not snap branch artwork back immediately")
		return false
	await create_timer(0.02).timeout
	var left_return_step := _angle_between(left_pose_at_end, _left_foreground.global_transform)
	var right_return_step := _angle_between(right_pose_at_end, _right_foreground.global_transform)
	if left_return_step > deg_to_rad(0.3) or right_return_step > deg_to_rad(0.3):
		_fail("Branch artwork must begin its return smoothly")
		return false
	await create_timer(0.6).timeout
	if (not _left_foreground.global_transform.is_equal_approx(_left_artwork_rest)
			or not _right_foreground.global_transform.is_equal_approx(_right_artwork_rest)):
		_fail("After wind ends, branch artwork must return to its authored pose")
		return false
	if not _blockers_are_resting():
		_fail("Wind must leave branch collision blockers unchanged")
		return false
	return true


func _angle_between(first: Transform3D, second: Transform3D) -> float:
	return first.basis.x.angle_to(second.basis.x)


func _blockers_are_resting() -> bool:
	return (_left_blocker.global_transform.is_equal_approx(_left_blocker_rest)
			and _right_blocker.global_transform.is_equal_approx(_right_blocker_rest))


func _fail(message: String) -> void:
	_cleanup()
	push_error("BRANCH WIGGLE FAIL: " + message)
	call_deferred("_quit_after_cleanup")


func _quit_after_cleanup() -> void:
	await create_timer(0.5).timeout
	quit(1)


func _cleanup() -> void:
	if not is_instance_valid(_canopy):
		return
	_stop_audio(_canopy)
	_canopy.free()


func _stop_audio(node: Node) -> void:
	if node is AudioStreamPlayer:
		node.stop()
	for child in node.get_children():
		_stop_audio(child)
