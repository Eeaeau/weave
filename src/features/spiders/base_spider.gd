class_name BaseSpider3D
extends Node3D
## Shared spider identity backed by the armature-driven visual rig.

@export_range(0.5, 12.0, 0.1) var visual_turn_speed := 2.1
@export_range(0.0, 0.04, 0.0025) var body_surge := 0.015
@export var team_name: String = "Team"

var _desired_facing := NAN
var _body_offset := Vector3.ZERO
var _body_velocity := Vector3.ZERO
var _body_last_position := Vector3.ZERO
var _landings: Array[float] = []

@onready var visual_rig: Node3D = $SpiderRig
@onready var body: Sprite3D = $SpiderRig/BoneAttachment3D/BodyOffset/Body
@onready var _rig_rest_position: Vector3 = visual_rig.position
@onready var _gait: Node = $SpiderRig/LegController


func _ready() -> void:
	body.modulate = Color.WHITE
	_body_last_position = global_position
	_landings.resize(8)
	_landings.fill(-1.0)


func _process(delta: float) -> void:
	advance_visual_facing(delta)
	_advance_body_motion(delta)


func face_direction(angle: float) -> void:
	_desired_facing = angle


func advance_visual_facing(delta: float) -> void:
	if is_nan(_desired_facing):
		return
	var difference := angle_difference(visual_rig.rotation.y, _desired_facing)
	var limit := visual_turn_speed * maxf(0.0, delta)
	visual_rig.rotation.y += clampf(difference, -limit, limit)


func _advance_body_motion(delta: float) -> void:
	var movement := global_position - _body_last_position
	_body_last_position = global_position
	if not _gait.has_method("landing_time"):
		return
	var contacts := 0
	for index in range(8):
		var landed: float = _gait.landing_time(index)
		if landed > _landings[index]:
			contacts += 1
		_landings[index] = landed
	var speed := movement.length() / maxf(delta, 0.001)
	if contacts > 0 and speed > 0.05:
		var impulse := body_surge * 24.0 * contacts * minf(speed / 0.8, 1.0)
		_body_velocity += movement.normalized() * impulse
		_body_velocity = _body_velocity.limit_length(body_surge * 32.0)
	if body_surge <= 0.0:
		_body_offset = Vector3.ZERO
		_body_velocity = Vector3.ZERO
	else:
		var elapsed := minf(delta, 0.05)
		var steps := maxi(1, ceili(elapsed / 0.008))
		var dt := elapsed / steps
		for iteration in range(steps):
			_body_velocity += (-_body_offset * 144.0 - _body_velocity * 18.0) * dt
			_body_offset = (_body_offset + _body_velocity * dt).limit_length(body_surge)
	visual_rig.position = _rig_rest_position + global_basis.inverse() * _body_offset
