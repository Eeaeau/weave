class_name WebMatch2D
extends Node2D
## Composes the arena, actors, web, weapon marker, and reusable UI.

@onready var hud: MatchHud = $MatchHud
@onready var pause_settings: SettingsMenu = $PauseMenu/SettingsMenu


func _ready() -> void:
	hud.set_show_hints(pause_settings.hints_check.button_pressed)
	pause_settings.hints_changed.connect(hud.set_show_hints)
