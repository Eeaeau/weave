class_name PebbleProjectile3D extends CharacterBody3D

const GRAVITY: float = 9.81


func _ready() -> void:
	add_to_group("camera_focus_projectiles")


func _physics_process(delta: float) -> void:
	velocity.y -= GRAVITY * delta
	var collision := move_and_collide(velocity * delta)
	if collision:
		_handle_impact(collision.get_collider())
	elif global_position.y < -1.0:
		queue_free()


func launch(direction: float, power: float) -> void:
	velocity = Vector3(4, 2, 0).rotated(Vector3(0, 1, 0), direction) * power


func _handle_impact(collider: Object) -> void:
	var spider := collider as PlayerSpider3D
	if spider:
		spider.hurtbox.take_damage(10)
	queue_free()
