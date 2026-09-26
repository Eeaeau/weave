class_name WebMatch3D
extends Node3D
## Composes the 3D arena, actors, web, collectible markers, and reusable UI.

@onready var hud: MatchHud = $MatchHud
@onready var pause_settings: SettingsMenu = $PauseMenu/SettingsMenu


func _ready() -> void:
	hud.set_show_hints(pause_settings.hints_check.button_pressed)
	pause_settings.hints_changed.connect(hud.set_show_hints)
