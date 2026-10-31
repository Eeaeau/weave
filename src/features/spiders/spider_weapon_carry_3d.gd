class_name SpiderWeaponCarry3D
extends Node
## Transfers authored weapon grips between limbs without delaying aim or movement.

const MIDDLE_PAIRS := [[2, 3], [3, 5], [5, 4], [4, 2]]

@export_range(0.05, 0.6, 0.01) var handoff_duration := 0.18
@export_range(0.0, 0.3, 0.01) var handoff_lift := 0.12
@export_range(45.0, 180.0, 5.0) var handoff_angle_degrees := 90.0

var _rig: Node3D
var _gait: Node
var _mount: Marker3D
var _weapon: Weapon3D
var _hands: Dictionary = {}
var _pending: Array[Dictionary] = []
var _transition: Dictionary = {}
var _last_relative := 0.0
var _rotation_since_switch := 0.0
var _tracking := false
var _initializing := false


func _ready() -> void:
	_rig = get_parent() as Node3D
	_gait = _rig.get_node("LegController")
	_mount = _rig.get_node("BoneAttachment3D/BodyOffset/WeaponEquipTarget")


func set_weapon(weapon: Weapon3D) -> void:
	if _weapon == weapon:
		return
	_weapon = weapon
	_hands.clear()
	_pending.clear()
	_transition.clear()
	_rotation_since_switch = 0.0
	_tracking = false
	_initializing = false


func get_holding_feet() -> Array[int]:
	var result: Array[int] = []
	for foot in _hands.values():
		result.append(int(foot))
	result.sort()
	return result


func get_grip_foot(slot: int) -> int:
	return int(_hands.get(slot, -1))


func advance(delta: float) -> void:
	var grips := _grip_points()
	if grips.is_empty():
		_gait.set_carried_feet({})
		return
	_track_rotation()
	if _hands.is_empty() and _pending.is_empty() and _transition.is_empty():
		var assignment := _choose_assignment(grips, false)
		for slot in range(assignment.size()):
			_pending.append({ "slot": slot, "foot": assignment[slot] })
		_initializing = true
	if _initializing:
		_rotation_since_switch = 0.0
	if not _initializing and _pending.is_empty() and _transition.is_empty():
		_try_handoff(grips)
	if _transition.is_empty() and not _pending.is_empty():
		_transition = _pending.pop_front()
		var foot: int = _transition.foot
		var marker: Node3D = _rig.get_node("FootTargets/" + _gait.FOOT_NAMES[foot])
		_transition.start = marker.global_position
		_transition.elapsed = 0.0
	if not _transition.is_empty():
		_transition.elapsed = minf(handoff_duration, _transition.elapsed + maxf(0.0, delta))
	_gait.set_carried_feet(_pose_targets(grips))
	if not _transition.is_empty() and _transition.elapsed >= handoff_duration:
		_hands[_transition.slot] = _transition.foot
		_transition.clear()
	if _pending.is_empty() and _transition.is_empty():
		_initializing = false


func _try_handoff(grips: Array[Vector3]) -> void:
	var current: Array[int] = []
	for slot in range(grips.size()):
		current.append(_hands[slot])
	var unsafe := is_inf(_assignment_score(current, grips))
	var threshold := deg_to_rad(handoff_angle_degrees)
	if not unsafe and absf(_rotation_since_switch) < threshold:
		return
	var assignment := _choose_assignment(grips, true)
	if assignment.is_empty() or assignment == current:
		return
	_begin_handoff(assignment)
	if unsafe:
		_rotation_since_switch = 0.0
	else:
		_rotation_since_switch -= signf(_rotation_since_switch) * threshold


func _grip_points() -> Array[Vector3]:
	var points: Array[Vector3] = []
	if not is_instance_valid(_weapon) or not is_instance_valid(_weapon.rear_grip):
		return points
	points.append(_weapon.rear_grip.global_position)
	if is_instance_valid(_weapon.front_grip):
		points.append(_weapon.front_grip.global_position)
	return points


func _track_rotation() -> void:
	var aim := _mount.global_basis.x
	var forward := _rig.global_basis.z
	var relative := atan2(aim.y, aim.x) - atan2(forward.y, forward.x)
	if _tracking:
		_rotation_since_switch += angle_difference(_last_relative, relative)
	_last_relative = relative
	_tracking = true


func _choose_assignment(grips: Array[Vector3], handoff: bool) -> Array[int]:
	var candidates: Array = [[0], [1]] if grips.size() == 1 else MIDDLE_PAIRS
	var best: Array[int] = []
	var best_score := INF
	for pair in candidates:
		for flip in range(pair.size()):
			var order: Array[int] = []
			order.assign(pair)
			if flip == 1:
				order.reverse()
			if handoff and grips.size() == 2 and _shared_count(order) != 1:
				continue
			var score := _assignment_score(order, grips)
			if score < best_score:
				best = order
				best_score = score
	return best


func _shared_count(order: Array[int]) -> int:
	var count := 0
	for foot in order:
		if _hands.values().has(foot):
			count += 1
	return count


func _assignment_score(order: Array[int], grips: Array[Vector3]) -> float:
	var score := 0.0
	for slot in range(order.size()):
		var origin: Vector3 = _gait.get_leg_origin(order[slot])
		var reach: float = _gait.get_leg_reach(order[slot])
		var distance := origin.distance_squared_to(grips[slot])
		if distance > reach * reach:
			return INF
		score += distance
	if order.size() == 2:
		var a: Vector3 = _gait.get_leg_origin(order[0])
		var b: Vector3 = _gait.get_leg_origin(order[1])
		if Geometry2D.segment_intersects_segment(
				Vector2(a.x, a.y), Vector2(grips[0].x, grips[0].y),
				Vector2(b.x, b.y), Vector2(grips[1].x, grips[1].y)) != null:
			return INF
	return score


func _begin_handoff(assignment: Array[int]) -> void:
	if assignment.size() == 1:
		_pending.append({ "slot": 0, "foot": assignment[0] })
		return
	var retained := -1
	var old_slot := -1
	for slot in _hands:
		if assignment.has(_hands[slot]):
			retained = _hands[slot]
			old_slot = slot
			break
	var new_slot := assignment.find(retained)
	_hands.clear()
	_hands[new_slot] = retained
	_pending.append({"slot": 1 - new_slot, "foot": assignment[1 - new_slot],
		"slide_from": old_slot, "slide_to": new_slot})


func _pose_targets(grips: Array[Vector3]) -> Dictionary:
	var targets: Dictionary = {}
	var progress := 1.0 if _transition.is_empty() else float(_transition.elapsed) / handoff_duration
	var eased := smoothstep(0.0, 1.0, progress)
	for slot in _hands:
		var point := grips[slot]
		if _transition.get("slide_to", -1) == slot:
			point = grips[_transition.slide_from].lerp(point, eased)
		targets[_hands[slot]] = point
	if not _transition.is_empty():
		var destination := grips[_transition.slot]
		var start: Vector3 = _transition.start
		var point := start.lerp(destination, eased)
		point += Vector3.BACK * handoff_lift * sin(PI * progress)
		targets[_transition.foot] = point
	return targets
