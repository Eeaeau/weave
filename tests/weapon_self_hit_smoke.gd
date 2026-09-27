extends SceneTree
## A carried projectile must leave its firing spider unharmed.

const MATCH_SCENE := preload("res://src/game/web_match.tscn")
const WEAPON_SCENES := [
	preload("res://src/features/collectibles/weapons/weapon_throw_pebble.tscn"),
	preload("res://src/features/collectibles/weapons/weapon_rocket_launcher.tscn"),
]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if not await _check_weapon(WEAPON_SCENES[0]):
		quit(1)
		return
	if not await _check_weapon(WEAPON_SCENES[1]):
		quit(1)
		return
	if not _check_rocket_range():
		quit(1)
		return
	await create_timer(0.5).timeout
	print("WEAPON SELF HIT PASS: launch safety and later damage for pebble and rocket")
	quit(0)


func _check_weapon(weapon_scene: PackedScene) -> bool:
	var match_scene := MATCH_SCENE.instantiate() as WebMatch3D
	root.add_child(match_scene)
	current_scene = match_scene
	await create_timer(0.0).timeout
	var manager := match_scene.get_node("MatchManager") as MatchManager
	var wind := match_scene.get_node("BranchCanopy/WindEvent") as WindEvent3D
	wind.is_active = false
	manager.waiting_for_wind = false
	var team := match_scene.get_node("TeamA") as Team
	team.start_turn(10.0)
	var spider := team.get_active_spider()
	var weapon := weapon_scene.instantiate() as ProjectileWeapon3D
	match_scene.add_child(weapon)
	spider.pick_up(weapon)
	weapon.after_picked_up()
	await create_timer(0.0).timeout
	spider.select_weapon(spider.weapons.find(weapon))
	spider.aim_angle = PI / 4.0
	spider._update_weapon_pose()
	var forward := (weapon.get_node("Sprite3D") as Sprite3D).global_basis.y.normalized()
	var expected_forward := Vector3.RIGHT.rotated(Vector3.UP, spider.aim_angle)
	var aims_forward := forward.dot(expected_forward) > 0.98
	Input.action_press("action")
	await process_frame
	Input.action_release("action")
	await process_frame
	await _wait_for_launch()
	var unharmed := true
	for ally in team.spiders:
		if not is_equal_approx(ally.health, 1.0) or not ally.visible:
			unharmed = false
	var opponent := (match_scene.get_node("TeamB") as Team).get_active_spider()
	var projectile: Projectile3D
	for child in match_scene.get_children():
		if child is Projectile3D:
			projectile = child
			break
	var damages_opponent := false
	if projectile != null:
		projectile.global_position = opponent.global_position + Vector3.UP * 0.3
		projectile._hitbox_entered(opponent.hurtbox)
		await physics_frame
		await physics_frame
		damages_opponent = opponent.health < 1.0
	_stop_audio(match_scene)
	match_scene.free()
	current_scene = null
	if not unharmed:
		return _fail("Firing %s must not damage spiders at the launch point"
			% weapon_scene.resource_path)
	if weapon_scene == WEAPON_SCENES[1] and not aims_forward:
		return _fail("Carried %s points %s instead of %s"
			% [weapon_scene.resource_path, forward, expected_forward])
	if not damages_opponent:
		return _fail("A fired %s must still damage an opponent"
			% weapon_scene.resource_path)
	return true


func _check_rocket_range() -> bool:
	var pebble := WEAPON_SCENES[0].instantiate() as ProjectileWeapon3D
	var rocket := WEAPON_SCENES[1].instantiate() as ProjectileWeapon3D
	var pebble_projectile := pebble.projectile_scene.instantiate() as Projectile3D
	var rocket_projectile := rocket.projectile_scene.instantiate() as Projectile3D
	root.add_child(pebble_projectile)
	root.add_child(rocket_projectile)
	pebble_projectile.launch(0.0, 1.0)
	rocket_projectile.launch(0.0, 1.0)
	var has_longer_range := rocket_projectile.velocity.x > pebble_projectile.velocity.x * 1.4
	pebble_projectile.free()
	rocket_projectile.free()
	pebble.free()
	rocket.free()
	if not has_longer_range:
		return _fail("Rocket must launch faster than the pebble at equal charge")
	return true


func _wait_for_launch() -> void:
	await physics_frame
	await physics_frame
	await physics_frame
	await physics_frame
	await physics_frame
	await physics_frame
	await physics_frame
	await physics_frame


func _stop_audio(node: Node) -> void:
	if node is AudioStreamPlayer:
		node.stop()
		node.stream = null
	for child in node.get_children():
		_stop_audio(child)


func _fail(message: String) -> bool:
	push_error("WEAPON SELF HIT FAIL: " + message)
	return false
