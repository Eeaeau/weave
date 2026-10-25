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
	if not _check_release_timing(spider, command.get_script()):
		return
	arena.queue_free()
	await process_frame
	await create_timer(0.2).timeout
	print("PLAYER SIMULATION PASS: scripted movement, aiming, inactivity and action budget")
	quit(0)


func _check_release_timing(spider: PlayerSpider3D, command_script: GDScript) -> bool:
	var expected := Vector3(4.0 * cos(0.6), 4.0 * sin(0.6) + 2.0, 0) \
		* (0.2 + sin(2.0) + 1.0) * 1.5
	var release = command_script.new()
	release.final_aim = 0.6
	release.final_charge = 1.0
	for observed_charge in [0.9, 1.1]:
		var weapon: Weapon3D = load(
			"res://src/features/collectibles/weapons/weapon_rocket_launcher.tscn").instantiate()
		spider.add_child(weapon)
		spider.pick_up(weapon)
		spider.select_weapon(spider.weapons.size() - 1)
		spider.n_remaining_actions = 1
		spider.aim_angle = observed_charge - 0.4
		spider.action_charged_time = observed_charge
		var received = command_script.from_packet(release.to_packet("match", 1, 2, 0), 64)
		spider.simulate(0.0, received)
		var shots := get_nodes_in_group("camera_focus_projectiles")
		if shots.size() != 1 or shots[0].velocity.distance_to(expected) > 0.001:
			_fail("Guest release power or aim changed with packet arrival jitter")
			return false
		shots[0].free()
	return true


func _fail(reason: String) -> void:
	push_error("PLAYER SIMULATION FAIL: " + reason)
	quit(1)
