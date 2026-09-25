class_name WebStrand3D
extends Node3D
## A 3D strand placeholder. Durability is data until web rules are built.

@export var endpoint_a: Vector3 = Vector3.ZERO
@export var endpoint_b: Vector3 = Vector3(1, 0, 0)
@export_range(1, 100) var durability: int = 3


func _ready() -> void:
	SceneGeometry3D.segment(self, endpoint_a, endpoint_b, 0.035, Color("c6e3df"))
