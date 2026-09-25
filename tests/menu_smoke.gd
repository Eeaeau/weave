extends SceneTree
## Check the retained title, settings, controls, and pause flow.


func _initialize() -> void:
	create_timer(30.0).timeout.connect(func() -> void: push_error("MENU TIMEOUT"); quit(2))
	call_deferred("_run")


func _run() -> void:
	var scene: PackedScene = load("res://src/features/ui/main_menu.tscn")
	var menu: MainMenu = scene.instantiate()
	root.add_child(menu)
	current_scene = menu
	await process_frame
	menu.get_node("Center/Menu/SettingsButton").pressed.emit()
	var settings: SettingsMenu = menu.get_node("SettingsMenu")
	if not settings.visible:
		_fail("Title settings did not open")
		return
	settings.get_node("Hub/Center/Menu/InputButton").pressed.emit()
	var controls: ControlsMenu = settings.get_node("ControlsMenu")
	if not controls.visible or controls.rows.get_child_count() != 1:
		_fail("Input page should document the working pause action")
		return
	controls.close_menu()
	settings.close_menu()
	menu.get_node("Center/Menu/PlayButton").pressed.emit()
	await process_frame
	await process_frame
	if not current_scene is WebMatch2D:
		_fail("Play did not open the 2D match")
		return
	var match_scene: WebMatch2D = current_scene
	var pause_menu: PauseMenu = match_scene.get_node("PauseMenu")
	pause_menu.show_pause()
	if not paused or not pause_menu.visible:
		_fail("Pause did not stop the match")
		return
	pause_menu.resume_game()
	if paused or pause_menu.visible:
		_fail("Resume did not restart the match")
		return
	pause_menu.get_node("Backdrop/Center/Menu/MainMenuButton").pressed.emit()
	await process_frame
	await process_frame
	if not current_scene is MainMenu:
		_fail("Main Menu did not return to title")
		return
	print("MENU PASS: title, settings, controls, play, pause, and return")
	quit(0)


func _fail(message: String) -> void:
	push_error("MENU FAIL: " + message)
	quit(1)
