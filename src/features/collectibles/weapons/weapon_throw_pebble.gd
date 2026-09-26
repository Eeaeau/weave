class_name WeaponThrowPebble extends Weapon3D

var projectile_scene = preload("res://src/features/collectibles/weapons/pebble_projectile.tscn")
var is_thrown: bool = false
var projectile_spawn = Vector3(0.5, 0, 0)


func fire(direction: float, power: float) -> void:
	print("Throwing pebble in direction {0} with power {1}".format([direction, power]))
	var pebble: PebbleProjectile3D = projectile_scene.instantiate()
	pebble.position += projectile_spawn.rotated(Vector3.UP, direction)
	add_child(pebble)
	pebble.reparent(get_parent_node_3d())
	pebble.launch(direction, power)
	is_thrown = true


func is_used_up() -> bool:
	return is_thrown
