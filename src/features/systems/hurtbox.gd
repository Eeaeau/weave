class_name Hurtbox3D extends Area3D

signal hurt(damage: float)


func take_damage(damage: float) -> void:
	hurt.emit(damage)
