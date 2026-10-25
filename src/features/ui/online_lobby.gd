class_name OnlineLobby
extends Control

signal closed

@onready var menu: VBoxContainer = $Center/Menu
@onready var status_label: Label = $Center/Menu/Status
@onready var code_field: LineEdit = $Center/Menu/JoinCode


func _ready() -> void:
	menu.get_node("HostButton").pressed.connect(OnlineSession.host_lobby)
	menu.get_node("JoinButton").pressed.connect(_join)
	menu.get_node("CopyButton").pressed.connect(_copy_code)
	menu.get_node("ReadyButton").pressed.connect(_toggle_ready)
	menu.get_node("BackButton").pressed.connect(close_menu)
	code_field.text_submitted.connect(func(_text: String) -> void: _join())
	OnlineSession.changed.connect(_refresh)
	_refresh()


func open() -> void:
	show()
	_refresh()
	menu.get_node("HostButton").grab_focus()


func close_menu() -> void:
	OnlineSession.leave_lobby()
	hide()
	closed.emit()


func _join() -> void:
	OnlineSession.join_lobby(code_field.text)


func _copy_code() -> void:
	if OnlineSession.state == "in_lobby":
		DisplayServer.clipboard_set(OnlineSession.code)


func _toggle_ready() -> void:
	OnlineSession.set_ready(not OnlineSession.ready_players.get(GDSync.get_client_id(), false))


func _refresh() -> void:
	var in_lobby := OnlineSession.state == "in_lobby"
	var busy := OnlineSession.is_busy()
	status_label.text = OnlineSession.message
	menu.get_node("HostButton").visible = not in_lobby
	menu.get_node("HostButton").disabled = busy
	menu.get_node("JoinButton").visible = not in_lobby
	menu.get_node("JoinButton").disabled = busy
	code_field.visible = not in_lobby
	code_field.editable = not busy
	menu.get_node("Code").visible = in_lobby
	menu.get_node("Code").text = OnlineSession.code
	menu.get_node("CopyButton").visible = in_lobby
	menu.get_node("Players").visible = in_lobby
	menu.get_node("Players").text = "%d / %d players" % [
		OnlineSession.players.size(), OnlineSession.PLAYER_LIMIT]
	menu.get_node("ReadyButton").visible = in_lobby
	menu.get_node("ReadyButton").disabled = OnlineSession.host_id < 0
	menu.get_node("ReadyButton").text = "Not Ready" if OnlineSession.ready_players.get(
		GDSync.get_client_id(), false) else "Ready"
	menu.get_node("ReadyCount").visible = in_lobby
	menu.get_node("ReadyCount").text = "%d / %d ready" % [
		OnlineSession.ready_players.values().count(true), OnlineSession.PLAYER_LIMIT]
	menu.get_node("BackButton").text = "Leave Lobby" if in_lobby else "Back"
