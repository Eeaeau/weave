extends Node

var _role := ""
var _join_code := ""
var _menu: Control
var _lobby: Control
var _announced := false
var _saw_guest := false
var _done := false
var _checking_rehost := false
var _requested_ready := false
var _both_ready := false
var _settings_changed := false
var _ready_revision := -1
var _saw_countdown := false
var _saw_cancellation := false
var _cancel_test_started := false
var _cancel_wait_complete := false


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--role="):
			_role = argument.trim_prefix("--role=")
		elif argument.begins_with("--code="):
			_join_code = argument.trim_prefix("--code=")
	get_tree().create_timer(30.0).timeout.connect(func() -> void: _fail("Timed out"))
	call_deferred("_run")


func _run() -> void:
	_menu = load("res://src/features/ui/main_menu.tscn").instantiate()
	add_child(_menu)
	_menu.get_node("Center/Menu/PlayButton").pressed.emit()
	_menu.get_node("PlayMenu/OnlineButton").pressed.emit()
	_lobby = _menu.get_node("OnlineLobby")
	if _lobby.get_node("%JoinCode").is_visible_in_tree():
		_fail("Code entry should only appear after choosing Join Lobby")
		return
	OnlineSession.changed.connect(_observe)
	if _role == "host":
		_lobby.get_node("%HostButton").pressed.emit()
	else:
		_lobby.get_node("%JoinButton").pressed.emit()
		if not _lobby.get_node("%JoinCode").is_visible_in_tree():
			_fail("Join Lobby did not open code entry")
			return
		_lobby.get_node("%JoinCode").text = "!"
		_lobby.get_node("%ConfirmJoinButton").pressed.emit()
		if OnlineSession.state != "error" or GDSync.is_active():
			_fail("Invalid code was not rejected before connecting")
			return
		_lobby.get_node("%JoinCode").text = " " + _join_code.to_lower() + " "
		_lobby.get_node("%ConfirmJoinButton").pressed.emit()


func _observe() -> void:
	if _done:
		return
	if OnlineSession.state == "error":
		# The invalid input above intentionally reports this before connecting.
		if OnlineSession.message != "Enter a six-character lobby code.":
			_fail(OnlineSession.message)
		return
	if OnlineSession.state != "in_lobby":
		return
	if _checking_rehost:
		if OnlineSession.players.size() != 1:
			_fail("A new lobby retained players from the previous lobby")
		else:
			_done = true
			call_deferred("_finish")
		return
	if _lobby.get_node("%Code").text != OnlineSession.code:
		_fail("The visible code differs from the joined lobby")
		return
	if _role == "host" and not _announced and OnlineSession.host_id >= 0:
		_announce_host()
	if OnlineSession.players.size() == 2:
		_observe_pair()
	elif _role == "host" and _saw_guest and _both_ready:
		_done = true
		call_deferred("_finish")


func _announce_host() -> void:
	_announced = true
	if OnlineSession.set_match_settings(0):
		_fail("Invalid drop count was accepted")
		return
	_lobby.get("options").drop_count.value = 5
	print("ONLINE_LOBBY_READY: ", OnlineSession.code)


func _observe_pair() -> void:
	if OnlineSession.match_settings.drops == 4:
		if OnlineSession.countdown_remaining() >= 0:
			_saw_countdown = true
		elif _saw_countdown:
			_saw_cancellation = true
	if _role == "guest" and OnlineSession.set_match_settings(8):
		_fail("Guest changed host settings")
		return
	if not _ready_pair():
		return
	if OnlineSession.match_settings.drops == 5:
		if _role == "host" and not _settings_changed:
			_settings_changed = true
			_lobby.get("options").drop_count.value = 4
		return
	if OnlineSession.match_settings.drops != 4:
		return
	if _role == "host" and not _cancel_test_started:
		_cancel_test_started = true
		OnlineSession.set_ready(false)
		get_tree().create_timer(3.3).timeout.connect(_check_countdown_cancelled)
		return
	if not _saw_cancellation or (_role == "host" and not _cancel_wait_complete):
		return
	_both_ready = true
	_saw_guest = true
	if _lobby.get_node("%PlayersCount").text != "2 / 2 players":
		_fail("Player count did not update")
	elif _role == "guest":
		_done = true
		call_deferred("_finish")


func _check_countdown_cancelled() -> void:
	if OnlineSession.state != "in_lobby" or OnlineSession.countdown_remaining() >= 0:
		_fail("Retracting readiness did not cancel the pending match start")
		return
	_cancel_wait_complete = true
	OnlineSession.set_ready(true)


func _ready_pair() -> bool:
	if OnlineSession.host_id < 0:
		return false
	if not _requested_ready or _ready_revision != OnlineSession.match_settings.revision:
		var ready_button := _lobby.get_node_or_null("%ReadyButton") as Button
		if ready_button == null:
			_fail("Lobby has no Ready action")
			return false
		_requested_ready = true
		_ready_revision = OnlineSession.match_settings.revision
		ready_button.pressed.emit()
	if OnlineSession.all_ready() and OnlineSession.can_start() != (_role == "host"):
		_fail("Only the original host may start a ready lobby")
		return false
	if OnlineSession.all_ready() and not OnlineSession.has_method("countdown_remaining"):
		_fail("All ready must start a cancellable countdown")
		return false
	return OnlineSession.all_ready()


func _finish() -> void:
	_lobby.get_node("%LeaveButton").pressed.emit()
	if OnlineSession.state != "idle" or not _menu.get_node("PlayMenu").visible:
		push_error("ONLINE_LOBBY_FAIL: Leaving did not return to the play menu")
		get_tree().quit(1)
		return
	if not _checking_rehost:
		_checking_rehost = true
		_done = false
		_menu.get_node("PlayMenu/OnlineButton").pressed.emit()
		_lobby.get_node("%HostButton").pressed.emit()
		return
	_menu.queue_free()
	await get_tree().process_frame
	await get_tree().create_timer(0.2).timeout
	print("ONLINE_LOBBY_PROBE_PASS: ", _role)
	get_tree().quit(0)


func _fail(reason: String) -> void:
	if _done:
		return
	_done = true
	push_error("ONLINE_LOBBY_FAIL: " + reason)
	OnlineSession.leave_lobby()
	get_tree().quit.call_deferred(1)
