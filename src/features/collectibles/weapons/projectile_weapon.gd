class_name ProjectileWeapon3D extends Weapon3D

@export var projectile_scene: PackedScene

var is_thrown: bool = false


func fire(direction: float, power: float) -> void:
	var projectile: Projectile3D = projectile_scene.instantiate()
	var ancestor := get_parent()
	while ancestor != null:
		if ancestor is PlayerSpider3D:
			projectile.source_hurtbox = (ancestor as PlayerSpider3D).hurtbox
			break
		ancestor = ancestor.get_parent()
	get_tree().current_scene.add_child(projectile)
	projectile.global_position = global_position
	projectile.launch(direction, power)
	is_thrown = true


func is_used_up() -> bool:
	return is_thrown
