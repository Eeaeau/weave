class_name WebStrand3D
extends Node3D
## A flat strand sprite between two 3D endpoints. Durability is data only.

@export var endpoint_a: Vector3 = Vector3.ZERO
@export var endpoint_b: Vector3 = Vector3(1, 0, 0)
@export_range(1, 100) var durability: int = 3


func _ready() -> void:
	var sprite: Sprite3D = $Sprite3D
	var offset := endpoint_b - endpoint_a
	if offset.is_zero_approx():
		sprite.visible = false
		return
	var direction := offset.normalized()
	sprite.position = (endpoint_a + endpoint_b) * 0.5
	sprite.basis = Basis(direction, Vector3.UP.cross(direction), Vector3.UP)
	sprite.scale.x = offset.length() / (sprite.texture.get_width() * sprite.pixel_size)
