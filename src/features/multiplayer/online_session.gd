extends Node

signal changed

const CODE_ALPHABET := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
const LOBBY_PREFIX := "spiders-v1-"
const PLAYER_LIMIT := 2
const PROTOCOL_VERSION := 1
const CONTENT_VERSION := "spiders-online-4"
const READY_COUNTDOWN_SECONDS := 3.0
const KEY_STORE := preload("res://addons/GD-Sync/Scripts/KeyStore.gd")

var state := "idle"
var message := "Host a lobby or enter a friend's code."
var code := ""
var host_id := -1
var players: Array[int] = []
var ready_players: Dictionary = {}
var match_settings := { "map": "canopy", "drops": 3, "revision": 0 }
var _countdown_ends_at := -1.0
var match_config: Dictionary = {}
var transport: Node
var replication: Node
var _pending_match_messages: Array[Array] = []
var use_local_network := false
var _hosting := false
var _generation := 0
var _creation_attempts := 0


func _ready() -> void:
	transport = preload("res://src/features/multiplayer/gd_sync_transport.gd").new()
	transport.name = "Transport"
	add_child(transport)
	transport.received.connect(_on_message)
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


func _process(_delta: float) -> void:
	if can_start() and _countdown_ends_at >= 0 \
			and GDSync.get_multiplayer_time() >= _countdown_ends_at:
		start_match()


func set_ready(value: bool) -> void:
	if state != "in_lobby" or host_id < 0:
		return
	if GDSync.get_client_id() == host_id:
		_accept_ready(host_id, PROTOCOL_VERSION, CONTENT_VERSION, value, match_settings.revision)
	else:
		GDSync.call_func_on(host_id, _receive_ready, PROTOCOL_VERSION, CONTENT_VERSION,
			value, match_settings.revision)


func countdown_remaining() -> float:
	if state != "in_lobby" or _countdown_ends_at < 0:
		return -1.0
	return maxf(0.0, _countdown_ends_at - GDSync.get_multiplayer_time())


func set_match_settings(drops: int, map_id: String = "canopy") -> bool:
	if state != "in_lobby" or host_id < 0 or GDSync.get_client_id() != host_id:
		return false
	var next := { "map": map_id, "drops": drops, "revision": match_settings.revision + 1 }
	if not _valid_settings(next):
		return false
	if drops == match_settings.drops and map_id == match_settings.map:
		return true
	match_settings = next
	ready_players.clear()
	_publish_readiness()
	return true


func _valid_settings(value: Variant) -> bool:
	return value is Dictionary and value.size() == 3 and value.get("map") == "canopy" \
		and value.get("drops") is int and value.drops >= 1 and value.drops <= 12 \
		and value.get("revision") is int and value.revision >= 0 and value.revision <= 1_000_000


func all_ready() -> bool:
	if state != "in_lobby" or players.size() != PLAYER_LIMIT:
		return false
	for player in players:
		if not ready_players.get(player, false):
			return false
	return true


func can_start() -> bool:
	return all_ready() and GDSync.get_client_id() == host_id


func is_match_active() -> bool:
	return state in ["loading", "playing"]


func start_match() -> void:
	if not can_start() or _countdown_ends_at < 0 \
			or GDSync.get_multiplayer_time() < _countdown_ends_at:
		return
	var slots := players.duplicate()
	slots.sort()
	slots.erase(host_id)
	slots.push_front(host_id)
	var config := {"match": Crypto.new().generate_random_bytes(16).hex_encode(), "slots": slots,
		"seed": randi_range(
			1,
			2_147_483_647,
		), "protocol": PROTOCOL_VERSION, "content": CONTENT_VERSION,
		"settings": match_settings.duplicate()}
	GDSync.lobby_close()
	transport.broadcast("prepare", config)
	_prepare_match(config)


func _on_message(sender: int, kind: String, payload: Dictionary) -> void:
	if kind == "prepare" and sender == host_id and state == "in_lobby":
		_prepare_match(payload)
	elif is_match_active() and match_config.slots.has(sender) \
			and payload.get("match") == match_config.match:
		if is_instance_valid(replication):
			replication.receive(sender, kind, payload)
		elif _pending_match_messages.size() < 64:
			_pending_match_messages.append([sender, kind, payload])


func attach_replication(driver: Node, arena: Node3D) -> void:
	replication = driver
	driver.setup(arena)
	for entry in _pending_match_messages:
		driver.receive(entry[0], entry[1], entry[2])
	_pending_match_messages.clear()


func _prepare_match(config: Dictionary) -> void:
	if not _valid_match_config(config):
		_fail("The host sent an incompatible match setup.")
		return
	match_config = config.duplicate(true)
	_set_state("loading", "Waiting for both players to load...")
	var generation := _generation
	get_tree().create_timer(30.0).timeout.connect(func() -> void:
		if generation == _generation and state == "loading":
			_fail("The other player did not finish loading. Please try again."))
	_load_match.call_deferred()


func _valid_match_config(config: Dictionary) -> bool:
	if config.get("protocol") != PROTOCOL_VERSION or config.get("content") != CONTENT_VERSION \
			or not config.get("match") is String or config.match.length() != 32 \
			or not config.get("seed") is int or not config.get("slots") is Array:
		return false
	if not _valid_settings(config.get("settings")) or config.settings != match_settings:
		return false
	var slots: Array = config.slots
	if slots.size() != PLAYER_LIMIT or slots[0] != host_id:
		return false
	for peer in players:
		if slots.count(peer) != 1:
			return false
	return players.size() == slots.size()


func _load_match() -> void:
	if (state == "loading"
			and get_tree().change_scene_to_file("res://src/game/web_match.tscn") != OK):
		_fail("Couldn't load the match. Please restart the game.")


func mark_playing() -> void:
	if state == "loading":
		_set_state("playing", "")


func end_match(reason: String) -> void:
	if is_match_active():
		_fail(reason)


func _receive_ready(protocol: Variant, content: Variant, value: Variant,
		settings_revision: Variant) -> void:
	_accept_ready(GDSync.get_sender_id(), protocol, content, value, settings_revision)


func _accept_ready(sender: int, protocol: Variant, content: Variant, value: Variant,
		settings_revision: Variant) -> void:
	if state != "in_lobby" or GDSync.get_client_id() != host_id or not players.has(sender):
		return
	if protocol != PROTOCOL_VERSION or content != CONTENT_VERSION or not value is bool:
		return
	if not settings_revision is int or settings_revision != match_settings.revision:
		_publish_readiness()
		return
	ready_players[sender] = value
	_publish_readiness()


func _publish_readiness() -> void:
	if GDSync.get_client_id() == host_id:
		if all_ready():
			if _countdown_ends_at < 0:
				_countdown_ends_at = GDSync.get_multiplayer_time() + READY_COUNTDOWN_SECONDS
		else:
			_countdown_ends_at = -1.0
		GDSync.call_func(_receive_readiness, ready_players, match_settings, _countdown_ends_at)
	changed.emit()


func _receive_readiness(values: Variant, settings: Variant, countdown_end: Variant) -> void:
	if state != "in_lobby" or GDSync.get_sender_id() != host_id or not values is Dictionary:
		return
	if values.size() > PLAYER_LIMIT:
		return
	if not _valid_settings(settings) or settings.revision < match_settings.revision:
		return
	if not countdown_end is float or not is_finite(countdown_end):
		return
	for player in values:
		if not player is int or not players.has(player) or not values[player] is bool:
			return
	ready_players = values.duplicate()
	match_settings = settings.duplicate()
	_countdown_ends_at = countdown_end
	changed.emit()


func host_lobby() -> void:
	if is_busy() or state == "in_lobby" or is_match_active():
		return
	_hosting = true
	_creation_attempts = 0
	code = ""
	_start()


func join_lobby(entered_code: String) -> void:
	if is_busy() or state == "in_lobby" or is_match_active():
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
	match_settings = { "map": "canopy", "drops": 3, "revision": 0 }
	_countdown_ends_at = -1.0
	match_config.clear()
	replication = null
	_pending_match_messages.clear()
	_set_state("idle", "Host a lobby or enter a friend's code.")


func is_busy() -> bool:
	return state in ["connecting", "creating", "joining", "loading"]


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
	if is_match_active() and match_config.slots.has(client_id):
		_fail("A player disconnected. The online match has ended.")
		return
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
	if (state == "in_lobby" or is_match_active()) and host_id != -1 and new_host_id != host_id:
		_fail("The host left the lobby.")


func _on_kicked(_reason: String) -> void:
	if state == "in_lobby" or is_match_active():
		_fail("The host closed the lobby.")


func _fail(reason: String) -> void:
	var was_in_match := is_match_active()
	leave_lobby()
	_set_state("error", reason)
	if was_in_match:
		get_tree().paused = false
		get_tree().change_scene_to_file.call_deferred("res://src/features/ui/main_menu.tscn")


func _set_state(next_state: String, next_message: String) -> void:
	state = next_state
	message = next_message
	changed.emit()
