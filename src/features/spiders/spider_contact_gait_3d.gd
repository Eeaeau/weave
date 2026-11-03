class_name SpiderContactGait3D
extends SpiderLegController3D

@export var lift_spacing := 0.08
@export var minimum_stance := 0.26
@export var minimum_stride := 0.24
@export var foot_swing_speed := 2.8
@export var body_footprint := Rect2(-1.91, -2.08, 3.32, 3.64)
@export var landing_adjustment := 0.32

var _clock := 0.0
var _next_lift := 0.0
var _landed: Array[float] = []
var history: Array[int] = []
var _last_side := -1
var _travel_speed := 0.0
var _query_foot := -1
var _forced_replacements: Dictionary = {}
var _query_direction := Vector3.ZERO
var _body_sprite: Sprite3D
var _needs_replant: Dictionary = {}
var _deformation: Node
var _support_bounds := AABB()


func _exit_tree() -> void:
	if is_instance_valid(_deformation):
		_deformation.unregister_gait(self)
	_disconnect_web()


func _ready() -> void:
	_body_sprite = get_parent().get_node("BoneAttachment3D/BodyOffset/Body")
	super._ready()
	_landed.resize(8)
	_landed.fill(-1.0)


func _refresh_web_binding() -> void:
	if is_instance_valid(_deformation):
		_deformation.unregister_gait(self)
	super._refresh_web_binding()
	_deformation = null
	if targeting_mode == TargetingMode.WEB and is_instance_valid(support_web):
		_deformation = support_web.get_deformation()
		if _deformation != null:
			_deformation.register_gait(self)


func get_deformation() -> Node:
	return _deformation if is_instance_valid(_deformation) else null


func _refresh_support_segments() -> void:
	super._refresh_support_segments()
	if _cycle.support_segments.is_empty():
		_support_bounds = AABB()
		return
	_support_bounds = AABB(_cycle.support_segments[0].start, Vector3.ZERO)
	for segment in _cycle.support_segments:
		_support_bounds = _support_bounds.expand(segment.start).expand(segment.end)


func _update_dangling(delta: float) -> void:
	for index in range(_feet.size()):
		var foot := _feet[index]
		if not foot.dangling or _is_stepping(index) or foot.carried:
			continue
		if not _choose_destination(index).is_empty():
			continue
		if _inside_body(foot.marker.global_position):
			foot.marker.global_position = foot.marker.global_position.move_toward(
				_dangling_position(index), foot_recovery_speed * maxf(delta, 0.0))


func _advance_gait(delta: float) -> void:
	if targeting_mode == TargetingMode.WEB and not is_instance_valid(support_web):
		_refresh_web_binding()
	_clock += maxf(0.0, delta)
	var travel := _rig.global_position - _cycle.last_rig_position
	travel -= _depth_normal() * travel.dot(_depth_normal())
	_travel_speed = travel.length() / maxf(delta, 0.001)
	_cycle.rig_moved = not travel.is_zero_approx()
	if _cycle.rig_moved:
		_cycle.travel_direction = travel.normalized()
	_cycle.last_rig_position = _rig.global_position
	_update_dangling(delta)
	_release_crossed_feet()
	_advance_swings(delta)
	if _clock < _next_lift:
		return
	var selected := -1
	var best := -INF
	var selected_landing: Dictionary = {}
	for index in range(8):
		var foot := _feet[index]
		if foot.carried or _is_stepping(index):
			continue
		var gap := _rig.to_global(foot.planted_anchor) - foot.marker.global_position
		gap -= _depth_normal() * gap.dot(_depth_normal())
		var pose_gap := _pose_rest_position(index) - _rig.to_global(_visual_pose.anchors[index])
		pose_gap -= _depth_normal() * pose_gap.dot(_depth_normal())
		var need := maxf(gap.length() / step_distance, pose_gap.length() / idle_pose_step_distance)
		var near_limit := _near_reach_limit(index) and _travel_speed > 0.1
		var urgent := near_limit or _needs_replant.has(index)
		if not foot.dangling and need < 1.0 and not urgent:
			continue
		if (not _forced_replacements.has(index)
				and not _needs_replant.has(index)
				and not _can_lift(index)):
			continue
		if not foot.dangling and not urgent and _clock - _landed[index] < minimum_stance:
			continue
		_query_foot = index if not foot.dangling and not urgent else -1
		_query_direction = _rest_destination(index) - foot.marker.global_position
		_query_direction -= _depth_normal() * _query_direction.dot(_depth_normal())
		_query_direction = _query_direction.normalized()
		var landing := _choose_destination(index)
		_query_foot = -1
		if landing.is_empty():
			continue
		var destination: Vector3 = landing.point
		if destination.distance_to(foot.marker.global_position) < 0.06:
			foot.dangling = false
			foot.strand_id = landing.get("strand_id", "")
			foot.planted_anchor = _rig.to_local(foot.marker.global_position)
			_visual_pose.anchors[index] = _pose_rest_local(index)
			continue
		var score := need + (8.0 if foot.dangling else 0.0)
		if urgent:
			score += 4.0
		if _needs_replant.has(index):
			score += 12.0
		if index % 2 != _last_side:
			score += 0.15
		if score > best:
			best = score
			selected = index
			selected_landing = landing
	if selected < 0:
		return
	_commit_step(selected, selected_landing)


func _commit_step(selected: int, selected_landing: Dictionary) -> void:
	assert(not selected_landing.is_empty())
	assert(targeting_mode != TargetingMode.WEB or has_web_support(selected_landing.point))
	var selected_foot := _feet[selected]
	var from_point := _planar(selected_foot.marker.global_position)
	var stride := from_point.distance_to(_planar(selected_landing.point))
	_steps.append({"index": selected, "start": selected_foot.marker.global_position,
		"end": selected_landing.point, "strand_id": selected_landing.get("strand_id", ""),
		"pose_anchor": _pose_rest_local(selected), "elapsed": 0.0,
		"duration": maxf(
			step_duration,
			1.5 * stride / maxf(foot_swing_speed, _travel_speed * 3.0),
		)})
	_next_lift = _clock + lift_spacing
	_last_side = selected % 2
	_forced_replacements.erase(selected)
	_needs_replant.erase(selected)
	history.append(selected)
	if history.size() > 64:
		history.pop_front()


func _can_lift(index: int) -> bool:
	var opposite := index ^ 1
	if not _feet[opposite].carried and _is_stepping(opposite):
		return false
	for direction in [-2, 2]:
		var neighbor: int = index + direction
		while neighbor >= 0 and neighbor < 8 and _feet[neighbor].carried:
			neighbor += direction
		if neighbor >= 0 and neighbor < 8 and _is_stepping(neighbor):
			return false
	var available := 0
	var supported := 0
	for other in range(8):
		if _feet[other].carried:
			continue
		available += 1
		if not _feet[other].dangling and not _is_stepping(other):
			supported += 1
	if _feet[index].dangling:
		return true
	var minimum := 4 if available >= 7 else 3
	return supported - 1 >= mini(minimum, available - 1)


func _advance_swings(delta: float) -> void:
	var remaining: Array[Dictionary] = []
	for swing in _steps:
		swing.elapsed += maxf(0.0, delta)
		var progress := minf(swing.elapsed / swing.duration, 1.0)
		var reach_phase := _smooth_phase(inverse_lerp(0.12, 0.78, progress))
		var start: Vector3 = swing.start
		var finish: Vector3 = swing.end
		var lift := minf(step_height, _planar(start).distance_to(_planar(finish)) * 0.25)
		var foot := _feet[swing.index]
		foot.marker.global_position = start.lerp(finish, reach_phase)
		var height := _smooth_phase(progress / 0.22) if progress < 0.22 else 1.0
		if progress > 0.68:
			height = 1.0 - _smooth_phase(inverse_lerp(0.68, 1.0, progress))
		foot.marker.global_position += _depth_normal() * lift * height
		if progress < 1.0:
			remaining.append(swing)
			continue
		if targeting_mode == TargetingMode.WEB and not has_web_support(finish):
			_release_foot(swing.index)
		else:
			foot.dangling = false
			foot.strand_id = swing.get("strand_id", "")
			foot.planted_anchor = _rig.to_local(finish)
			_visual_pose.anchors[swing.index] = swing.pose_anchor
			_landed[swing.index] = _clock
	_steps = remaining


func _start_urgent_replacements(priority: Array[int]) -> void:
	for index in priority:
		_forced_replacements[index] = true


func _release_crossed_feet() -> void:
	for index in range(_feet.size()):
		var foot := _feet[index]
		if foot.carried or foot.dangling or _is_stepping(index):
			continue
		var point := foot.marker.global_position
		if _inside_body(point):
			_needs_replant[index] = true
		else:
			_needs_replant.erase(index)
		if targeting_mode == TargetingMode.WEB:
			if not foot.support_checked or foot.support_position != point:
				foot.support = _find_support(point)
				foot.support_position = point
				foot.support_checked = true
			if foot.support.is_empty():
				_release_foot(index)


func _near_reach_limit(index: int) -> bool:
	var distance := get_leg_origin(index).distance_to(_feet[index].marker.global_position)
	return distance > get_leg_reach(index) * 0.88


func _limit_foot_reach() -> void:
	for index in range(_feet.size()):
		var foot := _feet[index]
		if foot.carried or _is_stepping(index):
			continue
		if get_leg_origin(index).distance_to(foot.marker.global_position) <= get_leg_reach(index):
			continue
		var landing := _choose_destination(index)
		if not landing.is_empty() and foot.marker.global_position.distance_to(landing.point) > 0.06:
			_commit_step(index, landing)
	super._limit_foot_reach()


func _dangling_position(index: int) -> Vector3:
	var resting_point := _pose_rest_position(index)
	var normal := _depth_normal()
	var height := _feet[index].ground_height + step_height * 0.5
	return resting_point + normal * (height - resting_point.dot(normal))


func can_land(index: int, candidate: Vector3) -> bool:
	if _inside_body(candidate):
		return false
	if _query_foot == index:
		var offset := candidate - _feet[index].marker.global_position
		offset -= _depth_normal() * offset.dot(_depth_normal())
		if offset.length() < minimum_stride or offset.dot(_query_direction) < minimum_stride * 0.6:
			return false
	return super.can_land(index, candidate)


func _inside_body(candidate: Vector3) -> bool:
	var local := _body_sprite.to_local(candidate)
	var center := body_footprint.get_center()
	var radius := body_footprint.size * 0.5
	var normalized := (Vector2(local.x, local.y) - center) / radius
	return normalized.length_squared() < 0.81


func _rest_destination(index: int) -> Vector3:
	var destination := _pose_rest_position(index)
	if _cycle.rig_moved:
		var lead := minimum_stride * 0.5 + _travel_speed * step_duration
		destination += _cycle.travel_direction * lead
	var normal := _depth_normal()
	destination += normal * (_feet[index].ground_height - destination.dot(normal))
	var hip := get_leg_origin(index)
	var depth := hip.dot(normal) - _feet[index].ground_height
	var plane_reach := sqrt(maxf(0.0, pow(get_leg_reach(index) * 0.95, 2.0) - depth * depth))
	var center := hip - normal * depth
	destination = center + (destination - center).limit_length(plane_reach)
	return destination


func _smooth_phase(value: float) -> float:
	var t := clampf(value, 0.0, 1.0)
	return t * t * t * (t * (t * 6.0 - 15.0) + 10.0)


func _choose_web_destination(index: int) -> Dictionary:
	if not is_instance_valid(support_web) or _cycle.support_segments.is_empty():
		return {}
	if not _support_bounds.grow(get_leg_reach(index) + 0.0001).has_point(get_leg_origin(index)):
		return {}
	var desired := _rest_destination(index)
	var landing := _find_landing_near(index, desired, landing_adjustment)
	if landing.is_empty() and (_feet[index].dangling or _needs_replant.has(index)):
		landing = _find_landing_near(index, _feet[index].marker.global_position, landing_adjustment)
		if landing.is_empty():
			landing = super._choose_web_destination(index)
	return landing


func _find_landing_near(index: int, desired: Vector3, radius: float) -> Dictionary:
	var best_error := radius * radius
	var desired_plane := _planar(desired)
	var best_landing: Dictionary = {}
	for segment in _segments_near(desired, radius):
		var start: Vector3 = segment.start
		var finish: Vector3 = segment.end
		var nearest := _closest_planar_parameter(desired, start, finish)
		var closest_plane := _planar(start.lerp(finish, nearest))
		if closest_plane.distance_squared_to(desired_plane) >= best_error:
			continue
		var length := maxf(start.distance_to(finish), 0.001)
		for distance in [0.0, -0.06, 0.06, -0.12, 0.12, -0.24, 0.24]:
			var point := start.lerp(finish, clampf(nearest + distance / length, 0.0, 1.0))
			var error := _planar(point).distance_squared_to(desired_plane)
			if error >= best_error or not can_land(index, point):
				continue
			if not _has_shared_strand_clearance(index, point, segment.strand_id):
				continue
			best_error = error
			best_landing = { "point": point, "strand_id": segment.strand_id }
	return best_landing


func _segments_near(point: Vector3, radius: float) -> Array[Dictionary]:
	if not is_instance_valid(support_web):
		return []
	return support_web.get_support_segments_near(point, radius)


func _choose_destination(index: int) -> Dictionary:
	if targeting_mode == TargetingMode.WEB:
		return _choose_web_destination(index)
	var desired := _rest_destination(index)
	return { "point": desired } if can_land(index, desired) else {}


func get_step_plans() -> Array[Dictionary]:
	return _steps.duplicate(true)


func landing_time(index: int) -> float:
	return _landed[index] if index >= 0 and index < _landed.size() else -1.0
