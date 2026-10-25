# Scripted peers wait for engine frames and play turns sequentially.
# gdstyle:ignore-file=quality/await-in-loop
extends Node

var _role := ""
var _code := ""
var _ready_requested := false
var _start_requested := false
var _announced := false
var _done := false
var _menu: MainMenu
var _scenario := "load"
var _testing_turns := false
var _rejected_command := false


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--role="):
			_role = argument.trim_prefix("--role=")
		elif argument.begins_with("--code="):
			_code = argument.trim_prefix("--code=")
		elif argument.begins_with("--scenario="):
			_scenario = argument.trim_prefix("--scenario=")
	get_tree().create_timer(35.0).timeout.connect(func() -> void: _fail("Match load timed out"))
	call_deferred("_open_menu")


func _process(_delta: float) -> void:
	if _done or _testing_turns or OnlineSession.state != "playing":
		return
	_check_loaded_match()


func _check_loaded_match() -> void:
	var arena := get_tree().current_scene as WebMatch3D
	if arena == null:
		_fail("Online start did not load the production match")
		return
	var driver := arena.get_node_or_null("MatchReplication")
	if driver == null or not driver.get("initial_state_confirmed"):
		_fail("Controls activated before the initial state acknowledgement")
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
	if _scenario == "turns":
		_testing_turns = true
		_play_turns.call_deferred(arena, driver)
	else:
		_pass()


func _play_turns(arena: WebMatch3D, driver: Node) -> void:
	if not driver.has_method("submit_command"):
		_fail("Match has no shared online command path")
		return
	driver.scripted_input = true
	driver.command_result.connect(func(result: Dictionary) -> void:
		if not result.accepted:
			_rejected_command = true)
	var command_script = load("res://src/features/multiplayer/player_command.gd")
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
	var deadline := Time.get_ticks_msec() + 12_000
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
	if _role == "host" and not _announced:
		_announced = true
		print("ONLINE_LOBBY_READY: ", OnlineSession.code)
	if OnlineSession.players.size() == 2 and OnlineSession.host_id >= 0 and not _ready_requested:
		_ready_requested = true
		OnlineSession.set_ready(true)
	if _role == "host" and OnlineSession.can_start() and not _start_requested:
		var start := _menu.get_node_or_null("OnlineLobby/Center/Menu/StartButton") as Button
		if start == null:
			_fail("Online lobby has no Start action")
		else:
			_start_requested = true
			start.pressed.emit.call_deferred()


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
