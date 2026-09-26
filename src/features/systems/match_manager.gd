class_name MatchManager extends Node

@export var is_active: bool = true

@export var spiderA: PlayerSpider3D
@export var spiderB: PlayerSpider3D
@export var match_hud: MatchHud

@export var movement_per_turn: float = 10

var active_spider: PlayerSpider3D

enum Team {A, B}

var active_team: Team = Team.A

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	spiderA.is_active = true
	spiderA.remaining_movement = movement_per_turn
	spiderB.is_active = false
	spiderB.remaining_movement = 0
	active_spider = spiderA

func next_team() -> void:
	if active_team == Team.A:
		spiderA.is_active = false
		spiderB.is_active = true
		spiderB.remaining_movement = movement_per_turn
		active_spider = spiderB
		active_team = Team.B
	elif active_team == Team.B:
		spiderB.is_active = false
		spiderA.is_active = true
		spiderA.remaining_movement = movement_per_turn
		active_spider = spiderA
		active_team = Team.A
	else:
		print("Unknown active team: {active_team}")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if not is_active:
		return
		
	match_hud.update_energy(active_spider.remaining_movement / movement_per_turn)
	if active_spider.remaining_movement <= 0:
		next_team()

	
