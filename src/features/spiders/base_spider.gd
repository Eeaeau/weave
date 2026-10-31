class_name BaseSpider3D
extends Node3D
## Shared spider identity backed by the armature-driven visual rig.

@export_range(0.5, 12.0, 0.1) var visual_turn_speed := 3.0
@export var team_name: String = "Team"

var _desired_facing := NAN

@onready var visual_rig: Node3D = $SpiderRig
@onready var body: Sprite3D = $SpiderRig/BoneAttachment3D/BodyOffset/Body


func _ready() -> void:
	body.modulate = Color.WHITE


func _process(delta: float) -> void:
	advance_visual_facing(delta)


func face_direction(angle: float) -> void:
	_desired_facing = angle


func advance_visual_facing(delta: float) -> void:
	if is_nan(_desired_facing):
		return
	var difference := angle_difference(visual_rig.rotation.y, _desired_facing)
	var limit := visual_turn_speed * maxf(0.0, delta)
	visual_rig.rotation.y += clampf(difference, -limit, limit)
