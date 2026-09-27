class_name SpiderLegController3D
extends Node3D

enum TargetingMode {
	WEB,
	FREE_STEP_DEBUG,
}

## Keeps the rig's IK feet planted, then moves alternating groups to free-step targets.

const FOOT_NAMES := [
	"FootFrontLeft",
	"FootFrontRight",
	"FootMidFrontLeft",
	"FootMidFrontRight",
	"FootMidBackLeft",
	"FootMidBackRight",
	"FootBackLeft",
	"FootBackRight",
]
const STEP_GROUPS := [[0, 3, 4, 7], [1, 2, 5, 6]]

@export var targeting_mode: TargetingMode = TargetingMode.WEB:
	set(value):
		targeting_mode = value
		if is_inside_tree():
			_refresh_web_binding()
@export var support_web: Web3D:
	set(value):
		if support_web == value:
			return
		_disconnect_web()
		support_web = value
		if is_inside_tree():
			_refresh_web_binding()
@export_range(0.05, 2.0, 0.01) var step_distance := 0.35
@export_range(0.02, 1.0, 0.01) var idle_pose_step_distance := 0.07
@export_range(0.05, 1.0, 0.01) var step_duration := 0.22
@export_range(0.0, 1.0, 0.01) var step_height := 0.2
@export_range(0.0, 1.0, 0.01) var step_lead := 0.2
@export_range(0.01, 0.5, 0.01) var support_tolerance := 0.12
@export_range(0.0, 1.0, 0.01) var reach_extension := 0.35

var _rig: Node3D
var _visual_pose: VisualPose
var _cycle: StepCycle
var _feet: Array[FootState] = []
var _steps: Array[Dictionary] = []


func _ready() -> void:
	_rig = get_parent() as Node3D
	_visual_pose = VisualPose.new(_rig.get_node("ImportedRig") as Node3D)
	_cycle = StepCycle.new()
	var targets := _rig.get_node("FootTargets")
	for foot_name in FOOT_NAMES:
		_initialize_foot(targets, foot_name)
	_cycle.last_rig_position = _rig.global_position
	_refresh_web_binding()


func _process(delta: float) -> void:
	advance(delta)


func _initialize_foot(targets: Node, foot_name: String) -> void:
	var foot := targets.get_node(foot_name) as Marker3D
	var planted_position := foot.global_position
	var foot_state := FootState.new(
		foot,
		_rig.to_local(planted_position),
		planted_position.y
	)
	_visual_pose.anchors.append(foot_state.rest_offset)
	foot.top_level = true
	foot.global_position = planted_position
	_feet.append(foot_state)


func _refresh_web_binding() -> void:
	if targeting_mode != TargetingMode.WEB:
		_disconnect_web()
		_cycle.support_segments.clear()
		return
	if support_web == null or not is_instance_valid(support_web):
		support_web = _find_nearest_web()
	if support_web == null:
		_cycle.support_segments.clear()
		return
	if not support_web.geometry_changed.is_connected(_on_web_geometry_changed):
		support_web.geometry_changed.connect(_on_web_geometry_changed)
	_refresh_support_segments()


func _find_nearest_web() -> Web3D:
	var nearest: Web3D
	var nearest_distance := INF
	for node in get_tree().get_nodes_in_group("web_support"):
		var candidate := node as Web3D
		if candidate == null:
			continue
		var distance := _planar(candidate.global_position).distance_to(
			_planar(_rig.global_position)
		)
		if distance < nearest_distance:
			nearest = candidate
			nearest_distance = distance
	return nearest


func _disconnect_web() -> void:
	if is_instance_valid(support_web):
		if support_web.geometry_changed.is_connected(_on_web_geometry_changed):
			support_web.geometry_changed.disconnect(_on_web_geometry_changed)
	if _cycle != null:
		_cycle.support_segments.clear()


func _refresh_support_segments() -> void:
	_cycle.support_segments.clear()
	if not is_instance_valid(support_web):
		return
	for segment in support_web.get_support_segments():
		_cycle.support_segments.append(segment)


func _on_web_geometry_changed() -> void:
	_refresh_support_segments()
	if targeting_mode != TargetingMode.WEB or _feet.size() != FOOT_NAMES.size():
		return
	var active_steps: Array[Dictionary] = []
	var unsupported_feet: Array[int] = []
	for step in _steps:
		var foot_index: int = step["index"]
		if has_web_support(step["end"]):
			active_steps.append(step)
		else:
			_feet[foot_index].dangling = true
			_feet[foot_index].strand_id = ""
			_feet[foot_index].marker.global_position = _dangling_position(foot_index)
			unsupported_feet.append(foot_index)
	_steps = active_steps
	for foot_index in range(_feet.size()):
		if _is_stepping(foot_index):
			continue
		var support := _find_support(_feet[foot_index].marker.global_position)
		if support.is_empty():
			_feet[foot_index].dangling = true
			_feet[foot_index].strand_id = ""
			_feet[foot_index].marker.global_position = _dangling_position(foot_index)
			if not unsupported_feet.has(foot_index):
				unsupported_feet.append(foot_index)
		else:
			_feet[foot_index].dangling = false
			_feet[foot_index].strand_id = support["strand_id"]
	for foot_index in unsupported_feet:
		if not _cycle.urgent_replacements.has(foot_index):
			_cycle.urgent_replacements.append(foot_index)
	if _steps.is_empty():
		var priority_feet := _cycle.urgent_replacements.duplicate()
		_cycle.urgent_replacements.clear()
		_start_urgent_replacements(priority_feet)


func advance(delta: float) -> void:
	if _feet.size() != FOOT_NAMES.size():
		return
	if targeting_mode == TargetingMode.WEB and not is_instance_valid(support_web):
		_refresh_web_binding()
	var travel := _rig.global_position - _cycle.last_rig_position
	travel.y = 0.0
	_cycle.rig_moved = not travel.is_zero_approx()
	if _cycle.rig_moved:
		_cycle.travel_direction = travel.normalized()
	_cycle.last_rig_position = _rig.global_position
	_update_dangling()
	_release_crossed_feet()
	if not _steps.is_empty():
		_animate_step(delta)
		return
	if not _cycle.urgent_replacements.is_empty():
		var priority_feet := _cycle.urgent_replacements.duplicate()
		_cycle.urgent_replacements.clear()
		_start_urgent_replacements(priority_feet)
		if not _steps.is_empty():
			_animate_step(delta)
			return
	if not _start_group(_cycle.next_group):
		_start_group(1 - _cycle.next_group)
	if not _steps.is_empty():
		_animate_step(delta)


func _start_group(group_index: int, only_dangling: bool = false) -> bool:
	for foot_index in STEP_GROUPS[group_index]:
		if only_dangling and not _feet[foot_index].dangling:
			continue
		var old_anchor := _rig.to_global(_visual_pose.anchors[foot_index])
		var walking_gap := old_anchor - _feet[foot_index].marker.global_position
		walking_gap.y = 0.0
		var pose_gap := _pose_rest_position(foot_index) - old_anchor
		pose_gap.y = 0.0
		var exceeds_threshold := (
			walking_gap.length() > step_distance
			or pose_gap.length() > idle_pose_step_distance
		)
		if (targeting_mode == TargetingMode.WEB and not _feet[foot_index].dangling
				and not exceeds_threshold):
			continue
		var landing := _choose_destination(foot_index)
		if landing.is_empty():
			if (targeting_mode == TargetingMode.WEB and not _feet[foot_index].dangling
					and has_web_support(_feet[foot_index].marker.global_position)):
				continue
			_feet[foot_index].dangling = true
			_feet[foot_index].strand_id = ""
			_feet[foot_index].marker.global_position = _dangling_position(foot_index)
			continue
		var destination: Vector3 = landing["point"]
		if (walking_gap.length() <= step_distance
				and pose_gap.length() <= idle_pose_step_distance
				and not _feet[foot_index].dangling):
			_feet[foot_index].strand_id = landing.get("strand_id", "")
			continue
		_steps.append({
			"index": foot_index,
			"start": _feet[foot_index].marker.global_position,
			"end": destination,
			"pose_anchor": _pose_rest_local(foot_index),
			"strand_id": landing.get("strand_id", ""),
		})
	if _steps.is_empty():
		return false
	_cycle.elapsed = 0.0
	_cycle.next_group = 1 - group_index
	return true


func _start_urgent_replacements(priority_feet: Array[int]) -> void:
	if not _steps.is_empty():
		return
	var group_order: Array[int] = []
	for foot_index in priority_feet:
		var group_index := 0 if STEP_GROUPS[0].has(foot_index) else 1
		if not group_order.has(group_index):
			group_order.append(group_index)
	for group_index in [_cycle.next_group, 1 - _cycle.next_group]:
		if not group_order.has(group_index):
			group_order.append(group_index)
	for group_index in group_order:
		if _start_group(group_index, true):
			return


func is_dangling(foot_index: int) -> bool:
	return foot_index >= 0 and foot_index < _feet.size() and _feet[foot_index].dangling


func _update_dangling() -> void:
	for foot_index in range(_feet.size()):
		if _feet[foot_index].dangling and not _is_stepping(foot_index):
			_feet[foot_index].marker.global_position = _dangling_position(foot_index)


func _release_crossed_feet() -> void:
	for foot_index in range(_feet.size()):
		if _feet[foot_index].dangling or _is_stepping(foot_index):
			continue
		var support := _find_support(_feet[foot_index].marker.global_position)
		if (not can_land(foot_index, _feet[foot_index].marker.global_position)
				or (targeting_mode == TargetingMode.WEB and support.is_empty())):
			_feet[foot_index].dangling = true
			_feet[foot_index].strand_id = ""
			_feet[foot_index].marker.global_position = _dangling_position(foot_index)
		elif targeting_mode == TargetingMode.WEB:
			_feet[foot_index].strand_id = support["strand_id"]


func _dangling_position(foot_index: int) -> Vector3:
	var foot_position := _lift_position(foot_index)
	foot_position.y = maxf(_feet[foot_index].ground_height + step_height * 0.5, foot_position.y)
	return foot_position


func _is_stepping(foot_index: int) -> bool:
	for active_step in _steps:
		if active_step["index"] == foot_index:
			return true
	return false


func _choose_destination(foot_index: int) -> Dictionary:
	if targeting_mode == TargetingMode.WEB:
		return _choose_web_destination(foot_index)
	var desired := _rest_destination(foot_index)
	if can_land(foot_index, desired):
		return { "point": desired }
	var without_lead := desired - _cycle.travel_direction * step_lead
	if can_land(foot_index, without_lead):
		return { "point": without_lead }
	var side := -1.0 if _feet[foot_index].rest_offset.x < 0.0 else 1.0
	for sideways in [0.12, 0.24, 0.36]:
		var candidate: Vector3 = desired + _rig.global_basis.x.normalized() * side * float(sideways)
		if can_land(foot_index, candidate):
			return { "point": candidate }
	return {}


func has_web_support(world_point: Vector3) -> bool:
	return not _find_support(world_point).is_empty()


func _find_support(world_point: Vector3) -> Dictionary:
	if targeting_mode != TargetingMode.WEB or not is_instance_valid(support_web):
		return {}
	var closest_support: Dictionary = {}
	var closest_distance := support_tolerance
	for segment in _cycle.support_segments:
		var point := _closest_point_on_segment(
			world_point,
			segment["start"],
			segment["end"]
		)
		var distance := world_point.distance_to(point)
		if distance <= closest_distance:
			closest_distance = distance
			closest_support = {
				"point": point,
				"strand_id": segment["strand_id"],
			}
	return closest_support


func _choose_web_destination(foot_index: int) -> Dictionary:
	if not is_instance_valid(support_web) or _cycle.support_segments.is_empty():
		return {}
	var desired := _rest_destination(foot_index)
	var preferred_strand: String = _feet[foot_index].strand_id
	var maximum_reach := _max_leg_reach(foot_index)
	var best_score := INF
	var best_destination: Dictionary = {}
	for segment in _cycle.support_segments:
		var candidate := _best_web_target_on_segment(
			foot_index,
			desired,
			preferred_strand,
			maximum_reach,
			segment
		)
		if not candidate.is_empty() and candidate["score"] < best_score:
			best_score = candidate["score"]
			best_destination = candidate
	best_destination.erase("score")
	return best_destination


func _best_web_target_on_segment(
	foot_index: int,
	desired: Vector3,
	preferred_strand: String,
	maximum_reach: float,
	segment: Dictionary
) -> Dictionary:
	var start: Vector3 = segment["start"]
	var end: Vector3 = segment["end"]
	var nearest_t := _closest_planar_parameter(desired, start, end)
	var best_score := INF
	var best_point := Vector3.ZERO
	var strand_id: String = segment["strand_id"]
	for t in [nearest_t, 0.0, 0.25, 0.5, 0.75, 1.0]:
		var candidate := start.lerp(end, t)
		if _lift_position(foot_index).distance_to(candidate) > maximum_reach:
			continue
		if not can_land(foot_index, candidate):
			continue
		if not _has_shared_strand_clearance(foot_index, candidate, strand_id):
			continue
		var score := _planar(candidate).distance_to(_planar(desired))
		score += absf(candidate.y - desired.y) * 0.5
		var local_candidate := _rig.to_local(candidate)
		if local_candidate.x * _feet[foot_index].rest_offset.x <= 0.0:
			score += 0.35
		if strand_id == preferred_strand:
			score = maxf(0.0, score - 0.2)
		if score < best_score:
			best_score = score
			best_point = candidate
	if is_inf(best_score):
		return {}
	return { "point": best_point, "strand_id": strand_id, "score": best_score }


func _closest_planar_parameter(point: Vector3, start: Vector3, end: Vector3) -> float:
	var segment := _planar(end) - _planar(start)
	if segment.length_squared() <= 0.000001:
		return 0.0
	var offset := _planar(point) - _planar(start)
	return clampf(offset.dot(segment) / segment.length_squared(), 0.0, 1.0)


func _closest_point_on_segment(point: Vector3, start: Vector3, end: Vector3) -> Vector3:
	var segment := end - start
	if segment.length_squared() <= 0.000001:
		return start
	var t := clampf((point - start).dot(segment) / segment.length_squared(), 0.0, 1.0)
	return start + segment * t


func _max_leg_reach(foot_index: int) -> float:
	var rest_position := _pose_rest_position(foot_index)
	return _lift_position(foot_index).distance_to(rest_position) + reach_extension


func _has_shared_strand_clearance(
	foot_index: int,
	candidate: Vector3,
	strand_id: String
) -> bool:
	for other_index in range(_feet.size()):
		if other_index == foot_index:
			continue
		var other_position := _feet[other_index].marker.global_position
		var other_strand: String = _feet[other_index].strand_id
		for active_step in _steps:
			if active_step["index"] == other_index:
				other_position = active_step["end"]
				other_strand = active_step.get("strand_id", "")
				break
		if (other_strand == strand_id
				and _planar(candidate).distance_to(_planar(other_position)) < 0.12):
			return false
	return true


func can_land(foot_index: int, candidate: Vector3) -> bool:
	if foot_index < 0 or foot_index >= _feet.size():
		return false
	var local_candidate := _rig.to_local(candidate)
	if (targeting_mode != TargetingMode.WEB
			and local_candidate.x * _feet[foot_index].rest_offset.x <= 0.0):
		return false
	var from_point := _planar(_lift_position(foot_index))
	var to_point := _planar(candidate)
	for other_index in range(_feet.size()):
		if other_index == foot_index:
			continue
		if _feet[other_index].dangling and not _is_stepping(other_index):
			continue
		var other_foot := _feet[other_index].marker.global_position
		for active_step in _steps:
			if active_step["index"] == other_index:
				other_foot = active_step["end"]
				break
		if to_point.distance_to(_planar(other_foot)) < 0.06:
			return false
		if _paths_cross(
			from_point,
			to_point,
			_planar(_lift_position(other_index)),
			_planar(other_foot)
		):
			return false
	return true


func _lift_position(foot_index: int) -> Vector3:
	var lift_name: String = FOOT_NAMES[foot_index].replace("Foot", "Lift")
	return (_rig.get_node("LiftTargets/" + lift_name) as Marker3D).global_position


func _planar(world_point: Vector3) -> Vector2:
	return Vector2(world_point.x, world_point.z)


func _paths_cross(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> bool:
	var ab := b - a
	var cd := d - c
	var denominator := ab.cross(cd)
	if absf(denominator) < 0.00001:
		return false
	var t := (c - a).cross(cd) / denominator
	var u := (c - a).cross(ab) / denominator
	return t > 0.001 and t < 0.999 and u > 0.001 and u < 0.999


func _rest_destination(foot_index: int) -> Vector3:
	var destination := _pose_rest_position(foot_index)
	if _cycle.rig_moved:
		destination += _cycle.travel_direction * step_lead
	destination.y = _feet[foot_index].ground_height
	return destination


func _pose_rest_position(foot_index: int) -> Vector3:
	return _rig.to_global(_pose_rest_local(foot_index))


func _pose_rest_local(foot_index: int) -> Vector3:
	var pose_delta := _visual_pose.node.transform * _visual_pose.rest_transform.affine_inverse()
	return pose_delta * _feet[foot_index].rest_offset


func _animate_step(delta: float) -> void:
	_cycle.elapsed += delta
	var progress := minf(_cycle.elapsed / step_duration, 1.0)
	var eased := progress * progress * (3.0 - 2.0 * progress)
	for active_step in _steps:
		var start: Vector3 = active_step["start"]
		var destination: Vector3 = active_step["end"]
		var foot_position := start.lerp(destination, eased)
		foot_position.y += 4.0 * step_height * progress * (1.0 - progress)
		var foot_index: int = active_step["index"]
		_feet[foot_index].marker.global_position = foot_position
	if progress >= 1.0:
		for active_step in _steps:
			var foot_index: int = active_step["index"]
			var destination: Vector3 = active_step["end"]
			if (targeting_mode == TargetingMode.WEB
					and not has_web_support(destination)):
				_feet[foot_index].dangling = true
				_feet[foot_index].strand_id = ""
				_feet[foot_index].marker.global_position = _dangling_position(foot_index)
			else:
				_feet[foot_index].dangling = false
				_feet[foot_index].strand_id = active_step.get("strand_id", "")
				_visual_pose.anchors[foot_index] = active_step["pose_anchor"]
		_steps.clear()


class FootState:
	var marker: Marker3D
	var rest_offset: Vector3
	var ground_height: float
	var dangling := false
	var strand_id := ""

	func _init(foot_marker: Marker3D, offset: Vector3, height: float) -> void:
		marker = foot_marker
		rest_offset = offset
		ground_height = height


class VisualPose:
	var node: Node3D
	var rest_transform: Transform3D
	var anchors: Array[Vector3] = []

	func _init(visual_node: Node3D) -> void:
		node = visual_node
		rest_transform = visual_node.transform


class StepCycle:
	var next_group := 0
	var elapsed := 0.0
	var rig_moved := false
	var last_rig_position := Vector3.ZERO
	var travel_direction := Vector3.ZERO
	var support_segments: Array[Dictionary] = []
	var urgent_replacements: Array[int] = []
