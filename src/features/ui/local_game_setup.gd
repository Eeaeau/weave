extends Control

signal closed

const OPTIONS := preload("res://src/game/match_options.gd")

@onready var options: PanelContainer = $Center/Menu/MatchOptions


func _ready() -> void:
	%BackButton.pressed.connect(_back)
	%PlayButton.pressed.connect(_play)
	options.set_values(OPTIONS.defaults(), true, "Wind blows at the start of each round.")


func open() -> void:
	show()
	%PlayButton.grab_focus()


func _back() -> void:
	hide()
	closed.emit()


func _play() -> void:
	if OPTIONS.queue_local(get_tree(), options.get_values()):
		get_tree().change_scene_to_file("res://src/game/web_match.tscn")
