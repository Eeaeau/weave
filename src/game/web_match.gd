class_name WebMatch3D
extends Node3D
## Composes the 3D arena, actors, web, collectible markers, and reusable UI.

var _round_number: int = 0

@onready var hud: MatchHud = $MatchHud
@onready var pause_settings: SettingsMenu = $PauseMenu/SettingsMenu


func _ready() -> void:
	hud.set_show_hints(pause_settings.hints_check.button_pressed)
	pause_settings.hints_changed.connect(hud.set_show_hints)


func _on_match_manager_team_changed(_previous_team: int, new_team: int) -> void:
	if new_team != 0:
		return
	_round_number += 1
	$BranchCanopy/WindEvent.start_round(_round_number)
