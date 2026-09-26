class_name WeaponNoAction extends Weapon3D
# Do nothing


func fire(aim_direction: float, aim_magnitude: float) -> void:
	pass


func is_used_up() -> bool:
	return false
