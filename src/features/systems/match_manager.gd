class_name MatchManager extends Node

signal team_changed(previous_team, new_team)
signal new_round_started

@export var teams: Array[Team]
@export var match_hud: MatchHud
@export var wind_event: WindEvent3D
@export var n_spiders_per_team: int = 1
@export var movement_per_turn: float = 10

var active_team_idx: int = 0
var waiting_for_wind: bool = false
var _round_number: int = 0


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if wind_event:
		wind_event.event_finished.connect(_on_wind_event_finished)
	for team in teams:
		team.spawn_spiders(n_spiders_per_team)
		team.end_turn()  # doesn't hurt to be sure
	give_turn_to(0)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if waiting_for_wind:
		return
	var active_team: Team = teams[active_team_idx]
	if active_team.turn_is_done():
		var next_team_idx: int = (active_team_idx + 1) % len(teams)
		active_team = give_turn_to(next_team_idx)
		if active_team_idx == 0:
			new_round_started.emit()

	var active_spider: PlayerSpider3D = active_team.get_active_spider()
	if active_spider:
		match_hud.update_energy(active_spider.remaining_movement / movement_per_turn)
		match_hud.update_actions_remaining(active_spider.n_remaining_actions)
		match_hud.update_weapon(active_spider.weapons, active_spider.selected_weapon_idx)


func give_turn_to(team_idx: int) -> Team:
	if waiting_for_wind:
		return teams[active_team_idx]
	var previous_team_idx = active_team_idx
	teams[active_team_idx].end_turn()
	assert(team_idx < len(teams))
	active_team_idx = team_idx
	var active_team: Team = teams[active_team_idx]
	match_hud.update_team_label(active_team.name)
	team_changed.emit(previous_team_idx, active_team_idx)
	if active_team_idx == 0 and wind_event:
		waiting_for_wind = true
		_round_number += 1
		wind_event.start_round(_round_number)
	else:
		active_team.start_turn(movement_per_turn)
	return active_team


func _on_wind_event_finished(round_number: int) -> void:
	if not waiting_for_wind or round_number != _round_number:
		return
	waiting_for_wind = false
	teams[active_team_idx].start_turn(movement_per_turn)
