extends SceneTree

const MATCH := preload("res://src/game/web_match.tscn")
const ROCKET := preload("res://src/features/collectibles/weapons/rocket_projectile.tscn")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var arena := MATCH.instantiate() as WebMatch3D
	root.add_child(arena)
	current_scene = arena
	await process_frame
	arena.process_mode = Node.PROCESS_MODE_DISABLED
	var spider := arena.get_node("TeamA").spiders[0] as PlayerSpider3D
	var rocket := ROCKET.instantiate() as Projectile3D
	arena.add_child(rocket)
	rocket.set_process(false)
	if not "network_replica" in rocket:
		_fail("Guest projectile must have a presentation-only mode")
		return
	rocket.set("network_replica", true)
	var health := spider.health
	var edges := arena.catch_webs[0].edges.duplicate()
	rocket.global_position = spider.global_position
	rocket.hit(spider.hurtbox)
	rocket.explode()
	rocket._explosion_hitbox_entered(spider.hurtbox)
	if spider.health != health or arena.catch_webs[0].edges != edges or rocket.freeze:
		_fail("Guest projectile callbacks changed gameplay")
		return
	rocket.free()
	var replication = load("res://src/features/multiplayer/projectile_replication.gd").new()
	arena.add_child(replication)
	replication.setup(arena, false, func() -> float: return 2.0)
	var launch := {"action": "launch", "id": 1, "type": 1,
		"position": [1_000_000, 1_000_000, 0], "velocity": [200_000, 400_000, 0],
		"rotation": [0, 0, 0], "time": 1.0}
	replication.receive(launch)
	replication.receive(launch)
	replication.present()
	var shots := get_nodes_in_group("camera_focus_projectiles")
	if shots.size() != 1 or shots[0].global_position.distance_to(Vector3(12, 9.095, 0)) > 0.001:
		_fail("Duplicate launch or frame-independent projectile flight failed")
		return
	var saved: Array = replication.capture()
	replication.restore(saved)
	replication.restore(saved)
	if get_nodes_in_group("camera_focus_projectiles").size() != 1:
		_fail("Recovery duplicated an airborne projectile")
		return
	replication.receive({ "action": "impact", "id": 1, "position": [300_000, 0, 0], "time": 2.0 })
	var shot := get_nodes_in_group("camera_focus_projectiles")[0] as Projectile3D
	if not shot.freeze or shot.global_position != Vector3(
		3,
		0,
		0,
	) or not shot.explosion_sprite.visible:
		_fail("Authoritative impact was not presented")
		return
	replication.receive({ "action": "remove", "id": 1 })
	replication.receive(launch)
	if not get_nodes_in_group("camera_focus_projectiles").is_empty():
		_fail("A removed projectile was resurrected by a stale launch")
		return
	current_scene = null
	arena.free()
	await process_frame
	await create_timer(0.2).timeout
	print("PROJECTILE REPLICATION PASS: guest authority, flight, impact and recovery")
	quit(0)


func _fail(message: String) -> void:
	push_error("PROJECTILE REPLICATION FAIL: " + message)
	quit(1)
