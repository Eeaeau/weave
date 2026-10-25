extends Node

signal changed

const CODE_ALPHABET := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
const LOBBY_PREFIX := "spiders-v1-"
const PLAYER_LIMIT := 2
const PROTOCOL_VERSION := 1
const CONTENT_VERSION := "spiders-online-1"
const KEY_STORE := preload("res://addons/GD-Sync/Scripts/KeyStore.gd")

var state := "idle"
var message := "Host a lobby or enter a friend's code."
var code := ""
var host_id := -1
var players: Array[int] = []
var ready_players: Dictionary = {}
var use_local_network := false
var _hosting := false
var _generation := 0
var _creation_attempts := 0


func _ready() -> void:
	use_local_network = OS.get_cmdline_user_args().has("--local-network")
	GDSync.connected.connect(_on_connected)
	GDSync.connection_failed.connect(_on_connection_failed)
	GDSync.disconnected.connect(_on_disconnected)
	GDSync.lobby_created.connect(_on_lobby_created)
	GDSync.lobby_creation_failed.connect(_on_creation_failed)
	GDSync.lobby_joined.connect(_on_lobby_joined)
	GDSync.lobby_join_failed.connect(_on_join_failed)
	GDSync.client_joined.connect(_on_client_joined)
	GDSync.client_left.connect(_on_client_left)
	GDSync.host_changed.connect(_on_host_changed)
	GDSync.kicked.connect(_on_kicked)
	GDSync.expose_func(_receive_ready)
	GDSync.expose_func(_receive_readiness)


func set_ready(value: bool) -> void:
	if state != "in_lobby" or host_id < 0:
		return
	if GDSync.get_client_id() == host_id:
		_accept_ready(host_id, PROTOCOL_VERSION, CONTENT_VERSION, value)
	else:
		GDSync.call_func_on(host_id, _receive_ready, PROTOCOL_VERSION, CONTENT_VERSION, value)


func all_ready() -> bool:
	if state != "in_lobby" or players.size() != PLAYER_LIMIT:
		return false
	for player in players:
		if not ready_players.get(player, false):
			return false
	return true


func can_start() -> bool:
	return all_ready() and GDSync.get_client_id() == host_id


func _receive_ready(protocol: Variant, content: Variant, value: Variant) -> void:
	_accept_ready(GDSync.get_sender_id(), protocol, content, value)


func _accept_ready(sender: int, protocol: Variant, content: Variant, value: Variant) -> void:
	if state != "in_lobby" or GDSync.get_client_id() != host_id or not players.has(sender):
		return
	if protocol != PROTOCOL_VERSION or content != CONTENT_VERSION or not value is bool:
		return
	ready_players[sender] = value
	_publish_readiness()


func _publish_readiness() -> void:
	if GDSync.get_client_id() == host_id:
		GDSync.call_func(_receive_readiness, ready_players)
	changed.emit()


func _receive_readiness(values: Variant) -> void:
	print("READINESS RECEIVE ", GDSync.get_client_id(), " <- ", GDSync.get_sender_id(), " ", values)
	if state != "in_lobby" or GDSync.get_sender_id() != host_id or not values is Dictionary:
		return
	if values.size() > PLAYER_LIMIT:
		return
	for player in values:
		if not player is int or not values[player] is bool:
			return
	ready_players = values.duplicate()
	changed.emit()


func host_lobby() -> void:
	if is_busy() or state == "in_lobby":
		return
	_hosting = true
	_creation_attempts = 0
	code = ""
	_start()


func join_lobby(entered_code: String) -> void:
	if is_busy() or state == "in_lobby":
		return
	var normalized := entered_code.strip_edges().to_upper()
	var valid := normalized.length() == 6
	for character in normalized:
		valid = valid and CODE_ALPHABET.contains(character)
	if not valid:
		_set_state("error", "Enter a six-character lobby code.")
		return
	_hosting = false
	code = normalized
	_start()


func leave_lobby() -> void:
	_generation += 1
	state = "idle"
	if GDSync.is_active():
		GDSync.lobby_leave()
	GDSync.stop_multiplayer()
	code = ""
	host_id = -1
	players.clear()
	ready_players.clear()
	_set_state("idle", "Host a lobby or enter a friend's code.")


func is_busy() -> bool:
	return state in ["connecting", "creating", "joining"]


func _start() -> void:
	if not use_local_network and not KEY_STORE.has_keys():
		_set_state("error", "Online play is not configured on this build.")
		return
	_generation += 1
	var request_generation := _generation
	_set_state("connecting", "Connecting...")
	get_tree().create_timer(25.0).timeout.connect(func() -> void:
		if request_generation == _generation and is_busy():
			_fail("Connection timed out. Please try again."))
	if use_local_network:
		GDSync.start_local_multiplayer()
	else:
		GDSync.start_multiplayer()


func _on_connected() -> void:
	if state != "connecting":
		return
	if _hosting:
		_create_lobby()
	else:
		_set_state("joining", "Joining lobby...")
		GDSync.lobby_join(LOBBY_PREFIX + code)


func _create_lobby() -> void:
	_creation_attempts += 1
	code = ""
	for random_byte in Crypto.new().generate_random_bytes(6):
		code += CODE_ALPHABET[random_byte % CODE_ALPHABET.length()]
	_set_state("creating", "Creating lobby...")
	GDSync.lobby_create(LOBBY_PREFIX + code, "", false, PLAYER_LIMIT,
		{ "protocol": PROTOCOL_VERSION, "content": CONTENT_VERSION })


func _on_lobby_created(lobby_name: String) -> void:
	if state != "creating" or lobby_name != LOBBY_PREFIX + code:
		return
	_set_state("joining", "Opening lobby...")
	GDSync.lobby_join(lobby_name)


func _on_lobby_joined(lobby_name: String) -> void:
	if state != "joining" or lobby_name != LOBBY_PREFIX + code:
		return
	host_id = GDSync.get_host()
	if GDSync.lobby_get_tag("protocol") != PROTOCOL_VERSION \
			or GDSync.lobby_get_tag("content") != CONTENT_VERSION:
		_fail("This lobby uses a different game version. Update both copies and try again.")
		return
	players.assign(GDSync.lobby_get_all_clients())
	_set_state("in_lobby", "Share the code with a friend." if _hosting else "Joined lobby.")


func _on_creation_failed(lobby_name: String, error: int) -> void:
	if state != "creating" or lobby_name != LOBBY_PREFIX + code:
		return
	if error == ENUMS.LOBBY_CREATION_ERROR.LOBBY_ALREADY_EXISTS and _creation_attempts < 4:
		var request_generation := _generation
		await get_tree().create_timer(3.2).timeout
		if request_generation == _generation and state == "creating":
			_create_lobby()
	else:
		_fail("Couldn't create a lobby. Please try again.")


func _on_join_failed(lobby_name: String, error: int) -> void:
	if state != "joining" or lobby_name != LOBBY_PREFIX + code:
		return
	var reason := "Couldn't join that lobby. Please try again."
	match error:
		ENUMS.LOBBY_JOIN_ERROR.LOBBY_DOES_NOT_EXIST:
			reason = "Lobby not found. Check the code with your friend."
		ENUMS.LOBBY_JOIN_ERROR.LOBBY_IS_CLOSED:
			reason = "That lobby is closed."
		ENUMS.LOBBY_JOIN_ERROR.LOBBY_IS_FULL:
			reason = "That lobby is full."
	_fail(reason)


func _on_connection_failed(_error: int) -> void:
	if is_busy():
		_fail("Couldn't connect to online play. Check your connection and try again.")


func _on_disconnected() -> void:
	if state != "idle" and state != "error":
		_fail("Connection lost. Please host or join again.")


func _on_client_joined(client_id: int) -> void:
	if state == "in_lobby" and not players.has(client_id):
		players.append(client_id)
		ready_players.clear()
		_publish_readiness()


func _on_client_left(client_id: int) -> void:
	if state != "in_lobby":
		return
	if client_id == host_id:
		_fail("The host left the lobby.")
	else:
		players.erase(client_id)
		ready_players.clear()
		_publish_readiness()


func _on_host_changed(_is_host: bool, new_host_id: int) -> void:
	if state == "in_lobby" and host_id == -1:
		host_id = new_host_id
		changed.emit()
		return
	if state == "in_lobby" and host_id != -1 and new_host_id != host_id:
		_fail("The host left the lobby.")


func _on_kicked(_reason: String) -> void:
	if state == "in_lobby":
		_fail("The host closed the lobby.")


func _fail(reason: String) -> void:
	leave_lobby()
	_set_state("error", reason)


func _set_state(next_state: String, next_message: String) -> void:
	state = next_state
	message = next_message
	changed.emit()
