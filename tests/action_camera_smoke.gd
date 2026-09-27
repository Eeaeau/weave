extends SceneTree
## Exercises plane-relative camera focus, framing, and zoom.

const MATCH_SCENE: PackedScene = preload("res://src/game/web_match.tscn")
const CAMERA_SCRIPT: Script = preload(
	"res://src/features/world/maps/branch_canopy/action_camera.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if not (await _focus_sources_and_smoothing()
			and _rotated_waypoint_and_zoom()):
		quit(1)
		return
	await create_timer(0.5).timeout
	print("ACTION CAMERA PASS: focus, rotated waypoint, and normal-axis zoom")
	quit(0)


func _focus_sources_and_smoothing() -> bool:
	var match_scene: Node3D = MATCH_SCENE.instantiate()
	root.add_child(match_scene)
	await process_frame
	var camera: Camera3D = match_scene.get_node("BranchCanopy/ActionCamera")
	camera.set_process(false)
	var checks_ok := _check_wind_focus(match_scene)
	checks_ok = _check_spider_focus(match_scene) and checks_ok
	checks_ok = _check_projectile_focus_and_smoothing(match_scene) and checks_ok
	checks_ok = _check_arena_fallback(match_scene) and checks_ok
	_free_scene(match_scene)
	return checks_ok


func _check_wind_focus(match_scene: Node3D) -> bool:
	var camera: Camera3D = match_scene.get_node("BranchCanopy/ActionCamera")
	var event: WindEvent3D = match_scene.get_node("BranchCanopy/WindEvent")
	var request: Dictionary = camera.call("_resolve_focus_request")
	if request.get("kind") != "wind":
		return _fail("An active wind group must take camera focus")
	var focus_position: Vector3 = request.get("position")
	if not focus_position.is_equal_approx(event.get_camera_focus_point()):
		return _fail("Wind focus must follow the center of its active group")
	return true


func _check_spider_focus(match_scene: Node3D) -> bool:
	var camera: Camera3D = match_scene.get_node("BranchCanopy/ActionCamera")
	var manager: MatchManager = match_scene.get_node("MatchManager")
	var event: WindEvent3D = match_scene.get_node("BranchCanopy/WindEvent")
	event.is_active = false
	manager.waiting_for_wind = false
	var spider := manager.teams[manager.active_team_idx].get_active_spider()
	var request: Dictionary = camera.call("_resolve_focus_request")
	var focus_position: Vector3 = request.get("position")
	if request.get("kind") != "spider" or not focus_position.is_equal_approx(
			spider.global_position):
		return _fail("The active spider must be the normal gameplay focus")
	return true


func _check_projectile_focus_and_smoothing(match_scene: Node3D) -> bool:
	var camera: Camera3D = match_scene.get_node("BranchCanopy/ActionCamera")
	var projectile := PebbleProjectile3D.new()
	projectile.position = Vector3(5.0, 2.0, -3.0)
	match_scene.add_child(projectile)
	var request: Dictionary = camera.call("_resolve_focus_request")
	var focus_position: Vector3 = request.get("position")
	if request.get("kind") != "projectile" or not focus_position.is_equal_approx(
			projectile.global_position):
		return _fail("A moving projectile must take focus while it is in flight")
	var waypoint: Node3D = camera.get_node(camera.get("waypoint_path"))
	var target_transform: Transform3D = camera.call(
		"_build_waypoint_transform", waypoint, projectile.global_position,
		request.get("distance"))
	if not _target_keeps_requested_plane_distance(
			target_transform.origin, waypoint, request.get("distance")):
		return _fail("An airborne projectile must not change camera distance from the plane")
	var starting_distance := camera.global_position.distance_to(target_transform.origin)
	camera.global_position += Vector3(12.0, 4.0, -6.0)
	var before_smoothing := camera.global_position
	camera.call("_process", 0.1)
	if camera.global_position.distance_to(before_smoothing) <= 0.01:
		return _fail("The action camera must pan smoothly toward its focus")
	if camera.global_position.distance_to(target_transform.origin) >= starting_distance:
		return _fail("Camera smoothing must reduce the distance to its waypoint")
	projectile.free()
	return true


func _target_keeps_requested_plane_distance(
		target_position: Vector3, waypoint: Node3D, target_distance: float) -> bool:
	var plane := waypoint.get_parent_node_3d()
	var plane_normal := plane.global_basis.y.normalized()
	var camera_plane_distance := (target_position - plane.global_position).dot(plane_normal)
	return is_equal_approx(camera_plane_distance, target_distance)


func _check_arena_fallback(match_scene: Node3D) -> bool:
	var camera: Camera3D = match_scene.get_node("BranchCanopy/ActionCamera")
	var manager: MatchManager = match_scene.get_node("MatchManager")
	var waypoint: Node3D = camera.get_node(camera.get("waypoint_path"))
	var plane := waypoint.get_parent_node_3d()
	manager.teams[manager.active_team_idx].active_spider_idx = (
		manager.teams[manager.active_team_idx].spiders.size())
	var request: Dictionary = camera.call("_resolve_focus_request")
	var focus_position: Vector3 = request.get("position")
	if request.get("kind") != "arena" or not focus_position.is_equal_approx(
			plane.global_position):
		return _fail("The arena center must be the final focus fallback")
	return true


func _rotated_waypoint_and_zoom() -> bool:
	var rig := _create_rotated_camera_rig()
	var distance_ok := _rotated_focus_is_centered(rig)
	var orientation_ok := _rotated_camera_orientation_matches(rig)
	var zoom_ok := _zoom_moves_on_normal_only(rig)
	_clear_camera_rig(rig)
	if not distance_ok:
		return _fail("A rotated waypoint must keep and center its requested focus distance")
	if not orientation_ok:
		return _fail("A rotated waypoint must carry the camera's complete orientation")
	if not zoom_ok:
		return _fail("Zoom must move only along the plane normal and leave FOV unchanged")
	return true


func _create_rotated_camera_rig() -> Dictionary:
	var plane := Node3D.new()
	plane.position = Vector3(3.0, -2.0, 1.0)
	plane.rotation = Vector3(0.55, -0.3, 0.8)
	root.add_child(plane)
	var waypoint := Marker3D.new()
	waypoint.position = Vector3(0.4, 12.0, -0.7)
	waypoint.rotation = Vector3(-PI / 2.0, 0.0, 0.0)
	plane.add_child(waypoint)
	var camera := Camera3D.new()
	camera.set_script(CAMERA_SCRIPT)
	camera.set_process(false)
	root.add_child(camera)
	return {
		"plane": plane,
		"waypoint": waypoint,
		"camera": camera,
		"focus": plane.to_global(Vector3(-2.5, 0.6, 1.25)),
	}


func _rotated_focus_is_centered(rig: Dictionary) -> bool:
	var plane: Node3D = rig["plane"]
	var camera: Camera3D = rig["camera"]
	var waypoint: Node3D = rig["waypoint"]
	var focus: Vector3 = rig["focus"]
	var target: Transform3D = camera.call("_build_waypoint_transform", waypoint, focus, 7.0)
	var normal := plane.global_basis.y.normalized()
	var camera_plane_distance := (target.origin - plane.global_position).dot(normal)
	var camera_target_offset := target.origin - focus
	var target_tangent_offset := camera_target_offset - normal * camera_target_offset.dot(normal)
	return is_equal_approx(camera_plane_distance, 7.0) and (
			target_tangent_offset.length() < 0.001)


func _rotated_camera_orientation_matches(rig: Dictionary) -> bool:
	var camera: Camera3D = rig["camera"]
	var waypoint: Node3D = rig["waypoint"]
	var focus: Vector3 = rig["focus"]
	var target: Transform3D = camera.call("_build_waypoint_transform", waypoint, focus, 7.0)
	return target.basis.is_equal_approx(waypoint.global_basis.orthonormalized())


func _zoom_moves_on_normal_only(rig: Dictionary) -> bool:
	var plane: Node3D = rig["plane"]
	var camera: Camera3D = rig["camera"]
	var waypoint: Node3D = rig["waypoint"]
	var focus: Vector3 = rig["focus"]
	var initial_fov: float = camera.fov
	var near_transform: Transform3D = camera.call(
		"_build_waypoint_transform", waypoint, focus, 7.0)
	var far_transform: Transform3D = camera.call(
		"_build_waypoint_transform", waypoint, focus, 12.0)
	var zoom_delta := far_transform.origin - near_transform.origin
	var normal := plane.global_basis.y.normalized()
	return is_equal_approx(zoom_delta.dot(normal), 5.0) and (
			zoom_delta - normal * 5.0).length() <= 0.001 and is_equal_approx(
			camera.fov, initial_fov)


func _clear_camera_rig(rig: Dictionary) -> void:
	(rig["camera"] as Camera3D).free()
	(rig["plane"] as Node3D).free()


func _free_scene(node: Node) -> void:
	_stop_audio(node)
	node.free()


func _stop_audio(node: Node) -> void:
	if node is AudioStreamPlayer:
		node.stop()
	for child in node.get_children():
		_stop_audio(child)


func _fail(message: String) -> bool:
	push_error("ACTION CAMERA FAIL: " + message)
	return false
