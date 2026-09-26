class_name SpiderLegController3D
extends Node3D
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

@export_range(0.05, 2.0, 0.01) var step_distance := 0.35
@export_range(0.05, 1.0, 0.01) var step_duration := 0.22
@export_range(0.0, 1.0, 0.01) var step_height := 0.2
@export_range(0.0, 1.0, 0.01) var step_lead := 0.2

var _rig: Node3D
var _feet: Array[Marker3D] = []
var _rest_offsets: Array[Vector3] = []
var _ground_heights: Array[float] = []
var _last_rig_position := Vector3.ZERO
var _travel_direction := Vector3.ZERO
var _next_group := 0
var _steps: Array[Dictionary] = []
var _dangling: Array[bool] = []
var _step_elapsed := 0.0


func _ready() -> void:
	_rig = get_parent() as Node3D
	var targets := _rig.get_node("FootTargets")
	for foot_name in FOOT_NAMES:
		var foot := targets.get_node(foot_name) as Marker3D
		var planted_position := foot.global_position
		_rest_offsets.append(_rig.to_local(planted_position))
		_ground_heights.append(planted_position.y)
		foot.top_level = true
		foot.global_position = planted_position
		_feet.append(foot)
		_dangling.append(false)
	_last_rig_position = _rig.global_position


func _process(delta: float) -> void:
	advance(delta)


func advance(delta: float) -> void:
	if _feet.size() != FOOT_NAMES.size():
		return
	var travel := _rig.global_position - _last_rig_position
	travel.y = 0.0
	if not travel.is_zero_approx():
		_travel_direction = travel.normalized()
	_last_rig_position = _rig.global_position
	_update_dangling()
	_release_crossed_feet()
	if not _steps.is_empty():
		_animate_step(delta)
		return
	if not _start_group(_next_group):
		_start_group(1 - _next_group)
	if not _steps.is_empty():
		_animate_step(delta)


func _start_group(group_index: int) -> bool:
	for foot_index in STEP_GROUPS[group_index]:
		var landing := _choose_destination(foot_index)
		if landing.is_empty():
			_dangling[foot_index] = true
			_feet[foot_index].global_position = _dangling_position(foot_index)
			continue
		var destination: Vector3 = landing["point"]
		var gap := destination - _feet[foot_index].global_position
		gap.y = 0.0
		if gap.length() <= step_distance and not _dangling[foot_index]:
			continue
		_steps.append({
			"index": foot_index,
			"start": _feet[foot_index].global_position,
			"end": destination,
		})
	if _steps.is_empty():
		return false
	_step_elapsed = 0.0
	_next_group = 1 - group_index
	return true


func is_dangling(foot_index: int) -> bool:
	return foot_index >= 0 and foot_index < _dangling.size() and _dangling[foot_index]


func _update_dangling() -> void:
	for foot_index in range(_feet.size()):
		if _dangling[foot_index] and not _is_stepping(foot_index):
			_feet[foot_index].global_position = _dangling_position(foot_index)


func _release_crossed_feet() -> void:
	for foot_index in range(_feet.size()):
		if _dangling[foot_index] or _is_stepping(foot_index):
			continue
		if not can_land(foot_index, _feet[foot_index].global_position):
			_dangling[foot_index] = true
			_feet[foot_index].global_position = _dangling_position(foot_index)


func _dangling_position(foot_index: int) -> Vector3:
	var foot_position := _lift_position(foot_index)
	foot_position.y = _ground_heights[foot_index] - step_height * 0.25
	return foot_position


func _is_stepping(foot_index: int) -> bool:
	for active_step in _steps:
		if active_step["index"] == foot_index:
			return true
	return false


func _choose_destination(foot_index: int) -> Dictionary:
	var desired := _rest_destination(foot_index)
	if can_land(foot_index, desired):
		return { "point": desired }
	var without_lead := desired - _travel_direction * step_lead
	if can_land(foot_index, without_lead):
		return { "point": without_lead }
	var side := -1.0 if _rest_offsets[foot_index].x < 0.0 else 1.0
	for sideways in [0.12, 0.24, 0.36]:
		var candidate: Vector3 = desired + _rig.global_basis.x.normalized() * side * float(sideways)
		if can_land(foot_index, candidate):
			return { "point": candidate }
	return {}


func can_land(foot_index: int, candidate: Vector3) -> bool:
	if foot_index < 0 or foot_index >= _feet.size():
		return false
	var local_candidate := _rig.to_local(candidate)
	if local_candidate.x * _rest_offsets[foot_index].x <= 0.0:
		return false
	var from_point := _planar(_lift_position(foot_index))
	var to_point := _planar(candidate)
	for other_index in range(_feet.size()):
		if other_index == foot_index:
			continue
		if _dangling[other_index] and not _is_stepping(other_index):
			continue
		var other_foot := _feet[other_index].global_position
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
	var destination := _rig.to_global(_rest_offsets[foot_index])
	destination += _travel_direction * step_lead
	destination.y = _ground_heights[foot_index]
	return destination


func _animate_step(delta: float) -> void:
	_step_elapsed += delta
	var progress := minf(_step_elapsed / step_duration, 1.0)
	var eased := progress * progress * (3.0 - 2.0 * progress)
	for active_step in _steps:
		var start: Vector3 = active_step["start"]
		var destination: Vector3 = active_step["end"]
		var foot_position := start.lerp(destination, eased)
		foot_position.y += 4.0 * step_height * progress * (1.0 - progress)
		var foot_index: int = active_step["index"]
		_feet[foot_index].global_position = foot_position
	if progress >= 1.0:
		for active_step in _steps:
			var foot_index: int = active_step["index"]
			_dangling[foot_index] = false
		_steps.clear()
