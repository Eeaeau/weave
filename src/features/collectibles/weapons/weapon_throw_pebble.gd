class_name WeaponThrowPebble extends Weapon3D

var is_thrown: bool = false


func fire(direction: float, power: float) -> void:
	print("Throwing pebble in direction {0} with power {1}".format([direction, power]))


func is_used_up() -> bool:
	return is_thrown
