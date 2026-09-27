extends SceneTree
## Verify branch collision layers, spider movement, and swept pebble impacts.

const BRANCH_SCENE := preload(
	"res://src/features/world/maps/branch_canopy/branch_canopy.tscn"
)
const SPIDER_SCENE := preload("res://src/features/spiders/player_spider.tscn")
const PROJECTILE_SCENE := preload(
	"res://src/features/collectibles/weapons/pebble_projectile.tscn"
)


func _initialize() -> void:
	create_timer(10.0).timeout.connect(_on_timeout)
	call_deferred("_run")


func _run() -> void:
	var branch_scene := BRANCH_SCENE.instantiate()
	root.add_child(branch_scene)
	await process_frame
	var left_blocker := branch_scene.get_node_or_null("LeftBranchBlocker") as StaticBody3D
	var right_blocker := branch_scene.get_node_or_null("RightBranchBlocker") as StaticBody3D
	if not _check_visible_capsule(left_blocker) or not _check_visible_capsule(right_blocker):
		branch_scene.free()
		return
	if left_blocker.collision_layer != 2 or right_blocker.collision_layer != 2:
		branch_scene.free()
		_fail("Branch blockers must use the impassable branch collision layer")
		return
	if (ProjectSettings.get_setting("layer_names/3d_physics/layer_2") != "Impassable Branches"
			or ProjectSettings.get_setting("layer_names/3d_physics/layer_3") != "Walkable Web"):
		branch_scene.free()
		_fail("Impassable branches and walkable web need separate named layers")
		return
	var movement_ok: bool = await _check_spider_movement(right_blocker)
	if not movement_ok:
		return
	await process_frame
	var impact_ok: bool = await _check_projectile_branch_impact(right_blocker)
	if not impact_ok:
		return
	await process_frame
	if not await _check_projectile_spider_damage():
		return
	branch_scene.queue_free()
	await process_frame
	await process_frame
	await create_timer(0.2).timeout
	print("BRANCH COLLISION PASS: branch layers, movement blocking, and swept impacts")
	quit(0)


func _check_visible_capsule(blocker: StaticBody3D) -> bool:
	if blocker == null:
		return _fail("Both branches need named StaticBody3D blockers")
	var shape_node := blocker.get_node_or_null("CollisionShape3D") as CollisionShape3D
	var marker := blocker.get_node_or_null("VisualCapsule") as MeshInstance3D
	if shape_node == null or not shape_node.shape is CapsuleShape3D:
		return _fail("Each branch blocker needs a capsule collision shape")
	if marker == null or not marker.mesh is CapsuleMesh or not marker.visible:
		return _fail("Each branch blocker needs a visible 3D capsule")
	if shape_node.global_basis.y.normalized().dot(Vector3.UP) < 0.95:
		return _fail("Blocker capsules must extend toward the camera")
	var capsule := shape_node.shape as CapsuleShape3D
	if blocker.global_position.y - capsule.height * 0.5 > 0.1:
		return _fail("Branch capsules must reach the spider's gameplay plane")
	return true


func _check_spider_movement(map_blocker: StaticBody3D) -> bool:
	return (await _check_clear_spider_movement()
		and await _check_blocked_spider_movement()
		and await _check_map_branch_movement(map_blocker))


func _check_map_branch_movement(blocker: StaticBody3D) -> bool:
	var spider := SPIDER_SCENE.instantiate() as PlayerSpider3D
	root.add_child(spider)
	await physics_frame
	spider.global_position = Vector3(
		blocker.global_position.x - 4.0, 0.0, blocker.global_position.z
	)
	spider.is_active = true
	spider.remaining_movement = 10.0
	Input.action_press("move_right")
	await _wait_physics_frames(120)
	Input.action_release("move_right")
	var stopped := spider.global_position.x < blocker.global_position.x - 1.0
	spider.queue_free()
	if not stopped:
		return _fail("The visible map branch must block an approaching spider")
	return true


func _check_clear_spider_movement() -> bool:
	var clear_spider_node: Node = SPIDER_SCENE.instantiate()
	if not clear_spider_node is CharacterBody3D:
		clear_spider_node.free()
		return _fail("Player spiders must use a physics body")
	var clear_spider := clear_spider_node as PlayerSpider3D
	if clear_spider.collision_layer != 1 or clear_spider.collision_mask != 6:
		clear_spider.free()
		return _fail("Spiders must collide with branch and future web layers")
	root.add_child(clear_spider)
	await process_frame
	clear_spider.position = Vector3(-3.593088, 0, 0.62834454)
	clear_spider.is_active = true
	clear_spider.remaining_movement = 10.0
	var clear_start := clear_spider.global_position
	Input.action_press("move_right")
	await _wait_physics_frames(4)
	Input.action_release("move_right")
	var clear_distance := clear_spider.global_position.distance_to(clear_start)
	var clear_spent := 10.0 - clear_spider.remaining_movement
	clear_spider.queue_free()
	if clear_distance < 0.04:
		return _fail("A clear movement path must let the spider walk")
	if absf(clear_spent - clear_distance) > 0.01:
		return _fail("Clear movement must spend energy only on actual travel")
	return true


func _check_blocked_spider_movement() -> bool:
	var blocked_spider := SPIDER_SCENE.instantiate() as PlayerSpider3D
	root.add_child(blocked_spider)
	var wall := _make_branch_wall(Vector3(1.5, 0.5, 0), Vector3(0.2, 1.0, 4.0))
	root.add_child(wall)
	await physics_frame
	blocked_spider.position = Vector3(0, 0, 0)
	blocked_spider.is_active = true
	blocked_spider.remaining_movement = 10.0
	var blocked_start := blocked_spider.global_position
	Input.action_press("move_right")
	await _wait_physics_frames(60)
	Input.action_release("move_right")
	var blocked_distance := blocked_spider.global_position.distance_to(blocked_start)
	var blocked_spent := 10.0 - blocked_spider.remaining_movement
	var reached_wall := blocked_spider.position.x < 1.2
	blocked_spider.queue_free()
	wall.queue_free()
	if not reached_wall or blocked_distance >= 1.2:
		return _fail("An impassable branch must stop the spider")
	if absf(blocked_spent - blocked_distance) > 0.02:
		return _fail("A blocked step must spend energy only on actual travel")
	return true


func _check_projectile_branch_impact(branch: StaticBody3D) -> bool:
	var projectile := PROJECTILE_SCENE.instantiate() as PebbleProjectile3D
	if projectile.collision_layer != 8 or projectile.collision_mask != 3:
		projectile.free()
		return _fail("Pebbles must collide with spiders and branches only")
	projectile.position = branch.global_position + Vector3.LEFT * 7.0
	projectile.velocity = Vector3(1000, 0, 0)
	root.add_child(projectile)
	await _wait_physics_frames(2)
	var stopped_by_branch := not is_instance_valid(projectile)
	if is_instance_valid(projectile):
		projectile.queue_free()
	if not stopped_by_branch:
		return _fail("A fast pebble must stop at an impassable branch")
	return true


func _check_projectile_spider_damage() -> bool:
	var spider := SPIDER_SCENE.instantiate() as PlayerSpider3D
	spider.position = Vector3(2, 0, 5)
	root.add_child(spider)
	var projectile := PROJECTILE_SCENE.instantiate() as PebbleProjectile3D
	projectile.position = Vector3(-2, 0.25, 5)
	projectile.velocity = Vector3(1000, 0, 0)
	root.add_child(projectile)
	await _wait_physics_frames(2)
	var damaged_spider := spider.health < 1.0 and not is_instance_valid(projectile)
	if is_instance_valid(projectile):
		projectile.queue_free()
	spider.queue_free()
	if not damaged_spider:
		return _fail("A swept pebble impact must retain spider damage")
	return true


func _make_branch_wall(wall_position: Vector3, box_size: Vector3) -> StaticBody3D:
	var wall := StaticBody3D.new()
	wall.name = "ImpassableBranchTestWall"
	wall.position = wall_position
	wall.collision_layer = 2
	wall.collision_mask = 0
	var shape := BoxShape3D.new()
	shape.size = box_size
	var shape_node := CollisionShape3D.new()
	shape_node.shape = shape
	wall.add_child(shape_node)
	return wall


func _wait_physics_frames(frame_count: int) -> void:
	var duration := float(frame_count) / float(Engine.physics_ticks_per_second)
	await create_timer(duration, true, true).timeout


func _on_timeout() -> void:
	push_error("BRANCH COLLISION TIMEOUT")
	quit(2)


func _fail(message: String) -> bool:
	push_error("BRANCH COLLISION FAIL: " + message)
	quit(1)
	return false
