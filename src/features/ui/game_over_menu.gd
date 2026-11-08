class_name GameOverMenu
extends CanvasLayer


func _ready() -> void:
	visible = false
	$Backdrop/Center/Menu/RetryButton.pressed.connect(_on_retry_pressed)
	$Backdrop/Center/Menu/MainMenuButton.pressed.connect(_on_main_menu_pressed)


func show_result(winner: int) -> void:
	var session := get_node("/root/OnlineSession")
	var manager: MatchManager = get_parent().get_node("MatchManager")
	var title := "Draw!"
	var online: bool = session.is_match_active()
	if winner >= 0:
		if online:
			title = "Victory!" if session.match_config.slots[winner] == get_node(
				"/root/GDSync").get_client_id() else "Defeat"
		else:
			title = "%s wins!" % manager.teams[winner].name
	$Backdrop/Center/Menu/Title.text = title
	$Backdrop/Center/Menu/RetryButton.text = "Return to Lobby" if online else "Play Again"
	$Backdrop/Center/Menu/RetryButton.disabled = online and session.host_id != get_node(
		"/root/GDSync").get_client_id()
	$Backdrop/Center/Menu/WaitingLabel.visible = $Backdrop/Center/Menu/RetryButton.disabled
	get_parent().get_node("PauseMenu").hide()
	get_parent().get_node("PauseMenu").process_mode = Node.PROCESS_MODE_DISABLED
	visible = true
	$Backdrop/Center/Menu/MainMenuButton.grab_focus()


func _on_retry_pressed() -> void:
	var session := get_node("/root/OnlineSession")
	if session.is_match_active():
		session.return_to_lobby()
	else:
		var options: Dictionary = { "map": "canopy", "drops": get_parent().wind_event.group_size }
		preload("res://src/game/match_options.gd").queue_local(get_tree(), options)
		get_tree().reload_current_scene()


func _on_main_menu_pressed() -> void:
	var session := get_node("/root/OnlineSession")
	if session.is_match_active():
		session.leave_lobby()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://src/features/ui/main_menu.tscn")
