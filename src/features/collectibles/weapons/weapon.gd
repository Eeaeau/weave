class_name Weapon3D extends Collectible3D
# This class is mostly just used as a type/interface for weapons

@export var icon: Texture


func fire(direction: float, power: float) -> void:
	pass


func is_used_up() -> bool:
	"""
	Whether or not the weapon is used up. E.g. out of ammo
	"""
	return true
