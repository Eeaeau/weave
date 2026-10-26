extends Node

signal command_result(result: Dictionary)

const STATE := preload("res://src/features/multiplayer/match_state.gd")
const COMMAND := preload("res://src/features/multiplayer/player_command.gd")

var initial_state_confirmed := false
var revision := 0
var acknowledged_revision := -1
var last_digest_revision := 0
var turn_id := 0
var active_actor_id := -1
var active_owner_id := -1
var scripted_input := false
var _authority := preload("res://src/features/multiplayer/command_authority.gd").new()
var _turn_key := ""
var _sequence := 0
var _last_held := -1
var _local_actor := -1
var _local_aim := 0.0
var _local_charge := 0.0
var _blocked_held := 0
var _input_cooldown := 0.0
var _pause_menu: CanvasLayer
var _motions: Dictionary = {}
var _motion_changes: Dictionary = {}
var _needs_digest := true
var _recovery_times: Dictionary = {}
var _recovering := false
var _last_recovery_request := -2000
var _wind_description: Dictionary = {}
var _wind_contacts: Dictionary = {}
var _arena: WebMatch3D
var _manager: MatchManager
var _codec := STATE.new()
var _scene_ready: Dictionary = {}
var _snapshot_acks: Dictionary = {}
var _state: Dictionary = {}
var _digests: Dictionary = {}
var _match_id := ""
var _slots: Array = []
var _host := false
var _projectiles: Node


func _process(delta: float) -> void:
	if OnlineSession.state != "playing" or not is_instance_valid(_arena):
		return
	if not _host:
		if _recovering:
			_request_recovery()
		if _manager.finished:
			return
		_projectiles.present()
		if _arena.wind_event.is_active and not _wind_description.is_empty():
			var elapsed := maxf(0.0, GDSync.get_multiplayer_time() - float(_wind_description.time))
			_arena.wind_event.advance(maxf(0.0, elapsed - _arena.wind_event._elapsed))
		_present_motion()
		for team in _manager.teams:
			for spider in team.spiders:
				spider.update_presentation()
		_manager.refresh_hud()
	if not scripted_input:
		_poll_input(delta)


func _physics_process(delta: float) -> void:
	if not _host or OnlineSession.state != "playing" or _manager.finished:
		return
	_arena.wind_event.advance(delta)
	_simulate_spiders(delta)
	var projectiles := get_tree().get_nodes_in_group("camera_focus_projectiles")
	for projectile in projectiles:
		projectile.set_process(false)
		projectile._process(delta)
	_manager.check_match_result()
	if not _manager.waiting_for_wind and projectiles.is_empty():
		for team in _manager.teams:
			team.advance(delta)
		_manager.advance(delta)
	_update_turn()
	_publish_changes()


func _simulate_spiders(delta: float) -> void:
	var idle := COMMAND.new()
	for team_index in range(_manager.teams.size()):
		var team := _manager.teams[team_index]
		for index in range(team.spiders.size()):
			var spider := team.spiders[index]
			var start := spider.global_position
			var id := "%d:%d" % [team_index, index]
			var command := idle
			if team_index * 100 + index == active_actor_id and spider.n_remaining_actions > 0:
				while _authority.has_pending():
					spider.simulate(0.0, _authority.take_command())
				if spider.n_remaining_actions > 0:
					command = _authority.take_command()
			spider.simulate(delta, command)
			_record_motion(id, spider, start, delta, command)


func _poll_input(delta: float) -> void:
	if _manager.finished:
		return
	_input_cooldown = maxf(0.0, _input_cooldown - delta)
	var command := COMMAND.from_input()
	if _manager.waiting_for_wind:
		if Input.is_action_just_pressed("skip_wind"):
			command.held = 128
			submit_command(command)
		return
	if active_owner_id != GDSync.get_client_id():
		return
	_blocked_held &= command.held
	command.held &= ~_blocked_held
	if _pause_menu.visible:
		command.held = 0
		command.selection = -1
		command.cycle = 0
		command.cancel = _last_held > 0
	if not _host and not _predict_aim(command, delta):
		return
	var discrete := command.selection >= 0 or command.cycle != 0 or command.cancel
	var action_edge := (command.held & 64) != (_last_held & 64)
	if discrete or (command.held != _last_held and (_input_cooldown <= 0 or action_edge)):
		submit_command(command)
		_input_cooldown = 1.0 / 30.0


func _predict_aim(command: PlayerCommand, delta: float) -> bool:
	var spider := _active_spider()
	if spider == null or not spider.is_active or spider.n_remaining_actions <= 0:
		return false
	if _local_actor != active_actor_id:
		_local_actor = active_actor_id
		_local_aim = spider.aim_angle
		_local_charge = spider.action_charged_time
	_local_aim += PlayerSpider3D.AIM_SPEED * delta * (int(command.is_pressed("aim_left"))
		- int(command.is_pressed("aim_right")))
	var released := _last_held >= 0 and (_last_held & 64) != 0 and (command.held & 64) == 0
	var aim_stopped := _last_held >= 0 and (_last_held & 48) != 0 and (command.held & 48) == 0
	if released or aim_stopped:
		command.final_aim = _local_aim
	if released and not command.cancel:
		command.final_charge = minf(_local_charge, 600.0)
	if command.is_pressed("action"):
		if (_last_held & 64) == 0:
			_local_charge = 0.0
		_local_charge += delta
	else:
		_local_charge = 0.0
	spider.aim_angle = _local_aim
	spider.action_charged_time = _local_charge
	spider.update_presentation()
	return true


func _reconcile_local_aim() -> void:
	if (_last_held & 112) != 0:
		return
	var id := "%d:%d" % [floori(active_actor_id / 100.0), active_actor_id % 100]
	var motion: Dictionary = _motions.get(id, {})
	if motion.get("aim_speed", 0) == 0 and not motion.get("charging", false):
		_local_actor = -1


func submit_command(command: PlayerCommand) -> bool:
	if OnlineSession.state != "playing" or _manager.finished:
		return false
	if not _manager.waiting_for_wind and active_owner_id != GDSync.get_client_id():
		return false
	_sequence += 1
	_last_held = command.held
	var packet := command.to_packet(_match_id, turn_id, _sequence, active_actor_id)
	if _host:
		_accept_command(GDSync.get_client_id(), packet)
	else:
		_send_host("command", packet)
	return true


func _accept_command(sender: int, packet: Dictionary) -> void:
	if _manager.finished:
		return
	var result := { "accepted": false, "reason": "Waiting for the wind" }
	if _manager.waiting_for_wind:
		var reason := COMMAND.validate_packet(packet, _match_id, turn_id, -1, 0)
		if reason.is_empty() and packet.held == 128 and packet.cycle == 0 and not packet.cancel:
			result = { "accepted": true, "reason": "" }
			_arena.wind_event.skip_to_end()
			OnlineSession.transport.broadcast("wind_skip", { "match": _match_id })
			_update_turn()
			_publish_changes()
	else:
		var spider := _active_spider()
		if spider != null and spider.n_remaining_actions > 0:
			result = _authority.accept(sender, packet, spider.weapons.size())
		else:
			result.reason = "Waiting for the action to finish"
	result["turn"] = packet.get("turn", -1)
	if result.accepted:
		_needs_digest = true
	result["seq"] = packet.get("seq", -1)
	if sender == GDSync.get_client_id():
		command_result.emit(result)
	else:
		result["match"] = _match_id
		OnlineSession.transport.send_to(sender, "command_ack", result)


func _active_spider() -> PlayerSpider3D:
	return _manager.teams[_manager.active_team_idx].get_active_spider()


func _update_turn() -> void:
	if _manager.finished:
		_motions.clear()
		_needs_digest = true
	var team := _manager.teams[_manager.active_team_idx]
	var key := "%d:%d:%d:%s" % [_manager._round_number, _manager.active_team_idx,
		team.active_spider_idx, str(_manager.waiting_for_wind) + str(_manager.finished)]
	if key == _turn_key:
		return
	_turn_key = key
	turn_id += 1
	var blocked := _manager.waiting_for_wind or _manager.finished
	active_actor_id = -1 if blocked else _manager.active_team_idx * 100 \
		+ team.active_spider_idx
	active_owner_id = -1 if blocked else _slots[_manager.active_team_idx]
	_authority.set_turn(_match_id, turn_id, active_actor_id, active_owner_id)
	_clear_local_input()
	_needs_digest = true


func _clear_local_input() -> void:
	_sequence = 0
	_last_held = -1
	_blocked_held = COMMAND.from_input().held
	_local_actor = -1


func _input_state() -> Dictionary:
	return { "turn": turn_id, "actor": active_actor_id, "owner": active_owner_id }


func _apply_input_state(value: Variant) -> void:
	if (not value is Dictionary
			or not value.get("turn") is int \
				or not value.get("actor") is int
			or not value.get("owner") is int):
		return
	if turn_id != value.turn:
		_clear_local_input()
	turn_id = value.turn
	active_actor_id = value.actor
	active_owner_id = value.owner


func _record_motion(id: String, spider: PlayerSpider3D, start: Vector3,
		delta: float, command: PlayerCommand) -> void:
	var speed := ((spider.global_position - start) / delta * 1000.0).round() / 1000.0
	var aim_speed := PlayerSpider3D.AIM_SPEED * (int(command.is_pressed("aim_left"))
		- int(command.is_pressed("aim_right"))) if spider.is_active else 0.0
	var charging := command.is_pressed("action") and spider.is_active
	var moving := not speed.is_zero_approx() or not is_zero_approx(aim_speed) or charging
	var previous: Dictionary = _motions.get(id, {})
	if previous.get(
		"speed",
		[0, 0, 0],
	) == STATE.pack_vector(speed) \
		and previous.get("aim_speed", 0) == STATE.quantize(aim_speed) \
		and previous.get("charging", false) == charging:
		return
	var motion := {"position": STATE.pack_vector(spider.global_position),
		"movement": STATE.quantize(spider.remaining_movement),
		"aim": STATE.quantize(spider.aim_angle),
		"speed": STATE.pack_vector(speed), "aim_speed": STATE.quantize(aim_speed),
		"charging": charging, "charge": spider.action_charged_time,
		"time": GDSync.get_multiplayer_time()}
	_motion_changes[id] = motion
	if moving:
		_motions[id] = motion
	else:
		_motions.erase(id)
		_needs_digest = true


func _present_motion() -> void:
	for id in _motions:
		var motion: Dictionary = _motions[id]
		var parts := str(id).split(":")
		var spider := _manager.teams[int(parts[0])].spiders[int(parts[1])]
		var elapsed := maxf(0.0, GDSync.get_multiplayer_time() - float(motion.time))
		var speed := STATE.unpack_vector(motion.speed)
		var displacement := speed * elapsed
		var budget := float(motion.movement) / STATE.PRECISION
		if displacement.length() > budget:
			displacement = displacement.normalized() * budget
		spider.global_position = STATE.unpack_vector(motion.position) + displacement
		spider.remaining_movement = maxf(0.0, budget - displacement.length())
		spider.aim_angle = float(motion.aim) / STATE.PRECISION \
			+ float(motion.aim_speed) / STATE.PRECISION * elapsed
		spider.action_charged_time = float(motion.charge) + elapsed if motion.charging else 0.0
		if not speed.is_zero_approx():
			spider.spider_rig.rotation.y = atan2(speed.x, -speed.y)


func _apply_motions(values: Variant) -> void:
	if not values is Dictionary or values.size() > 100:
		return
	for id in values:
		if not _state.actors.has(id) or not values[id] is Dictionary:
			continue
		var motion: Dictionary = values[id]
		if (not STATE._valid_vector(motion.get("position")) \
			or not STATE._valid_vector(motion.get("speed")) \
			or not motion.get("aim") is int
				or not motion.get("aim_speed") is int \
					or not motion.get("movement") is int
				or not motion.get("charging") is bool \
					or not motion.get("time") is float
				or not is_finite(motion.time) \
					or not motion.get("charge") is float
				or not is_finite(motion.charge)):
			continue
		if motion.speed == [0, 0, 0] and motion.aim_speed == 0 and not motion.charging:
			_motions.erase(id)
		else:
			_motions[id] = motion


func setup(arena: WebMatch3D) -> void:
	_arena = arena
	_manager = arena.get_node("MatchManager")
	_pause_menu = arena.get_node("PauseMenu")
	_match_id = OnlineSession.match_config.match
	_slots = OnlineSession.match_config.slots
	_host = GDSync.get_client_id() == OnlineSession.host_id
	_projectiles = load("res://src/features/multiplayer/projectile_replication.gd").new()
	add_child(_projectiles)
	_projectiles.setup(arena, _host, GDSync.get_multiplayer_time)
	_projectiles.event_ready.connect(_broadcast_projectile)
	for team in _manager.teams:
		for spider in team.spiders:
			spider.silk_builder.network_replica = not _host
	_arena.wind_event.set_process(false)
	_arena.wind_event.group_size = OnlineSession.match_config.settings.drops
	_arena.wind_event.reset_match(OnlineSession.match_config.seed)
	if _host:
		_arena.wind_event.group_planned.connect(_on_wind_planned)
		_arena.collectible_contact_resolved.connect(_on_wind_contact)
		_record_scene_ready(GDSync.get_client_id())
	else:
		_send_host("scene_ready", {})


func register_projectile(projectile: Projectile3D) -> void:
	_projectiles.register(projectile)
	_needs_digest = true


func _broadcast_projectile(payload: Dictionary) -> void:
	var message := payload.duplicate(true)
	message["match"] = _match_id
	OnlineSession.transport.broadcast("projectile", message)


func receive(sender: int, kind: String, payload: Dictionary) -> void:
	if payload.get("match") != _match_id or not _slots.has(sender):
		return
	if _host:
		_receive_as_host(sender, kind, payload)
	elif sender == OnlineSession.host_id:
		_receive_as_guest(kind, payload)


func _receive_as_host(sender: int, kind: String, payload: Dictionary) -> void:
	match kind:
		"scene_ready":
			_record_scene_ready(sender)
		"snapshot_ack":
			if OnlineSession.state == "loading" and payload.get("digest") == _codec.digest(_state):
				_snapshot_acks[sender] = true
				if _snapshot_acks.size() == _slots.size():
					_begin_match()
		"recover":
			_recover_peer(sender)
		"command":
			_accept_command(sender, payload)
		"state_ack":
			if payload.get("revision") is int and _digests.has(payload.revision):
				if _digests[payload.revision] == payload.get("digest"):
					acknowledged_revision = maxi(acknowledged_revision, payload.revision)
				else:
					_recover_peer(sender)


func _recover_peer(peer: int) -> void:
	var now := Time.get_ticks_msec()
	if now - _recovery_times.get(peer, -2000) >= 1000:
		_recovery_times[peer] = now
		_send_snapshot(peer)


func _request_recovery() -> void:
	_recovering = true
	var now := Time.get_ticks_msec()
	if now - _last_recovery_request >= 1000:
		_last_recovery_request = now
		_send_host("recover", {})


func _receive_as_guest(kind: String, payload: Dictionary) -> void:
	match kind:
		"return_lobby":
			OnlineSession.resume_lobby()
		"flame":
			if STATE._valid_vector(payload.get("position")) \
					and payload.get("aim") is float and is_finite(payload.aim) \
					and payload.get("reach") is float \
					and payload.reach >= 0.5 and payload.reach <= 10:
				Flamethrower3D.present_burst(_arena, STATE.unpack_vector(payload.position),
					payload.aim, payload.reach)
		"snapshot":
			_apply_snapshot(payload)
		"start":
			if initial_state_confirmed:
				OnlineSession.mark_playing()
		"events":
			_apply_events(payload)
		"command_ack":
			if payload.get("accepted") is bool:
				command_result.emit(payload)
		"wind":
			_receive_wind(payload)
		"wind_skip":
			_arena.wind_event.skip_to_end()
		"wind_contact":
			if payload.get("id") is String and payload.get("caught") is bool:
				_wind_contacts[payload.id] = payload.caught
		"projectile":
			_projectiles.receive(payload)


func _on_wind_planned(round_number: int, descriptions: Array) -> void:
	_wind_contacts.clear()
	_wind_description = {"match": _match_id, "round": round_number, "items": descriptions,
		"time": GDSync.get_multiplayer_time()}
	OnlineSession.transport.broadcast("wind", _wind_description)


func _on_wind_contact(id: String, caught: bool, point: Vector3) -> void:
	_wind_contacts[id] = caught
	OnlineSession.transport.broadcast("wind_contact", {"match": _match_id, "id": id,
		"caught": caught, "position": STATE.pack_vector(point)})


func _receive_wind(payload: Dictionary, excluded: Array = []) -> void:
	if not _valid_wind(payload) or _wind_description.get("round", -1) >= payload.round:
		return
	_wind_description = payload
	var elapsed := maxf(0.0, GDSync.get_multiplayer_time() - float(payload.time))
	_arena.wind_event.play_group(payload.round, payload.items, elapsed, excluded)


func _valid_wind(payload: Dictionary) -> bool:
	if not payload.get("round") is int or payload.round < _manager._round_number \
			or not payload.get("time") is float or not is_finite(payload.time) \
			or not payload.get("items") is Array or payload.items.size() > 12:
		return false
	for item in payload.items:
		if not item is Dictionary or not _valid_wind_item(item):
			return false
	return true


func _valid_wind_item(item: Dictionary) -> bool:
	if not item.get("entry") is int or item.entry < 0 \
			or item.entry >= _arena.wind_event.spawn_entries.size() \
			or not item.get("side") is int or item.side < 0 or item.side > 1 \
			or not item.get("id") is String or item.id.length() > 48:
		return false
	if not item.get("duration") is float or not is_finite(item.duration) \
			or item.duration < 1.0 or item.duration > 20.0 \
			or not item.get("sway") is float or not is_finite(item.sway) or absf(item.sway) > 2.0 \
			or not item.get("path") is PackedVector3Array or item.path.size() != 3:
		return false
	for point in item.path:
		if not point.is_finite() or point.length() > 1000.0:
			return false
	return true


func _record_scene_ready(peer: int) -> void:
	if OnlineSession.state != "loading" or _snapshot_acks.size() > 0:
		return
	_scene_ready[peer] = true
	if _scene_ready.size() == _slots.size():
		_state = _codec.capture(_arena)
		_snapshot_acks[GDSync.get_client_id()] = true
		for guest in _slots:
			if guest != GDSync.get_client_id():
				_send_snapshot(guest)


func _send_snapshot(peer: int) -> void:
	var state := _state
	OnlineSession.transport.send_to(peer, "snapshot", {"match": _match_id,
		"revision": revision, "state": state, "digest": _codec.digest(state),
		"input": _input_state(), "motions": _motions,
		"wind": _wind_description if _manager.waiting_for_wind else {}, "contacts": _wind_contacts,
		"projectiles": _projectiles.capture()})


func _apply_snapshot(payload: Dictionary) -> void:
	if not payload.get("state") is Dictionary or not payload.get("revision") is int:
		return
	if initial_state_confirmed and (not _recovering or payload.revision < revision):
		return
	if not _codec.apply(_arena, payload.state):
		OnlineSession.end_match("The starting state is invalid. Update both game copies.")
		return
	var actual := _codec.capture(_arena)
	if _codec.digest(actual) != payload.get("digest"):
		OnlineSession.end_match("The game state could not be synchronized. Please try again.")
		return
	_state = actual
	_recovering = false
	revision = payload.revision
	initial_state_confirmed = true
	if not _projectiles.restore(payload.get("projectiles", [])):
		OnlineSession.end_match("The projectile state could not be synchronized.")
		return
	_apply_input_state(payload.get("input"))
	_motions.clear()
	_apply_motions(payload.get("motions", {}))
	_reconcile_local_aim()
	if payload.get("wind") is Dictionary and not payload.wind.is_empty():
		var excluded: Array = []
		if payload.get("contacts") is Dictionary:
			for id in payload.contacts:
				if payload.contacts[id] == true:
					excluded.append(id)
		_wind_description = {}
		_receive_wind(payload.wind, excluded)
	elif _arena.wind_event.is_active:
		_arena.wind_event.skip_to_end()
	_send_host("snapshot_ack", { "revision": revision, "digest": _codec.digest(actual) })


func _begin_match() -> void:
	initial_state_confirmed = true
	OnlineSession.transport.broadcast("start", { "match": _match_id })
	OnlineSession.mark_playing()
	_manager.give_turn_to(0)
	_update_turn()
	_publish_changes()


func _publish_changes() -> void:
	var current := _codec.capture(_arena)
	var patch := _codec.diff(_state, current)
	if patch.has("caught"):
		_needs_digest = true
	var barrier := _needs_digest and _motions.is_empty() and not _manager.waiting_for_wind \
		and get_tree().get_nodes_in_group("camera_focus_projectiles").is_empty()
	if not barrier and patch.has("actors"):
		for id in patch.actors.keys():
			var before: Dictionary = _state.actors[id].duplicate()
			var after: Dictionary = current.actors[id].duplicate()
			for field in ["position", "movement", "aim"]:
				before.erase(field)
				after.erase(field)
			if before == after:
				patch.actors.erase(id)
		if patch.actors.is_empty():
			patch.erase("actors")
	if patch.is_empty() and _motion_changes.is_empty() and not barrier:
		return
	revision += 1
	_state = _codec.merge(_state, patch)
	var digest := ""
	if barrier:
		digest = _codec.digest(current)
		_digests[revision] = digest
		last_digest_revision = revision
		_needs_digest = false
		if _digests.size() > 32:
			_digests.erase(_digests.keys()[0])
	OnlineSession.transport.broadcast("events", {"match": _match_id,
		"revision": revision, "patch": patch, "digest": digest, "input": _input_state(),
		"motions": _motion_changes})
	_motion_changes = {}


func _apply_events(payload: Dictionary) -> void:
	if not payload.get("revision") is int or payload.revision <= revision:
		return
	if _recovering:
		return
	if payload.revision != revision + 1 or not payload.get("patch") is Dictionary:
		_request_recovery()
		return
	var merged := _codec.merge(_state, payload.patch)
	if not _codec.apply(_arena, merged):
		_request_recovery()
		return
	_state = merged
	revision = payload.revision
	_apply_input_state(payload.get("input"))
	_apply_motions(payload.get("motions", {}))
	_reconcile_local_aim()
	if payload.get("digest", "") != "":
		var digest := _codec.digest(_codec.capture(_arena))
		_send_host("state_ack", { "revision": revision, "digest": digest })
		if digest != payload.digest:
			_recovering = true
			_last_recovery_request = Time.get_ticks_msec()


func _send_host(kind: String, payload: Dictionary) -> void:
	payload["match"] = _match_id
	OnlineSession.transport.send_to(OnlineSession.host_id, kind, payload)


func broadcast_flame(point: Vector3, aim: float, reach: float) -> void:
	if _host:
		OnlineSession.transport.broadcast("flame", {"match": _match_id,
			"position": STATE.pack_vector(point), "aim": aim, "reach": reach})


func match_has_finished() -> bool:
	return _manager.finished
