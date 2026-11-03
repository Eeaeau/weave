extends SceneTree
# gdstyle:ignore-file=quality/await-in-loop

var _surfaces: Array[PackedVector3Array] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var arena: WebMatch3D = load("res://src/game/web_match.tscn").instantiate()
	root.add_child(arena)
	current_scene = arena
	await process_frame
	arena.process_mode = Node.PROCESS_MODE_DISABLED
	var player: PlayerSpider3D = arena.get_node("TeamA").spiders[0]
	player.global_position = Vector3.ZERO
	var animation: AnimationPlayer = player.get_node("SpiderRig/AnimationPlayer")
	animation.play("eye_idle")
	animation.seek(0.0, true)
	var gait: SpiderLegController3D = player.get_node("SpiderRig/LegController")
	gait.targeting_mode = SpiderLegController3D.TargetingMode.FREE_STEP_DEBUG
	var strokes: SpiderLegStroke3D = player.get_node("SpiderRig/LegStrokes")
	var skeleton: Skeleton3D = player.get_node("SpiderRig/ImportedRig/RIG_spider/Skeleton3D")
	skeleton.process_mode = Node.PROCESS_MODE_ALWAYS
	strokes.pose_drawn.connect(func(): _capture(strokes))
	var passed := true
	for armed in [false, true]:
		if armed:
			var weapon: Weapon3D = load(
				"res://src/features/collectibles/weapons/weapon_rocket_launcher.tscn").instantiate()
			player.add_child(weapon)
			player.pick_up(weapon)
			await process_frame
			player.select_weapon(2)
		for warmup in range(60):
			player.update_presentation()
			gait.advance(1.0 / 60.0)
			await strokes.pose_drawn
		var previous := _surfaces.duplicate(true)
		for tick in range(360):
			var angle := tick * 0.025 if tick < 240 else (PI / 2.0 if tick % 8 < 4 else -PI / 2.0)
			player.face_direction(angle)
			animation.advance(1.0 / 60.0)
			player.advance_visual_facing(1.0 / 60.0)
			player.update_presentation()
			gait.advance(1.0 / 60.0)
			await strokes.pose_drawn
			if not _stable(previous, player.global_basis.y.normalized()):
				passed = false
				break
			if not _walking_depth(player, gait, strokes):
				passed = false
				break
			previous = _surfaces.duplicate(true)
		if not passed:
			break
	if passed:
		passed = await _check_web_contact(arena, player, gait, skeleton, strokes)
	await process_frame
	arena.queue_free()
	await process_frame
	await create_timer(0.2).timeout
	if not passed:
		quit(1)
		return
	print("SPIDER POSE STABILITY PASS: posed legs turn continuously with and without a launcher")
	quit(0)


func _capture(strokes: SpiderLegStroke3D) -> void:
	_surfaces.clear()
	for surface in range(strokes.mesh.get_surface_count()):
		var arrays := strokes.mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for index in range(vertices.size()):
			vertices[index] = strokes.to_global(vertices[index])
		_surfaces.append(vertices)


func _stable(previous: Array[PackedVector3Array], normal: Vector3) -> bool:
	for surface in range(_surfaces.size()):
		for index in range(_surfaces[surface].size()):
			var movement := _surfaces[surface][index] - previous[surface][index]
			movement -= normal * movement.dot(normal)
			if movement.length() > 0.22:
				push_error("SPIDER POSE STABILITY FAIL: a drawn leg flipped during a slow turn")
				return false
	return true


func _walking_depth(player: PlayerSpider3D, gait: SpiderLegController3D,
		strokes: SpiderLegStroke3D) -> bool:
	var normal := player.global_basis.y.normalized()
	var body_depth := player.body.global_position.dot(normal)
	for surface in range(_surfaces.size()):
		var foot: int = gait.FOOT_NAMES.find(strokes.LEG_SPECS[surface][3])
		if gait.is_carried(foot):
			continue
		for vertex in _surfaces[surface]:
			if vertex.dot(normal) >= body_depth - 0.005:
				push_error("SPIDER POSE STABILITY FAIL: a walking leg draws over the body/eyes")
				return false
	return true


func _check_web_contact(arena: WebMatch3D, player: PlayerSpider3D,
		gait: SpiderLegController3D, skeleton: Skeleton3D, strokes: SpiderLegStroke3D) -> bool:
	player.select_weapon(0)
	var web: Web3D = arena.catch_webs[0]
	gait.targeting_mode = SpiderLegController3D.TargetingMode.WEB
	gait.support_web = web
	var origin := Vector3.ZERO
	for vertex in web.find_faces()[0]:
		origin += web.valid_nodes[vertex].global_position / 3.0
	for tick in range(540):
		if tick < 360:
			var phase := float(tick) / 60.0
			player.global_position = origin + Vector3(sin(phase), cos(phase), 0.0) * 0.7
			player.face_direction(phase)
		player.advance_visual_facing(1.0 / 60.0)
		player.update_presentation()
		gait.advance(1.0 / 60.0)
		await strokes.pose_drawn
	for foot in [6, 7]:
		for surface in range(strokes.LEG_SPECS.size()):
			if strokes.LEG_SPECS[surface][3] != gait.FOOT_NAMES[foot]:
				continue
			var vertices := _surfaces[surface]
			var tip := (vertices[-1] + vertices[-2]) * 0.5
			var target: Node3D = gait.get_parent().get_node("FootTargets/" + gait.FOOT_NAMES[foot])
			if tip.distance_to(target.global_position) > 0.03 or not gait.has_web_support(tip):
				push_error("SPIDER POSE STABILITY FAIL: a rear toe cannot reach its web strand")
				return false
	return true
