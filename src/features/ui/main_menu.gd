class_name MainMenu
extends Control
## Dimension-independent entry screen.


func _ready() -> void:
	get_tree().paused = false
	$Center/Menu/PlayButton.pressed.connect(_on_play_pressed)
	$PlayMenu/LocalButton.pressed.connect(_on_local_pressed)
	$PlayMenu/OnlineButton.pressed.connect(_on_online_pressed)
	$PlayMenu/BackButton.pressed.connect(_on_play_closed)
	$Center/Menu/SettingsButton.pressed.connect(_on_settings_pressed)
	$Center/Menu/QuitButton.pressed.connect(_on_quit_pressed)
	$Center/Menu/QuitButton.visible = not OS.has_feature("web")
	$SettingsMenu.closed.connect(_on_settings_closed)
	$OnlineLobby.closed.connect(_on_online_closed)
	$LocalGameSetup.closed.connect(_on_local_setup_closed)
	$Center/Menu/PlayButton.grab_focus()
	if get_node("/root/OnlineSession").state in ["error", "in_lobby"]:
		_on_play_pressed()
		_on_online_pressed()


func _on_play_pressed() -> void:
	$Center.hide()
	$PlayMenu.show()
	$PlayMenu/LocalButton.grab_focus()


func _on_play_closed() -> void:
	$PlayMenu.hide()
	$Center.show()
	$Center/Menu/PlayButton.grab_focus()


func _on_local_pressed() -> void:
	$PlayMenu.hide()
	$LocalGameSetup.open()


func _on_local_setup_closed() -> void:
	$PlayMenu.show()
	$PlayMenu/LocalButton.grab_focus()


func _on_online_pressed() -> void:
	$PlayMenu.hide()
	$OnlineLobby.open()


func _on_online_closed() -> void:
	$PlayMenu.show()
	$PlayMenu/OnlineButton.grab_focus()


func _on_quit_pressed() -> void:
	get_tree().quit()


func _on_settings_pressed() -> void:
	$Center.visible = false
	$SettingsMenu.open()


func _on_settings_closed() -> void:
	$Center.visible = true
	$Center/Menu/SettingsButton.grab_focus()
