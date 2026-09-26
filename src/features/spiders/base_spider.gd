class_name BaseSpider3D
extends Node3D
## Shared spider identity backed by the armature-driven visual rig.

@export var team_name: String = "Team"
@export var body_color: Color = Color("b9d8a5")

@onready var body: Sprite3D = $SpiderRig/BoneAttachment3D/BodyOffset/Body


func _ready() -> void:
	body.modulate = body_color
