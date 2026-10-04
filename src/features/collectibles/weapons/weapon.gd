class_name Weapon3D extends Collectible3D
# This class is mostly just used as a type/interface for weapons

enum CarryStyle {
	NONE,
	FRONT_LEFT,
	MIDDLE_PAIR,
}

@export var icon: Texture
@export var carry_style: CarryStyle = CarryStyle.NONE
@export_range(0.0, 0.2, 0.005) var carry_bob_amplitude := 0.035
@export_range(0.0, 0.5, 0.01) var recoil_distance := 0.16


func carry_grips() -> Dictionary:
	match carry_style:
		CarryStyle.FRONT_LEFT:
			return { 0: get_node_or_null("GripLeft") as Marker3D }
		CarryStyle.MIDDLE_PAIR:
			return {
				2: get_node_or_null("GripLeft") as Marker3D,
				3: get_node_or_null("GripRight") as Marker3D,
			}
	return {}


func fire(direction: float, power: float) -> void:
	pass


func is_used_up() -> bool:
	"""
	Whether or not the weapon is used up. E.g. out of ammo
	"""
	return true
