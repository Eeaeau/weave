extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var codec_path := "res://src/features/multiplayer/match_state.gd"
	var codec = load(codec_path).new()
	var arena: WebMatch3D = load("res://src/game/web_match.tscn").instantiate()
	root.add_child(arena)
	current_scene = arena
	await process_frame
	arena.process_mode = Node.PROCESS_MODE_DISABLED
	var before: Dictionary = codec.capture(arena)
	var digest: String = codec.digest(before)
	var spider: PlayerSpider3D = arena.get_node("TeamA").spiders[0]
	spider.health = 0.25
	spider.silk_amount = 0
	spider.remaining_movement = 1.25
	spider.global_position += Vector3.UP * 0.5
	var weapon: Weapon3D = load(
		"res://src/features/collectibles/weapons/weapon_rocket_launcher.tscn").instantiate()
	spider.add_child(weapon)
	spider.pick_up(weapon)
	spider.select_weapon(2)
	var web: Web3D = arena.catch_webs[0]
	web.edges = []
	if codec.digest(codec.capture(arena)) == digest:
		_fail("Digest ignored changed health, position, inventory or topology")
		return
	if not codec.apply(arena, before) or codec.digest(codec.capture(arena)) != digest:
		_fail("Recovery did not restore the actual match state")
		return
	var changed: Dictionary = before.duplicate(true)
	changed.actors["0:0"].health = 50_000
	changed.actors["0:0"].silk = 4
	changed.actors["0:0"].inventory.append(3)
	changed.actors["0:0"].selected = 2
	if not codec.apply(
		arena,
		changed,
	) or codec.digest(codec.capture(arena)) != codec.digest(changed):
		_fail("Authoritative inventory and resource changes did not reach the game objects")
		return
	var patch: Dictionary = codec.diff(before, changed)
	if patch.size() != 1 or not patch.has("actors") or patch.actors.size() != 1:
		_fail("A changed actor sent unrelated actors or unchanged match state")
		return
	var merged: Dictionary = codec.merge(before, patch)
	if codec.digest(merged) != codec.digest(changed):
		_fail("Sparse updates did not reproduce the authoritative state")
		return
	if not _check_collectible_recovery(codec, arena, web, spider, changed):
		return
	arena.queue_free()
	await process_frame
	await create_timer(0.2).timeout
	print("MATCH STATE PASS: real actor, inventory and web recovery with sparse updates")
	quit(0)


func _check_collectible_recovery(codec: RefCounted, arena: WebMatch3D, web: Web3D,
		spider: PlayerSpider3D, changed: Dictionary) -> bool:
	changed.caught["17"] = {"web": 0, "face": web.find_catch_face(_face_center(web)),
		"type": 4, "position": codec.pack_vector(spider.global_position)}
	if not codec.apply(
		arena,
		changed,
	) or codec.digest(codec.capture(arena)) != codec.digest(changed):
		_fail("Recovery did not restore a caught insect")
		return false
	var caught := web.get_node("CaughtItems").get_child(0) as CaughtCollectible3D
	caught.global_position += Vector3.RIGHT
	if not codec.apply(
		arena,
		changed,
	) or codec.digest(codec.capture(arena)) != codec.digest(changed) \
			or web.get_node("CaughtItems").get_child_count() != 1:
		_fail("Repeated recovery duplicated a collectible or preserved a displaced collectible")
		return false
	for type_id in [-1, 4, 5, 6, 100]:
		var invalid: Dictionary = changed.duplicate(true)
		invalid.actors["0:0"].inventory = [0, 1, type_id]
		if codec.apply(
			arena,
			invalid,
		) or codec.digest(codec.capture(arena)) != codec.digest(changed):
			_fail("An invalid inventory changed the match before validation completed")
			return false
	changed.caught.clear()
	if not codec.apply(
		arena,
		changed,
	) or codec.digest(codec.capture(arena)) != codec.digest(changed):
		_fail("Explicit collectible removal did not reach the game objects")
		return false
	return true


func _face_center(web: Web3D) -> Vector3:
	var center := Vector3.ZERO
	for index in web.find_faces()[0]:
		center += web.valid_nodes[index].global_position
	return center / 3.0


func _fail(reason: String) -> void:
	push_error("MATCH STATE FAIL: " + reason)
	quit(1)
