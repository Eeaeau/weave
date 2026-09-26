class_name MatchManager extends Node

@export var teams: Array[Team]
@export var match_hud: MatchHud
@export var n_spiders_per_team: int = 1
@export var movement_per_turn: float = 10

var active_team_idx: int = 0


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	for team in teams:
		team.spawn_spiders(n_spiders_per_team)
		team.end_turn()  # doesn't hurt to be sure
	give_turn_to(0)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	var active_team: Team = teams[active_team_idx]
	if active_team.turn_is_done():
		var next_team_idx: int = (active_team_idx + 1) % len(teams)
		active_team = give_turn_to(next_team_idx)

	var active_spider: PlayerSpider3D = active_team.get_active_spider()
	if active_spider:
		match_hud.update_energy(active_spider.remaining_movement / movement_per_turn)
		match_hud.update_actions_remaining(active_spider.n_remaining_actions)


func give_turn_to(team_idx: int) -> Team:
	teams[active_team_idx].end_turn()
	assert(team_idx < len(teams))
	active_team_idx = team_idx
	teams[active_team_idx].start_turn(movement_per_turn)
	var active_team: Team = teams[active_team_idx]
	match_hud.update_team_label(active_team.name)
	return active_team
