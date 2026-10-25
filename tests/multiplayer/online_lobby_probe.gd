extends Node

var _role := ""
var _join_code := ""
var _menu: Control
var _lobby: Control
var _announced := false
var _saw_guest := false
var _done := false
var _checking_rehost := false


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
	OnlineSession.changed.connect(_observe)
	if _role == "host":
		_lobby.get_node("Center/Menu/HostButton").pressed.emit()
	else:
		_lobby.get_node("Center/Menu/JoinCode").text = "!"
		_lobby.get_node("Center/Menu/JoinButton").pressed.emit()
		if OnlineSession.state != "error" or GDSync.is_active():
			_fail("Invalid code was not rejected before connecting")
			return
		_lobby.get_node("Center/Menu/JoinCode").text = " " + _join_code.to_lower() + " "
		_lobby.get_node("Center/Menu/JoinButton").pressed.emit()


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
	if _lobby.get_node("Center/Menu/Code").text != OnlineSession.code:
		_fail("The visible code differs from the joined lobby")
		return
	if _role == "host" and not _announced:
		_announced = true
		print("ONLINE_LOBBY_READY: ", OnlineSession.code)
	if OnlineSession.players.size() == 2:
		_saw_guest = true
		if _lobby.get_node("Center/Menu/Players").text != "2 / 2 players":
			_fail("Player count did not update")
		elif _role == "guest":
			_done = true
			call_deferred("_finish")
	elif _role == "host" and _saw_guest:
		_done = true
		call_deferred("_finish")


func _finish() -> void:
	_lobby.get_node("Center/Menu/BackButton").pressed.emit()
	if OnlineSession.state != "idle" or not _menu.get_node("PlayMenu").visible:
		push_error("ONLINE_LOBBY_FAIL: Leaving did not return to the play menu")
		get_tree().quit(1)
		return
	if not _checking_rehost:
		_checking_rehost = true
		_done = false
		_menu.get_node("PlayMenu/OnlineButton").pressed.emit()
		_lobby.get_node("Center/Menu/HostButton").pressed.emit()
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
