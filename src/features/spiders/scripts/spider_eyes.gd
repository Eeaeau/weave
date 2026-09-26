@tool
class_name SpiderEyes3D
extends Node3D
## Moves the spider's pupils toward an animatable local-space target.

@export_group("Nodes")
@export var left_eye: Sprite3D
@export var right_eye: Sprite3D
@export var look_at_pos: Marker3D
@export var left_eye_center: Marker3D
@export var right_eye_center: Marker3D
@export_group("Motion")
@export_range(0.0, 0.5, 0.005, "or_greater") var eye_radius := 0.08
@export_range(0.0, 1.0, 0.01) var influence := 1.0
@export_group("Neutral Positions")
@export var left_neutral_position := Vector3(-0.099202484, 0.5124047, -0.29688102)
@export var right_neutral_position := Vector3(-0.22503239, 0.5124047, -0.3552975)


func _ready() -> void:
	if left_eye == null or right_eye == null:
		push_warning("Spider eyes require both pupil sprites")
		set_process(false)
		return
	_update_eye_positions()


func _process(_delta: float) -> void:
	_update_eye_positions()


func _notification(what: int) -> void:
	if not Engine.is_editor_hint() or left_eye == null or right_eye == null:
		return
	if what == NOTIFICATION_EDITOR_PRE_SAVE:
		left_eye.position = left_neutral_position
		right_eye.position = right_neutral_position
	elif what == NOTIFICATION_EDITOR_POST_SAVE:
		_update_eye_positions()


func _update_eye_positions() -> void:
	if left_eye == null or right_eye == null:
		return
	left_eye.position = left_neutral_position + _offset_for_eye(left_eye_center)
	right_eye.position = right_neutral_position + _offset_for_eye(right_eye_center)


func _offset_for_eye(eye_center: Marker3D) -> Vector3:
	if look_at_pos == null or eye_center == null:
		return Vector3.ZERO
	var target := to_local(look_at_pos.global_position)
	var center := to_local(eye_center.global_position)
	var planar_offset := Vector2(target.x - center.x, target.z - center.z)
	planar_offset = planar_offset.limit_length(eye_radius) * influence
	return Vector3(planar_offset.x, 0.0, planar_offset.y)
