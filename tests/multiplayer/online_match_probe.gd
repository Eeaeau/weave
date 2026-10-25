# Scripted peers wait for engine frames and play turns sequentially.
# gdstyle:ignore-file=quality/await-in-loop
extends Node

const COMMAND := preload("res://src/features/multiplayer/player_command.gd")

var _role := ""
var _code := ""
var _ready_requested := false
var _ready_revision := -1
var _announced := false
var _done := false
var _menu: MainMenu
var _scenario := "load"
var _testing_turns := false
var _rejected_command := false
var _damage_events := 0
var _interactive := false


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--role="):
			_role = argument.trim_prefix("--role=")
		elif argument.begins_with("--code="):
			_code = argument.trim_prefix("--code=")
		elif argument.begins_with("--scenario="):
			_scenario = argument.trim_prefix("--scenario=")
		elif argument == "--interactive":
			_interactive = true
	get_tree().create_timer(120.0 if _interactive else 35.0).timeout.connect(
		func() -> void: _fail("Match load timed out"))
	get_tree().scene_changed.connect(_configure_match)
	call_deferred("_open_menu")


func _process(_delta: float) -> void:
	if _done or _testing_turns or OnlineSession.state != "playing":
		return
	_check_loaded_match()


func _configure_match() -> void:
	if _role != "host" or _scenario not in ["combat", "silk"]:
		return
	var arena := get_tree().current_scene as WebMatch3D
	if arena == null:
		return
	var shooter: PlayerSpider3D = arena.get_node("TeamA").spiders[0]
	if _scenario == "silk":
		var web := arena.get_node("TeamA").home_web as Web3D
		web.edges = [Vector2i(0, 1)]
		for spider in arena.get_node("TeamA").spiders:
			spider.webs.clear()
		shooter.webs.append(web)
		shooter.global_position = web.valid_nodes[0].global_position
		return
	var target: PlayerSpider3D = arena.get_node("TeamB").spiders[0]
	shooter.webs.clear()
	target.webs.clear()
	shooter.global_position = Vector3(0, 50, 0)
	target.global_position = Vector3(10, 50, 0)
	var codec = load("res://src/features/multiplayer/match_state.gd").new()
	var weapon := codec.create_item(3) as Weapon3D
	arena.add_child(weapon)
	shooter.pick_up(weapon)
	target.hurtbox.hurt.connect(func(_amount: float) -> void: _damage_events += 1)


func _check_loaded_match() -> void:
	var arena := get_tree().current_scene as WebMatch3D
	if arena == null:
		_fail("Online start did not load the production match")
		return
	var driver := arena.get_node_or_null("MatchReplication")
	if driver == null or not driver.get("initial_state_confirmed"):
		_fail("Controls activated before the initial state acknowledgement")
		return
	if arena.wind_event.group_size != OnlineSession.match_config.settings.drops:
		_fail("The selected drop count did not reach the match")
		return
	if not arena.get_node("MatchManager").waiting_for_wind:
		return
	if _role == "guest" and not arena.wind_event.is_active:
		_fail("The guest has no visual wind group during the wind event")
		return
	for team in arena.get_node("MatchManager").teams:
		for spider in team.spiders:
			if spider.is_active or not is_equal_approx(spider.health, 1.0):
				_fail("Spiders acted or died before the initial wind finished")
				return
	if _scenario in ["turns", "combat", "silk"]:
		_testing_turns = true
		if _scenario == "combat":
			_play_combat.call_deferred(arena, driver)
		elif _scenario == "silk":
			_play_silk.call_deferred(arena, driver)
		else:
			_play_turns.call_deferred(arena, driver)
	else:
		_pass()


func _play_silk(arena: WebMatch3D, driver: Node) -> void:
	driver.scripted_input = true
	var spider: PlayerSpider3D = arena.get_node("TeamA").spiders[0]
	var web := arena.get_node("TeamA").home_web as Web3D
	if _role == "guest":
		var skip := COMMAND.new()
		skip.held = 128
		driver.submit_command(skip)
	if not await _wait_until(_wind_finished.bind(arena)):
		return
	if _role == "host":
		var selection := COMMAND.new()
		selection.selection = 1
		driver.submit_command(selection)
	if not await _wait_until(_silk_options_ready.bind(spider)):
		return
	if _role == "host":
		var cycle := COMMAND.new()
		cycle.cycle = 1
		driver.submit_command(cycle)
	if not await _wait_until(_silk_cycled.bind(spider)):
		return
	spider.update_presentation()
	if spider.silk_builder.target_markers.size() < 2:
		_fail("Silk options are not visible on both clients")
		return
	var target_index: int = spider.silk_builder.silk_target_indices[1]
	if _role == "host":
		await get_tree().create_timer(0.2).timeout
		var press := COMMAND.new()
		press.held = 64
		driver.submit_command(press)
		await get_tree().create_timer(0.05).timeout
		driver.submit_command(COMMAND.new())
	await _verify_silk(driver, spider, web, target_index)


func _verify_silk(driver: Node, spider: PlayerSpider3D, web: Web3D, target: int) -> void:
	if not await _wait_until(_edge_built.bind(web, target)):
		return
	if spider.silk_amount != 2 or spider.n_remaining_actions != 0 or spider.health != 1.0:
		_fail("Silk build did not replicate its cost or preserve its spider")
		return
	if _role == "host" and not await _wait_until(_outcomes_acknowledged.bind(driver)):
		return
	_pass()


func _edge_built(web: Web3D, target: int) -> bool:
	return web.edges.has(Vector2i(0, target)) or web.edges.has(Vector2i(target, 0))


func _silk_options_ready(spider: PlayerSpider3D) -> bool:
	return spider.selected_weapon_idx == 1 and spider.silk_builder.silk_target_indices.size() >= 2


func _silk_cycled(spider: PlayerSpider3D) -> bool:
	return spider.silk_builder.selected_silk_target_index == 1


func _play_combat(arena: WebMatch3D, driver: Node) -> void:
	driver.scripted_input = true
	var target: PlayerSpider3D = arena.get_node("TeamB").spiders[0]
	if _role == "guest":
		var skip = COMMAND.new()
		skip.held = 128
		driver.submit_command(skip)
		if not await _wait_until(_has_projectile):
			return
		var replica := get_tree().get_nodes_in_group("camera_focus_projectiles")[0] as Projectile3D
		var health := target.health
		replica.hit(target.hurtbox)
		if not replica.network_replica or target.health != health:
			_fail("Guest projectile applied damage independently")
			return
	if _role == "host" and not await _fire_rocket(arena, driver, target):
		return
	await _verify_combat(driver, target)


func _fire_rocket(arena: WebMatch3D, driver: Node, target: PlayerSpider3D) -> bool:
	if not await _wait_until(_wind_finished.bind(arena)):
		return false
	var selection = COMMAND.new()
	selection.selection = 2
	driver.submit_command(selection)
	if not await _wait_until(_rocket_selected.bind(arena)):
		return false
	var press = COMMAND.new()
	press.held = 64
	driver.submit_command(press)
	await get_tree().create_timer(0.12).timeout
	driver.submit_command(COMMAND.new())
	if not await _wait_until(_has_projectile):
		return false
	var projectile := get_tree().get_nodes_in_group("camera_focus_projectiles")[0] as Projectile3D
	projectile.damage = 0.25
	projectile.explosion_damage = 0.0
	await get_tree().create_timer(0.35).timeout
	target.global_position = projectile.global_position + projectile.velocity * 0.03
	if not await _wait_until(_shot_frozen.bind(projectile)):
		return false
	projectile.hit(target.hurtbox)
	if not is_equal_approx(target.health, 0.75) or _damage_events != 1:
		_fail("Host collision did not apply direct damage exactly once")
		return false
	return true


func _verify_combat(driver: Node, target: PlayerSpider3D) -> void:
	if not await _wait_until(_no_projectile):
		return
	if not await _wait_until(_health_matches.bind(target, 0.75)):
		return
	if _role == "host" and not await _wait_until(_outcomes_acknowledged.bind(driver)):
		return
	var transport := OnlineSession.transport
	var counts: Dictionary = transport.sent_messages
	if _role == "guest":
		counts = transport.received_messages
	if counts.get("projectile", 0) != 3:
		_fail("A shot must send only launch, impact and removal")
		return
	_pass()


func _has_projectile() -> bool:
	return not get_tree().get_nodes_in_group("camera_focus_projectiles").is_empty()


func _no_projectile() -> bool:
	return not _has_projectile()


func _shot_frozen(projectile: Projectile3D) -> bool:
	return is_instance_valid(projectile) and projectile.freeze


func _health_matches(target: PlayerSpider3D, expected: float) -> bool:
	return is_equal_approx(target.health, expected)


func _wind_finished(arena: WebMatch3D) -> bool:
	return not arena.get_node("MatchManager").waiting_for_wind


func _rocket_selected(arena: WebMatch3D) -> bool:
	return arena.get_node("TeamA").spiders[0].selected_weapon_idx == 2


func _play_turns(arena: WebMatch3D, driver: Node) -> void:
	if not driver.has_method("submit_command"):
		_fail("Match has no shared online command path")
		return
	driver.scripted_input = true
	driver.command_result.connect(func(result: Dictionary) -> void:
		if not result.accepted:
			_rejected_command = true)
	var command_script = COMMAND
	if _role == "guest":
		var skip = command_script.new()
		skip.held = 128
		driver.submit_command(skip)
	var manager: MatchManager = arena.get_node("MatchManager")
	if not await _wait_until(func() -> bool: return not manager.waiting_for_wind):
		return
	if _role == "guest":
		var forged = command_script.new()
		forged.held = 4
		var packet: Dictionary = forged.to_packet(OnlineSession.match_config.match,
			driver.turn_id, 99, driver.active_actor_id)
		OnlineSession.transport.send_to(OnlineSession.host_id, "command", packet)
		if not await _wait_until(func() -> bool: return _rejected_command):
			return
	await _take_team_turns(arena, driver, manager, command_script)
	if _done:
		return
	if _role == "host" and not await _wait_until(_outcomes_acknowledged.bind(driver)):
		return
	_pass()


func _take_team_turns(arena: WebMatch3D, driver: Node, manager: MatchManager,
		command_script: GDScript) -> void:
	var moved := false
	var press = command_script.new()
	press.held = 64
	var release = command_script.new()
	while manager._round_number < 2 and not _done:
		if driver.active_owner_id != GDSync.get_client_id() or manager.waiting_for_wind:
			await get_tree().process_frame
			continue
		var actor_id: int = driver.active_actor_id
		var spider := manager.teams[manager.active_team_idx].get_active_spider()
		if _role == "host" and not moved:
			if not await _move_spider(driver, spider, command_script):
				return
			moved = true
		driver.submit_command(press)
		await get_tree().create_timer(0.08).timeout
		driver.submit_command(release)
		if not await _wait_until(_turn_changed.bind(driver, manager, actor_id)):
			return
	for team in manager.teams:
		for spider in team.spiders:
			if not is_equal_approx(spider.health, 1.0):
				_fail("A pass action or turn transition killed a spider")
				return
	if _role == "guest" and not _rejected_command:
		_fail("Host did not reject another team's movement command")


func _turn_changed(driver: Node, manager: MatchManager, actor_id: int) -> bool:
	return driver.active_actor_id != actor_id or manager.waiting_for_wind


func _outcomes_acknowledged(driver: Node) -> bool:
	return driver.acknowledged_revision >= driver.last_digest_revision


func _move_spider(driver: Node, spider: PlayerSpider3D, command_script: GDScript) -> bool:
	var start := spider.global_position
	var budget := spider.remaining_movement
	var move = command_script.new()
	for held in [1, 2, 4, 8]:
		move.held = held
		var point: Vector3 = start + move.movement_direction() * 0.4
		if spider.is_on_web(Vector2(point.x, point.y)):
			break
	driver.submit_command(move)
	await get_tree().create_timer(0.2).timeout
	driver.submit_command(command_script.new())
	await get_tree().create_timer(0.1).timeout
	if spider.global_position.distance_to(start) < 0.05 or spider.remaining_movement >= budget:
		_fail("Host movement was not applied through online player commands")
		return false
	return true


func _wait_until(predicate: Callable) -> bool:
	var deadline := Time.get_ticks_msec() + (60_000 if _interactive else 12_000)
	while not _done and not predicate.call():
		if Time.get_ticks_msec() > deadline:
			_fail("Timed out waiting for an acknowledged gameplay transition")
			return false
		await get_tree().process_frame
	return not _done


func _pass() -> void:
	_done = true
	print("ONLINE_MATCH_PASS: ", _role)
	_finish.call_deferred()


func _open_menu() -> void:
	_menu = load("res://src/features/ui/main_menu.tscn").instantiate()
	get_tree().root.add_child(_menu)
	get_tree().current_scene = _menu
	_menu.get_node("Center/Menu/PlayButton").pressed.emit()
	_menu.get_node("PlayMenu/OnlineButton").pressed.emit()
	OnlineSession.changed.connect(_observe_lobby)
	if _role == "host":
		OnlineSession.host_lobby()
	else:
		OnlineSession.join_lobby(_code)


func _observe_lobby() -> void:
	if _done:
		return
	if OnlineSession.state == "error":
		_fail(OnlineSession.message)
		return
	if OnlineSession.state != "in_lobby":
		return
	if _role == "host" and not _announced and OnlineSession.host_id >= 0:
		_announced = true
		if _scenario == "turns":
			OnlineSession.set_match_settings(5)
		print("ONLINE_LOBBY_READY: ", OnlineSession.code)
	if (OnlineSession.players.size() == 2
			and OnlineSession.host_id >= 0
			and (not _ready_requested or _ready_revision != OnlineSession.match_settings.revision)):
		_ready_requested = true
		_ready_revision = OnlineSession.match_settings.revision
		OnlineSession.set_ready(true)


func _finish() -> void:
	await get_tree().create_timer(0.5).timeout
	OnlineSession.leave_lobby()
	var arena := get_tree().current_scene
	get_tree().current_scene = null
	arena.queue_free()
	await get_tree().process_frame
	await get_tree().create_timer(0.2).timeout
	get_tree().quit(0)


func _fail(reason: String) -> void:
	if _done:
		return
	_done = true
	push_error("ONLINE_MATCH_FAIL: " + reason)
	OnlineSession.leave_lobby()
	get_tree().quit.call_deferred(1)
