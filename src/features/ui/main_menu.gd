class_name MainMenu
extends Control
## Dimension-independent entry screen.


func _ready() -> void:
	get_tree().paused = false
	$Center/Menu/PlayButton.pressed.connect(_on_play_pressed)
	$Center/Menu/SettingsButton.pressed.connect(_on_settings_pressed)
	$Center/Menu/QuitButton.pressed.connect(_on_quit_pressed)
	$Center/Menu/QuitButton.visible = not OS.has_feature("web")
	$SettingsMenu.closed.connect(_on_settings_closed)
	$Center/Menu/PlayButton.grab_focus()


func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://src/game/web_match.tscn")


func _on_quit_pressed() -> void:
	get_tree().quit()


func _on_settings_pressed() -> void:
	$Center.visible = false
	$SettingsMenu.open()


func _on_settings_closed() -> void:
	$Center.visible = true
	$Center/Menu/SettingsButton.grab_focus()
