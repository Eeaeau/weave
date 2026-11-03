extends SceneTree

const PROJECTILES := [
	preload("res://src/features/collectibles/weapons/pebble_projectile.tscn"),
	preload("res://src/features/collectibles/weapons/rocket_projectile.tscn"),
	preload("res://src/features/collectibles/weapons/guided_rocket_projectile.tscn"),
]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var branch: Node3D = load(
		"res://src/features/world/maps/branch_canopy/branch_web.tscn").instantiate()
	root.add_child(branch)
	current_scene = branch
	var colliders := branch.get_node_or_null("BranchProjectileColliders") as Area3D
	var passed := _check_authoring(branch, colliders)
	if passed:
		var blocker := colliders.get_child(0) as CollisionShape3D
		var anchor := branch.get_node("WebAnchors").get_child(0) as Marker3D
		var original := anchor.global_position
		blocker.position.x += 4.0
		passed = anchor.global_position.is_equal_approx(original)
		if not passed:
			_fail("Moving a branch blocker moved its web anchor")
		else:
			colliders.reparent(root)
			branch.free()
			branch = null
			passed = await _check_hits(blocker)
			if passed:
				colliders.scale.x = -1
				passed = await _check_hits(blocker)
	if is_instance_valid(branch):
		branch.free()
	if is_instance_valid(colliders):
		colliders.free()
	current_scene = null
	await create_timer(0.6).timeout
	if not passed:
		quit(1)
		return
	print("BRANCH COLLIDERS PASS: editable, independent regions and depth-safe projectile impacts")
	quit(0)


func _check_authoring(branch: Node3D, colliders: Area3D) -> bool:
	if colliders == null:
		return _fail("Branch scene has no editable projectile colliders")
	if (not colliders.is_in_group("projectile_blockers") or colliders.collision_layer != 16
			or colliders.get_child_count() == 0):
		return _fail("Branch regions must be detected by projectile hitboxes")
	var shapes: Array[Shape3D] = []
	for blocker in colliders.get_children():
		if not blocker is CollisionShape3D or blocker.owner != branch:
			return _fail("Branch regions must be saved, editor-selectable collision shapes")
		if not blocker.shape is BoxShape3D:
			return _fail("Branch regions must have editable box dimensions")
		if shapes.has(blocker.shape):
			return _fail("Resizing one blocker would change another blocker's shape")
		shapes.append(blocker.shape)
	return true


func _check_hits(blocker: CollisionShape3D, index: int = 0) -> bool:
	if index >= PROJECTILES.size() * 2:
		return true
	var projectile := PROJECTILES[index / 2].instantiate() as Projectile3D
	root.add_child(projectile)
	projectile.set_process(false)
	projectile.explosion_damage = 0.0
	var depth: float = blocker.shape.size.z * (0.25 if index % 2 == 0 else -0.25)
	projectile.global_position = blocker.to_global(Vector3(0, 0, depth))
	await physics_frame
	await physics_frame
	var hit := not is_instance_valid(projectile) or projectile.freeze
	if is_instance_valid(projectile):
		projectile.free()
	if not hit:
		return _fail("Projectile passed through a moved branch region")
	return await _check_hits(blocker, index + 1)


func _fail(message: String) -> bool:
	push_error("BRANCH COLLIDERS FAIL: " + message)
	return false
