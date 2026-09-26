class_name WeaponThrowPebble extends Weapon3D

var projectile_scene = preload("res://src/features/collectibles/weapons/pebble_projectile.tscn")
var is_thrown: bool = false


func fire(direction: float, power: float) -> void:
	print("Throwing pebble in direction {0} with power {1}".format([direction, power]))
	var pebble: PebbleProjectile3D = projectile_scene.instantiate()
	get_tree().current_scene.add_child(pebble)
	pebble.global_position = get_parent_node_3d().global_position + Vector3.UP
	pebble.launch(direction, power)
	is_thrown = true


func is_used_up() -> bool:
	return is_thrown
