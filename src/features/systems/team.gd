class_name Team extends Node3D

@export var spider_scene: PackedScene

var spiders: Array[PlayerSpider3D] = []
var spawn_offset: Vector3 = Vector3(0.5, 0, 0)
var active_spider_idx: int = 0


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	var active_spider: PlayerSpider3D = get_active_spider()
	if not active_spider:
		return
	if active_spider.remaining_movement <= 0:
		active_spider.is_active = false
		active_spider_idx += 1
	else:
		active_spider.is_active = true


func spawn_spiders(number: int) -> void:
	var spawn_position: Vector3 = self.position
	for i in range(number):
		var instance: PlayerSpider3D = spider_scene.instantiate()
		instance.position = spawn_position
		add_child(instance)
		spiders.append(instance)
		spawn_position += spawn_offset


func end_turn() -> void:
	for spider in spiders:
		spider.is_active = false


func get_active_spider() -> PlayerSpider3D:
	if active_spider_idx >= len(spiders):
		return null
	return spiders[active_spider_idx]


func start_turn(energy_budget_per_spider: float) -> void:
	for spider in spiders:
		spider.is_active = false
		spider.remaining_movement = energy_budget_per_spider
	active_spider_idx = 0
	if len(spiders) > 0:
		spiders[active_spider_idx].is_active = true


func turn_is_done() -> bool:
	return active_spider_idx >= len(spiders)
