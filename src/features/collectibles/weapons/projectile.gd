class_name Projectile3D extends Node3D

@export var damage: float = 0.0
@export var explosion_damage: float = 0.0
@export var hitbox: Area3D
@export var explosion_hitbox: Area3D
@export var explosion_sprite: Sprite3D
@export var hide_on_hit: Array[Node3D]

var velocity: Vector3 = Vector3.ZERO
var freeze: bool = false
var ready_for_removal: bool = false


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	add_to_group("camera_focus_projectiles")
	hitbox.area_entered.connect(_hitbox_entered)
	if explosion_hitbox:
		explosion_hitbox.area_entered.connect(_explosion_hitbox_entered)
		explosion_hitbox.set_deferred("disabled", true)
	if explosion_sprite:
		explosion_sprite.visible = false


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if not freeze:
		global_position += velocity * delta
		velocity.y -= 9.81 * delta
	if position.y <= 0:
		hit(null)


func hit(hurtbox: Hurtbox3D) -> void:
	for node in hide_on_hit:
		node.visible = false
	freeze = true
	if hurtbox:
		hurtbox.take_damage(damage)

	hitbox.set_deferred("monitorable", true)
	hitbox.set_deferred("monitoring", true)
	explode()


func launch(direction: float, power: float) -> void:
	velocity = Vector3(4, 2, 0).rotated(Vector3(0, 1, 0), direction) * power
	rotate_y(direction)


func explode() -> void:
	if not explosion_hitbox:
		queue_free()
		return
	if explosion_sprite:
		explosion_sprite.visible = true
	explosion_hitbox.set_deferred("disabled", false)

	# TODO: should probably connect to animation ending instead
	# when we have animation
	get_tree().create_timer(1.0).timeout.connect(queue_free)


func _hitbox_entered(area: Area3D) -> void:
	if area is Hurtbox3D:
		hit(area)


func _explosion_hitbox_entered(area: Area3D) -> void:
	if area is Hurtbox3D:
		area.take_damage(explosion_damage)
