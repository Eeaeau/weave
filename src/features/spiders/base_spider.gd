class_name BaseSpider3D
extends Node3D
## Shared spider identity backed by the armature-driven visual rig.

@export var team_name: String = "Team"

@onready var body: Sprite3D = $SpiderRig/BoneAttachment3D/BodyOffset/Body


func _ready() -> void:
	body.modulate = Color.WHITE
