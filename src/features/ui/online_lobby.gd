class_name OnlineLobby
extends Control

signal closed

var _join_mode := false

@onready var code_field: LineEdit = %JoinCode
@onready var options: PanelContainer = $LobbyMargin/Lobby/Columns/SettingsPanel


func _ready() -> void:
	%HostButton.pressed.connect(OnlineSession.host_lobby)
	%JoinButton.pressed.connect(_open_join)
	%ConfirmJoinButton.pressed.connect(_join)
	%JoinBackButton.pressed.connect(_back_from_join)
	%ChoiceBackButton.pressed.connect(close_menu)
	%CopyButton.pressed.connect(_copy_code)
	%ReadyButton.pressed.connect(_toggle_ready)
	%LeaveButton.pressed.connect(close_menu)
	options.drop_count_changed.connect(_change_drop_count)
	code_field.text_submitted.connect(func(_text: String) -> void: _join())
	OnlineSession.changed.connect(_refresh)
	_refresh()


func _process(_delta: float) -> void:
	if visible and OnlineSession.state == "in_lobby":
		_update_countdown()


func open() -> void:
	_join_mode = false
	show()
	_refresh()
	%HostButton.grab_focus()


func close_menu() -> void:
	OnlineSession.leave_lobby()
	hide()
	closed.emit()


func _open_join() -> void:
	_join_mode = true
	_refresh()
	code_field.grab_focus()


func _back_from_join() -> void:
	OnlineSession.leave_lobby()
	_join_mode = false
	_refresh()
	%JoinButton.grab_focus()


func _join() -> void:
	OnlineSession.join_lobby(code_field.text)


func _copy_code() -> void:
	if OnlineSession.state == "in_lobby":
		DisplayServer.clipboard_set(OnlineSession.code)


func _toggle_ready() -> void:
	OnlineSession.set_ready(not OnlineSession.ready_players.get(GDSync.get_client_id(), false))


func _change_drop_count(value: int) -> void:
	OnlineSession.set_match_settings(value)


func _update_countdown() -> void:
	var remaining := OnlineSession.countdown_remaining()
	if remaining >= 0:
		%LobbyStatus.text = "Starting in %d... Unready to cancel." % ceili(remaining)
	else:
		%LobbyStatus.text = "%d / %d ready. Ready up to start." % [
			OnlineSession.ready_players.values().count(true), OnlineSession.PLAYER_LIMIT]


func _refresh() -> void:
	var in_lobby := OnlineSession.state == "in_lobby"
	var busy := OnlineSession.is_busy()
	var is_host := OnlineSession.host_id >= 0 and OnlineSession.host_id == GDSync.get_client_id()
	$ChoiceCenter.visible = not in_lobby and not _join_mode
	$JoinCenter.visible = not in_lobby and _join_mode
	$LobbyMargin.visible = in_lobby
	%ChoiceStatus.text = OnlineSession.message
	%JoinStatus.text = OnlineSession.message
	%HostButton.disabled = busy
	%JoinButton.disabled = busy
	%ConfirmJoinButton.disabled = busy
	code_field.editable = not busy
	%JoinBackButton.text = "Cancel" if busy else "Back"
	%Code.text = OnlineSession.code
	%PlayersCount.text = "%d / %d players" % [
		OnlineSession.players.size(),
		OnlineSession.PLAYER_LIMIT,
	]
	%PlayersList.text = _player_list()
	%ReadyButton.disabled = OnlineSession.host_id < 0
	%ReadyButton.text = "Unready" if OnlineSession.ready_players.get(
		GDSync.get_client_id(), false) else "Ready"
	_update_countdown()
	var note := "Changing settings resets readiness."
	if not is_host:
		note = "Host controls match settings."
	options.set_values(OnlineSession.match_settings, is_host, note)


func _player_list() -> String:
	var players := OnlineSession.players.duplicate()
	players.sort()
	players.erase(OnlineSession.host_id)
	if OnlineSession.host_id >= 0:
		players.push_front(OnlineSession.host_id)
	var rows := PackedStringArray()
	for index in range(OnlineSession.PLAYER_LIMIT):
		if index >= players.size():
			rows.append("Waiting for player...")
			continue
		var id: int = players[index]
		var label := "Host" if id == OnlineSession.host_id else "Player %d" % (index + 1)
		if id == GDSync.get_client_id():
			label += " (You)"
		rows.append("%s\n%s" % [label,
			"Ready" if OnlineSession.ready_players.get(id, false) else "Not ready"])
	return "\n\n".join(rows)
