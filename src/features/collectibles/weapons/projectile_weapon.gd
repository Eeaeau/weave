class_name ProjectileWeapon3D extends Weapon3D

@export var projectile_scene: PackedScene

var is_thrown: bool = false


func fire(direction: float, power: float) -> void:
	var session := get_node_or_null("/root/OnlineSession")
	if (session != null and session.is_match_active()
			and session.host_id != get_node("/root/GDSync").get_client_id()):
		return
	var projectile: Projectile3D = projectile_scene.instantiate()
	var origin := global_position
	var ancestor := get_parent()
	while ancestor != null:
		if ancestor is PlayerSpider3D:
			projectile.source_hurtbox = (ancestor as PlayerSpider3D).hurtbox
			origin = ancestor.global_position + (ancestor as PlayerSpider3D).projectile_spawn_offset
			break
		ancestor = ancestor.get_parent()
	get_tree().current_scene.add_child(projectile)
	projectile.global_position = origin
	projectile.launch(direction, power)
	if session != null and session.is_match_active() and session.replication != null:
		session.replication.register_projectile(projectile)
	is_thrown = true


func is_used_up() -> bool:
	return is_thrown
