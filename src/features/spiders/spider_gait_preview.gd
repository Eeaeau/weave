extends Node3D
## Freely moves a regular spider so its leg gait can be tuned without web rules.

@export_range(0.1, 10.0, 0.1) var move_speed := 2.0

@onready var spider: BaseSpider3D = $Spider
@onready var spider_rig: Node3D = $Spider/SpiderRig


func _process(delta: float) -> void:
	var direction := Vector3(
		Input.get_axis("move_left", "move_right"),
		0.0,
		Input.get_axis("move_up", "move_down")
	)
	move_spider(direction, delta)


func move_spider(direction: Vector3, delta: float) -> void:
	direction.y = 0.0
	if direction.is_zero_approx():
		return
	direction = direction.normalized()
	spider.position += direction * move_speed * delta
	spider_rig.rotation.y = atan2(direction.x, direction.z)
