extends Node

var _client: Node
var _role: String
var _code: String
var _online := false
var _done := false


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--role="):
			_role = argument.trim_prefix("--role=")
		elif argument.begins_with("--code="):
			_code = argument.trim_prefix("--code=")
		elif argument == "--online":
			_online = true
	_client = get_node_or_null("/root/GDSync")
	if _client == null:
		_fail("GD-Sync autoload is missing")
		return
	_client.connected.connect(_on_connected)
	_client.connection_failed.connect(func(error: int) -> void:
		_fail("Connection failed: %d" % error))
	_client.lobby_created.connect(_on_lobby_created)
	_client.lobby_creation_failed.connect(func(_name: String, error: int) -> void:
		_fail("Lobby creation failed: %d" % error))
	_client.lobby_joined.connect(_on_lobby_joined)
	_client.lobby_join_failed.connect(func(_name: String, error: int) -> void:
		_fail("Lobby join failed: %d" % error))
	_client.disconnected.connect(func() -> void: _fail("Unexpected disconnect"))
	_client.expose_func(receive_probe)
	_client.expose_func(receive_reply)
	_client.expose_func(receive_acknowledgement)
	get_tree().create_timer(30.0).timeout.connect(func() -> void: _fail("Probe timed out"))
	if _online:
		_client.start_multiplayer()
	else:
		_client.start_local_multiplayer()


func _on_connected() -> void:
	print("GD_SYNC_CONNECTED: ", _role)
	if _role == "host":
		_client.lobby_create(_code, "", false, 2)
	else:
		_client.lobby_join(_code)


func _on_lobby_created(lobby_name: String) -> void:
	_client.lobby_join(lobby_name)


func _on_lobby_joined(_lobby_name: String) -> void:
	print("GD_SYNC_JOINED: ", _role)
	if _role == "guest":
		_client.call_func_on(_client.get_host(), receive_probe, "probe", 42)


func receive_probe(message: String, value: int) -> void:
	if _role != "host" or message != "probe" or value != 42:
		_fail("Invalid probe")
		return
	_client.call_func_on(_client.get_sender_id(), receive_reply, "reply", value + 1)


func receive_reply(message: String, value: int) -> void:
	if _role != "guest" or _client.get_sender_id() != _client.get_host() \
			or message != "reply" or value != 43:
		_fail("Invalid host reply")
		return
	_client.call_func_on(_client.get_host(), receive_acknowledgement, value)
	_finish()


func receive_acknowledgement(value: int) -> void:
	if _role != "host" or value != 43:
		_fail("Invalid acknowledgement")
		return
	_finish()


func _finish() -> void:
	_done = true
	print("GD_SYNC_PROBE_PASS: ", _role)
	await get_tree().create_timer(0.3).timeout
	_client.stop_multiplayer()
	get_tree().quit(0)


func _fail(reason: String) -> void:
	if _done:
		return
	_done = true
	push_error("GD_SYNC_PROBE_FAIL: " + reason)
	if _client != null:
		_client.stop_multiplayer()
	get_tree().quit.call_deferred(1)
