extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var arena = load("res://src/game/web_match.tscn").instantiate()
	root.add_child(arena)
	current_scene = arena
	await process_frame
	arena.process_mode = Node.PROCESS_MODE_DISABLED
	var spider: PlayerSpider3D = arena.get_node("TeamA").spiders[0]
	if not spider.has_method("simulate"):
		_fail("Spider has no shared command simulation")
		return
	var web: Web3D = arena.catch_webs[0]
	var face: Array = web.find_faces()[0]
	var center := Vector3.ZERO
	for index in face:
		center += web.valid_nodes[index].global_position
	spider.global_position = center / 3.0
	spider.is_active = true
	spider.n_remaining_actions = 1
	spider.remaining_movement = 0.01
	var start := spider.global_position
	var command = load("res://src/features/multiplayer/player_command.gd").new()
	command.held = 4
	spider.call("simulate", 0.1, command)
	if not spider.global_position.is_equal_approx(start + Vector3.UP * 0.01) \
			or not is_zero_approx(spider.remaining_movement):
		_fail("Scripted movement must respect the XY plane and movement budget")
		return
	spider.is_active = false
	spider.remaining_movement = 1.0
	start = spider.global_position
	spider.call("simulate", 0.1, command)
	if not spider.global_position.is_equal_approx(start):
		_fail("An inactive spider accepted movement")
		return
	spider.is_active = true
	command.held = 16
	spider.call("simulate", 0.1, command)
	if not is_equal_approx(spider.aim_angle, 0.3):
		_fail("Scripted aiming must use the same speed as keyboard input")
		return
	command.held = 0
	command.action_released = true
	spider.select_weapon(0)
	command.cancel = true
	spider.call("simulate", 0.0, command)
	if spider.n_remaining_actions != 1:
		_fail("Cancelling a held action must not fire or spend it")
		return
	command.cancel = false
	spider.call("simulate", 0.0, command)
	spider.call("simulate", 0.0, command)
	if spider.n_remaining_actions != 0:
		_fail("Repeated releases must not spend actions below zero")
		return
	arena.queue_free()
	await process_frame
	await create_timer(0.2).timeout
	print("PLAYER SIMULATION PASS: scripted movement, aiming, inactivity and action budget")
	quit(0)


func _fail(reason: String) -> void:
	push_error("PLAYER SIMULATION FAIL: " + reason)
	quit(1)
