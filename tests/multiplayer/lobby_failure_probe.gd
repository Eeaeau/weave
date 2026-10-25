# The probe waits for real SDK callbacks and isolated fixture shutdown.
# gdstyle:ignore-file=quality/await-in-loop
extends Node

const EXPECTED := {
	"full": "That lobby is full.",
	"closed": "That lobby is closed.",
	"missing": "Lobby not found. Check the code with your friend.",
	"version": "This lobby uses a different game version. Update both copies and try again.",
	"timeout": "Connection timed out. Please try again.",
}

var _role := ""
var _case := ""
var _code := ""
var _stop_path := ""
var _done := false
var _menu: MainMenu


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--role="):
			_role = argument.trim_prefix("--role=")
		elif argument.begins_with("--case="):
			_case = argument.trim_prefix("--case=")
		elif argument.begins_with("--code="):
			_code = argument.trim_prefix("--code=")
		elif argument.begins_with("--stop="):
			_stop_path = argument.trim_prefix("--stop=")
	get_tree().create_timer(30.0).timeout.connect(func() -> void: _fail("Probe timed out"))
	if _role == "host":
		GDSync.connected.connect(_create_fixture)
		GDSync.lobby_created.connect(GDSync.lobby_join)
		GDSync.lobby_joined.connect(_fixture_joined)
		GDSync.start_local_multiplayer()
	else:
		_run_guest.call_deferred()


func _process(_delta: float) -> void:
	if _role == "host" and not _done and FileAccess.file_exists(_stop_path):
		_finish.call_deferred()
		_done = true


func _create_fixture() -> void:
	if _case in ["missing", "timeout", "collision", "cancel-retry"]:
		print("ONLINE_LOBBY_READY: ", _code)
		return
	var content: String = OnlineSession.CONTENT_VERSION
	if _case == "version":
		content = "incompatible-probe"
	var limit := 1 if _case == "full" else 2
	GDSync.lobby_create(OnlineSession.LOBBY_PREFIX + _code, "", false, limit,
		{ "protocol": OnlineSession.PROTOCOL_VERSION, "content": content })


func _fixture_joined(_name: String) -> void:
	if _case == "closed":
		GDSync.lobby_close()
		await get_tree().create_timer(0.3).timeout
	print("ONLINE_LOBBY_READY: ", _code)


func _run_guest() -> void:
	_menu = load("res://src/features/ui/main_menu.tscn").instantiate()
	add_child(_menu)
	_menu.get_node("Center/Menu/PlayButton").pressed.emit()
	_menu.get_node("PlayMenu/OnlineButton").pressed.emit()
	var lobby := _menu.get_node("OnlineLobby") as OnlineLobby
	if _case in ["collision", "cancel-retry"]:
		await _check_collision(lobby)
		return
	lobby.get_node("%JoinButton").pressed.emit()
	lobby.code_field.text = _code
	if _case == "timeout":
		# Simulate an SDK that starts but never reports a connection result.
		GDSync.set_block_signals(true)
	lobby.get_node("%ConfirmJoinButton").pressed.emit()
	if _case == "cancel":
		await _check_cancel(lobby)
		return
	if not await _wait_for_state("error"):
		return
	if OnlineSession.message != EXPECTED[_case] \
			or lobby.get_node("%JoinStatus").text != EXPECTED[_case]:
		_fail("Incorrect lobby error: " + OnlineSession.message)
		return
	if OnlineSession.is_busy() or GDSync.is_active() or not OnlineSession.players.is_empty() \
			or not lobby.code_field.editable or lobby.get_node("%ConfirmJoinButton").disabled:
		_fail("Lobby error left the connection or join controls busy")
		return
	await _finish()


func _check_cancel(lobby: OnlineLobby) -> void:
	if not OnlineSession.is_busy() or lobby.get_node("%JoinBackButton").text != "Cancel":
		_fail("Join did not expose a cancel action")
		return
	lobby.get_node("%JoinBackButton").pressed.emit()
	await get_tree().create_timer(0.5).timeout
	if OnlineSession.state != "idle" or GDSync.is_active():
		_fail("A cancelled connection revived from an old callback")
		return
	lobby.get_node("%HostButton").pressed.emit()
	if not await _wait_for_state("in_lobby"):
		return
	if OnlineSession.players.size() != 1 or OnlineSession.code == _code:
		_fail("Hosting after cancellation retained the old connection")
		return
	await _finish()


func _check_collision(lobby: OnlineLobby) -> void:
	lobby.get_node("%HostButton").pressed.emit()
	if not await _wait_for_state("creating"):
		return
	var first_code := OnlineSession.code
	# Replace the SDK's first creation result with a confirmed name collision.
	GDSync.set_block_signals(true)
	await get_tree().create_timer(0.8).timeout
	GDSync.lobby_leave()
	GDSync.set_block_signals(false)
	GDSync.lobby_creation_failed.emit(OnlineSession.LOBBY_PREFIX + first_code,
		ENUMS.LOBBY_CREATION_ERROR.LOBBY_ALREADY_EXISTS)
	if _case == "cancel-retry":
		lobby.get_node("%ChoiceBackButton").pressed.emit()
		await get_tree().create_timer(3.5).timeout
		if OnlineSession.state != "idle" or GDSync.is_active():
			_fail("A cancelled collision retry restarted hosting")
			return
		await _finish()
		return
	if not await _wait_for_state("in_lobby"):
		return
	if OnlineSession.code == first_code or OnlineSession.players.size() != 1:
		_fail("A confirmed collision did not retry with a fresh code")
		return
	await _finish()


func _wait_for_state(expected: String) -> bool:
	var deadline := Time.get_ticks_msec() + (28_000 if _case == "timeout" else 15_000)
	while OnlineSession.state != expected and not _done:
		if Time.get_ticks_msec() >= deadline:
			_fail("Timed out waiting for " + expected + ": " + OnlineSession.message)
			return false
		await get_tree().process_frame
	return not _done


func _finish() -> void:
	_done = true
	GDSync.set_block_signals(false)
	OnlineSession.leave_lobby()
	if _role == "host":
		GDSync.stop_multiplayer()
	if is_instance_valid(_menu):
		_menu.queue_free()
	await get_tree().process_frame
	await get_tree().create_timer(0.2).timeout
	print("LOBBY_FAILURE_PASS: ", _role, " ", _case)
	get_tree().quit(0)


func _fail(reason: String) -> void:
	if _done:
		return
	_done = true
	GDSync.set_block_signals(false)
	push_error("LOBBY_FAILURE_FAIL: " + reason)
	OnlineSession.leave_lobby()
	get_tree().quit(1)
