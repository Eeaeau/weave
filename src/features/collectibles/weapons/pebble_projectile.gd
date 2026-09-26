class_name PebbleProjectile3D extends Node3D

var velocity: Vector3 = Vector3.ZERO


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	global_position += velocity * delta
	velocity.y -= 9.81 * delta
	if position.y < 0:
		queue_free()


func launch(direction: float, power: float) -> void:
	velocity = Vector3(1, 2, 0).rotated(Vector3(0, 1, 0), direction) * power


func _on_area_3d_area_entered(area: Area3D) -> void:
	var parent = area.get_parent_node_3d()
	if parent and parent is PlayerSpider3D:
		parent.take_damage(10)
		queue_free()
