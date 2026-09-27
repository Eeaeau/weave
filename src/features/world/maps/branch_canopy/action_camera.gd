class_name ActionCamera3D
extends Camera3D
## Follows match action through a pose waypoint attached to the gameplay plane.

const WIND_FOCUS_SMOOTHING: float = 3.0

@export var waypoint_path: NodePath
@export_range(0.1, 20.0, 0.1) var pan_smoothing: float = 5.0
@export var sway_distance: float = 0.45
@export var sway_speed: float = 0.65
@export_range(1.0, 40.0, 0.1) var arena_distance: float = 12.081
@export_range(1.0, 40.0, 0.1) var spider_distance: float = 11.0
@export_range(1.0, 40.0, 0.1) var wind_distance: float = 12.081
@export_range(1.0, 40.0, 0.1) var projectile_distance: float = 9.5

var _authored_transform: Transform3D
var _elapsed: float = 0.0
var _waypoint: Node3D
var _gameplay_plane: Node3D
var _wind_event: WindEvent3D
var _match_manager: MatchManager
var _wind_focus: Dictionary = {}


func _ready() -> void:
	_authored_transform = transform
	if not waypoint_path.is_empty():
		_waypoint = get_node_or_null(waypoint_path) as Node3D
	if _waypoint != null:
		_gameplay_plane = _waypoint.get_parent_node_3d()
		_wind_event = _gameplay_plane.get_parent_node_3d() as WindEvent3D
	_match_manager = get_node_or_null("../../MatchManager") as MatchManager


func _process(delta: float) -> void:
	_elapsed += delta
	if _waypoint == null:
		var sway := sin(_elapsed * sway_speed) * sway_distance
		transform = _authored_transform.translated_local(Vector3(sway, 0.0, 0.0))
		return

	var focus_request := _resolve_focus_request()
	var focus_position: Vector3 = focus_request["position"]
	if focus_request["kind"] == "wind":
		if _wind_focus.is_empty():
			_wind_focus["position"] = focus_position
		else:
			var focus_weight := 1.0 - exp(-WIND_FOCUS_SMOOTHING * maxf(delta, 0.0))
			var previous_focus: Vector3 = _wind_focus["position"]
			_wind_focus["position"] = previous_focus.lerp(focus_position, focus_weight)
		focus_position = _wind_focus["position"]
	else:
		_wind_focus.clear()
	var target_transform := _build_waypoint_transform(
		_waypoint,
		focus_position,
		focus_request["distance"],
	)
	target_transform.origin += target_transform.basis.x * sin(_elapsed * sway_speed) * sway_distance
	var weight := 1.0 - exp(-pan_smoothing * maxf(delta, 0.0))
	global_transform = Transform3D(
		global_basis.slerp(target_transform.basis, weight),
		global_position.lerp(target_transform.origin, weight),
	)


func _resolve_focus_request() -> Dictionary:
	for node in get_tree().get_nodes_in_group("camera_focus_projectiles"):
		if node is Node3D and is_instance_valid(node) and not node.is_queued_for_deletion():
			return {
				"position": node.global_position,
				"distance": projectile_distance,
				"kind": "projectile",
			}

	if _wind_event != null and _wind_event.is_active:
		return {
			"position": _wind_event.get_camera_focus_point(),
			"distance": wind_distance,
			"kind": "wind",
		}

	if (_match_manager != null and _match_manager.active_team_idx >= 0
			and _match_manager.active_team_idx < _match_manager.teams.size()):
		var active_team := _match_manager.teams[_match_manager.active_team_idx]
		if active_team != null:
			var spider := active_team.get_active_spider()
			if spider != null and is_instance_valid(spider):
				return {
					"position": spider.global_position,
					"distance": spider_distance,
					"kind": "spider",
				}

	var plane := _get_gameplay_plane()
	var fallback_position := plane.global_position if plane != null else global_position
	return {
		"position": fallback_position,
		"distance": arena_distance,
		"kind": "arena",
	}


func _build_waypoint_transform(
		waypoint: Node3D, focus_position: Vector3, target_distance: float) -> Transform3D:
	var plane := waypoint.get_parent_node_3d()
	if plane == null:
		return waypoint.global_transform
	var plane_basis := plane.global_basis.orthonormalized()
	var focus_offset_from_plane := focus_position - plane.global_position
	var waypoint_offset_from_plane := waypoint.global_position - plane.global_position
	var waypoint_distance := (waypoint.global_position - plane.global_position).dot(plane_basis.y)
	var focus_offset := plane_basis.x * (
		focus_offset_from_plane.dot(plane_basis.x)
		- waypoint_offset_from_plane.dot(plane_basis.x)
	)
	focus_offset += plane_basis.z * (
		focus_offset_from_plane.dot(plane_basis.z)
		- waypoint_offset_from_plane.dot(plane_basis.z)
	)
	var origin := waypoint.global_position + focus_offset
	origin += plane_basis.y * (target_distance - waypoint_distance)
	return Transform3D(waypoint.global_basis.orthonormalized(), origin)


func _get_gameplay_plane() -> Node3D:
	return _gameplay_plane
