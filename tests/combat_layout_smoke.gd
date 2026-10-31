extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var arena: WebMatch3D = load("res://src/game/web_match.tscn").instantiate()
	root.add_child(arena)
	current_scene = arena
	await process_frame
	arena.process_mode = Node.PROCESS_MODE_DISABLED
	var player: PlayerSpider3D = arena.get_node("TeamA").spiders[0]
	var weapon: Weapon3D = load(
		"res://src/features/collectibles/weapons/weapon_rocket_launcher.tscn").instantiate()
	player.add_child(weapon)
	player.pick_up(weapon)
	await process_frame
	player.select_weapon(2)
	player.is_active = true
	var mount := player._get_weapon_equip_target()
	var body: Node3D = player.get_node("SpiderRig/BoneAttachment3D/BodyOffset/Body")
	for angle in [-PI, -PI / 2.0, 0.0, 0.6, PI / 2.0]:
		player.aim_angle = angle
		player.update_presentation()
		var offset := mount.global_position - body.global_position
		assert(Vector2(offset.x, offset.y).length() < 0.02,
			"Launcher pivot must be centered over the spider's body")
		var forward := Vector3(cos(angle), sin(angle), 0)
		assert(player.aim_arrow.global_basis.x.normalized().dot(forward) > 0.999,
			"Aim arrow must follow XY: angle=%s axis=%s active=%s health=%s selected=%s" % [
				angle, player.aim_arrow.global_basis.x, player.is_active, player.health,
				player.selected_weapon_idx])
		var arrow_offset := player.aim_arrow.global_position - mount.global_position
		assert(absf(arrow_offset.dot(Vector3(-sin(angle), cos(angle), 0))) < 0.01,
			"Aim arrow must share the launcher's aiming line")
	var expected_origin := player.global_position + player.projectile_spawn_offset
	for turn in [0.0, 1.0, -1.0]:
		player.spider_rig.rotation.y = turn
		player.update_presentation()
		weapon.fire(0.0, 1.0)
		var shot: Projectile3D = get_nodes_in_group("camera_focus_projectiles")[-1]
		assert(shot.global_position.is_equal_approx(expected_origin),
			"Cosmetic turning must not change the gameplay shot origin")
		shot.free()
	var hurt_shape := player.hurtbox.get_node("CollisionShape3D") as CollisionShape3D
	assert(absf(hurt_shape.global_basis.y.normalized().dot(Vector3.BACK)) > 0.999)
	var shape := hurt_shape.shape as CapsuleShape3D
	assert(shape.radius >= 0.5 and shape.height >= 2.0,
		"Spider hitbox must cover its body and extend through the gameplay plane")
	var anchor: Node3D = arena.catch_webs[0].valid_nodes[0]
	var anchor_shape := anchor.get_node("ProjectileHitbox").get_child(0) as CollisionShape3D
	assert(anchor_shape.shape is CapsuleShape3D and anchor_shape.shape.radius >= 0.4)
	assert(absf(anchor_shape.global_basis.y.normalized().dot(Vector3.BACK)) > 0.999)
	arena.queue_free()
	await process_frame
	await create_timer(0.2).timeout
	print("COMBAT LAYOUT PASS: centered launcher, aligned aim and larger depth-safe hitboxes")
	quit(0)
