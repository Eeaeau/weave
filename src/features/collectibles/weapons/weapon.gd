class_name Weapon3D extends Collectible3D
# This class is mostly just used as a type/interface for weapons

@export var icon: Texture
@export var icon_material: ShaderMaterial
@export_group("Carrying")
@export var rear_grip: Marker3D
@export var front_grip: Marker3D


func fire(direction: float, power: float) -> void:
	pass


func is_used_up() -> bool:
	"""
	Whether or not the weapon is used up. E.g. out of ammo
	"""
	return true
