class_name SpiderEyes3D
extends Node3D
## Moves the spider's pupils toward an animatable local-space target.

@export var left_eye: Sprite3D
@export var right_eye: Sprite3D
@export var look_at_pos: Marker3D
@export_range(0.0, 0.5, 0.005, "or_greater") var eye_radius := 0.08
@export_range(0.0, 1.0, 0.01) var influence := 1.0

var _left_neutral_position := Vector3.ZERO
var _right_neutral_position := Vector3.ZERO


func _ready() -> void:
	if left_eye == null or right_eye == null:
		push_warning("Spider eyes require both pupil sprites")
		set_process(false)
		return
	_left_neutral_position = left_eye.position
	_right_neutral_position = right_eye.position
	_update_eye_positions()


func _process(_delta: float) -> void:
	_update_eye_positions()


func _update_eye_positions() -> void:
	if left_eye == null or right_eye == null:
		return
	var offset := Vector3.ZERO
	if look_at_pos != null:
		var target := to_local(look_at_pos.global_position)
		var planar_offset := Vector2(target.x, target.z).limit_length(eye_radius)
		planar_offset *= influence
		offset = Vector3(planar_offset.x, 0.0, planar_offset.y)
	left_eye.position = _left_neutral_position + offset
	right_eye.position = _right_neutral_position + offset
