class_name GameOverMenu
extends CanvasLayer
## Minimal lose/retry example. The gameplay root opens it when the player dies.


func _ready() -> void:
	visible = false
	$Backdrop/Center/Menu/RetryButton.pressed.connect(_on_retry_pressed)
	$Backdrop/Center/Menu/MainMenuButton.pressed.connect(_on_main_menu_pressed)


func show_game_over() -> void:
	visible = true
	get_tree().paused = true
	$Backdrop/Center/Menu/RetryButton.grab_focus()


func _on_retry_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_main_menu_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://src/features/ui/main_menu.tscn")
