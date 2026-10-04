class_name Hurtbox3D extends Area3D

signal hurt(damage: float)

## Enclosing radius of this hurtbox in the X/Y gameplay plane.
@export_range(0.05, 3.0, 0.01) var plane_hit_radius: float = 0.425


func _ready() -> void:
	add_to_group("projectile_plane_targets")


func take_damage(damage: float) -> void:
	hurt.emit(damage)
