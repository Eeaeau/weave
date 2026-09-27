class_name ProjectileWeapon3D extends Weapon3D

@export var projectile_scene: PackedScene

var is_thrown: bool = false


func fire(direction: float, power: float) -> void:
	var projectile: Projectile3D = projectile_scene.instantiate()
	get_tree().current_scene.add_child(projectile)
	projectile.global_position = get_parent_node_3d().global_position + Vector3.UP * 2
	projectile.launch(direction, power)
	is_thrown = true


func is_used_up() -> bool:
	return is_thrown
