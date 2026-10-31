extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var arena: WebMatch3D = load("res://src/game/web_match.tscn").instantiate()
	root.add_child(arena)
	current_scene = arena
	await process_frame
	arena.process_mode = Node.PROCESS_MODE_DISABLED
	var spider: PlayerSpider3D = arena.get_node("TeamA").spiders[0]
	var web: Web3D = arena.catch_webs[0]
	var point := Vector3.ZERO
	var face: Array = web.find_faces()[0]
	for vertex in face:
		point += web.valid_nodes[vertex].global_position
	spider.global_position = point / 3.0
	spider.is_active = true
	spider.remaining_movement = 10.0
	spider.n_remaining_actions = 1
	var command := PlayerCommand.new()
	command.held = 2
	var before := spider.global_position
	var facing := spider.spider_rig.rotation.y
	spider.simulate(1.0 / 60.0, command)
	var immediate := spider.global_position.is_equal_approx(before + Vector3.RIGHT / 30.0)
	if not immediate or absf(angle_difference(facing, spider.spider_rig.rotation.y)) > 0.1:
		_fail("Movement was delayed" if not immediate else "Visual rig snapped on input")
		return
	for tick in range(30):
		command.held = 1 if tick % 4 < 2 else 2
		before = spider.global_position
		facing = spider.spider_rig.rotation.y
		spider.simulate(1.0 / 60.0, command)
		spider.advance_visual_facing(1.0 / 60.0)
		spider.get_node("SpiderRig/LegController").advance(1.0 / 60.0)
		var direction := Vector3.LEFT if command.held == 1 else Vector3.RIGHT
		if not spider.global_position.is_equal_approx(before + direction / 30.0):
			_fail("Rapid reversals delayed movement")
			return
		if absf(angle_difference(facing, spider.spider_rig.rotation.y)) > 0.051:
			_fail("Rapid reversals exceeded the visual turn speed")
			return
	spider.face_direction(PI - 0.01)
	for tick in range(120):
		spider.advance_visual_facing(1.0 / 60.0)
		spider.get_node("SpiderRig/LegController").advance(1.0 / 60.0)
	facing = spider.spider_rig.rotation.y
	if absf(angle_difference(facing, PI - 0.01)) > 0.001:
		_fail("The rig did not catch up after movement stopped")
		return
	spider.face_direction(-PI + 0.01)
	spider.advance_visual_facing(1.0 / 60.0)
	var short_turn := absf(angle_difference(facing, spider.spider_rig.rotation.y)) <= 0.025
	arena.queue_free()
	await process_frame
	await create_timer(0.2).timeout
	if not short_turn:
		_fail("Turning across the angle boundary took the long route")
		return
	if not _check_free_step_reversals():
		return
	print("SPIDER TURNING PASS: responsive reversals, gradual visual turn and settle")
	quit(0)


func _fail(reason: String) -> void:
	push_error("SPIDER TURNING FAIL: " + reason)
	quit(1)


func _check_free_step_reversals() -> bool:
	var spider: BaseSpider3D = load("res://src/features/spiders/base_spider.tscn").instantiate()
	root.add_child(spider)
	var gait: SpiderLegController3D = spider.get_node("SpiderRig/LegController")
	gait.targeting_mode = SpiderLegController3D.TargetingMode.FREE_STEP_DEBUG
	gait.set_process(false)
	var feet := spider.get_node("SpiderRig/FootTargets").get_children()
	var stable := true
	var first_jump := ""
	for tick in range(120):
		var direction := 1.0 if tick % 8 < 4 else -1.0
		var before: Array[Vector3] = []
		for foot in feet:
			before.append(foot.global_position)
		spider.position.x += direction / 30.0
		spider.face_direction(direction * PI / 2.0)
		spider.advance_visual_facing(1.0 / 60.0)
		gait.advance(1.0 / 60.0)
		for index in range(feet.size()):
			if feet[index].global_position.distance_to(before[index]) > 0.15:
				if first_jump.is_empty():
					first_jump = "%s tick %s: %s -> %s" % [
						feet[index].name, tick, before[index], feet[index].global_position]
				stable = false
	spider.free()
	if not stable:
		_fail("Rapid reversals teleported a leg target: " + first_jump)
	return stable
