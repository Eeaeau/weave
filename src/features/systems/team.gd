class_name Team extends Node3D

@export var webs: Array[Web3D] = []
@export var spider_scene: PackedScene
@export var home_web: Web3D

var spiders: Array[PlayerSpider3D] = []
var spawn_offset: Vector3 = Vector3(0.5, 0, 0)
var active_spider_idx: int = 0
var _network_controlled := false
var _turn_active := false


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if not _network_controlled:
		advance(delta)


func advance(_delta: float) -> void:
	if not _turn_active:
		return
	if not get_tree().get_nodes_in_group("camera_focus_projectiles").is_empty():
		return
	var active_spider: PlayerSpider3D = get_active_spider()
	if not active_spider or (not active_spider.is_active and not active_spider.is_dead()):
		return
	if active_spider.is_done():
		active_spider.deactivate()
		active_spider_idx += 1
		_skip_dead_spiders()
		active_spider = get_active_spider()
		if active_spider:
			active_spider.activate()


func spawn_spiders(number: int) -> void:
	_network_controlled = get_node("/root/OnlineSession").is_match_active()
	var spawn_position := Vector3.ZERO
	for i in range(number):
		var instance: PlayerSpider3D = spider_scene.instantiate()
		instance.position = spawn_position
		instance.webs = webs
		instance.network_controlled = _network_controlled
		add_child(instance)
		instance.call_deferred("set_build_web", home_web)
		spiders.append(instance)
		instance.deactivate()
		spawn_position += spawn_offset


func end_turn() -> void:
	_turn_active = false
	for spider in spiders:
		spider.is_active = false


func get_active_spider() -> PlayerSpider3D:
	if active_spider_idx >= len(spiders):
		return null
	return spiders[active_spider_idx]


func start_turn(energy_budget_per_spider: float) -> void:
	_turn_active = true
	for spider in spiders:
		spider.is_active = false
		spider.remaining_movement = energy_budget_per_spider
		spider.n_remaining_actions = 1
	active_spider_idx = 0
	for spider in spiders:
		spider.begin_turn_effects()
	_skip_dead_spiders()
	if active_spider_idx < spiders.size():
		spiders[active_spider_idx].is_active = true


func turn_is_done() -> bool:
	return active_spider_idx >= len(spiders)


func _skip_dead_spiders() -> void:
	while active_spider_idx < spiders.size() and spiders[active_spider_idx].is_dead():
		active_spider_idx += 1


func has_living_spiders() -> bool:
	return spiders.any(func(spider: PlayerSpider3D) -> bool: return not spider.is_dead())
