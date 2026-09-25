class_name PauseMenu
extends CanvasLayer
## Processes input while the gameplay tree is paused.


func _ready() -> void:
	visible = false
	$Backdrop/Center/Menu/ResumeButton.pressed.connect(resume_game)
	$Backdrop/Center/Menu/SettingsButton.pressed.connect(_on_settings_pressed)
	$Backdrop/Center/Menu/MainMenuButton.pressed.connect(_on_main_menu_pressed)
	$Backdrop/Center/Menu/QuitButton.pressed.connect(_on_quit_pressed)
	$Backdrop/Center/Menu/QuitButton.visible = not OS.has_feature("web")
	$SettingsMenu.closed.connect(_on_settings_closed)


func _unhandled_input(event: InputEvent) -> void:
	if $SettingsMenu.visible:
		if $SettingsMenu/ControlsMenu.visible:
			return
		if ((event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"))
				and not event.is_echo()):
			$SettingsMenu.back()
			get_viewport().set_input_as_handled()
		return
	if get_tree().paused and not visible:
		return
	if event.is_action_pressed("pause") and not event.is_echo():
		if visible:
			resume_game()
		else:
			show_pause()
		get_viewport().set_input_as_handled()


func show_pause() -> void:
	visible = true
	get_tree().paused = true
	$Backdrop/Center/Menu/ResumeButton.grab_focus()


func resume_game() -> void:
	visible = false
	get_tree().paused = false


func _on_main_menu_pressed() -> void:
	resume_game()
	get_tree().change_scene_to_file("res://src/features/ui/main_menu.tscn")


func _on_quit_pressed() -> void:
	get_tree().paused = false
	get_tree().quit()


func _on_settings_pressed() -> void:
	$Backdrop.visible = false
	$SettingsMenu.open()


func _on_settings_closed() -> void:
	$Backdrop.visible = true
	$Backdrop/Center/Menu/SettingsButton.grab_focus()
