class_name Projectile3D extends Node3D

@export var damage: float = 0.0
@export var explosion_damage: float = 0.0
@export var hitbox: Area3D
@export var explosion_hitbox: Area3D
@export var explosion_sprite: SpriteBase3D
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


func _physics_process(delta: float) -> void:
	if freeze:
		return
	var next_position := global_position + velocity * delta
	var query := PhysicsRayQueryParameters3D.create(global_position, next_position, 3)
	var impact := get_world_3d().direct_space_state.intersect_ray(query)
	if not impact.is_empty():
		global_position = impact["position"]
		var spider := impact["collider"] as PlayerSpider3D
		hit(spider.hurtbox if spider else null)
		return
	global_position = next_position
	velocity.y -= 9.81 * delta
	if position.y <= 0:
		hit(null)


func hit(hurtbox: Hurtbox3D) -> void:
	if freeze:
		return
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


func get_all_children(node):
	var array = []
	array.push_back(node)
	for child in node.get_children():
		array.append_array(get_all_children(child))
	return array


func get_all_webs() -> Array[Web3D]:
	var array: Array[Web3D]
	var everything = get_all_children(get_tree().get_root())
	for thing in everything:
		if thing is Web3D:
			array.append(thing)
	return array


func explode() -> void:
	if not explosion_hitbox:
		queue_free()
		return
	if explosion_sprite:
		explosion_sprite.visible = true
	explosion_hitbox.set_deferred("disabled", false)

	var blast_radius: float = 0.0
	var hitbox_children = explosion_hitbox.get_children()
	for child in hitbox_children:
		if child is CollisionShape3D:
			if child.shape is SphereShape3D:
				blast_radius = child.shape.radius
				break

	var point2d: Vector2 = Vector2(position.x, position.z)
	var webs: Array[Web3D] = get_all_webs()
	for web in webs:
		web.deal_damage(point2d, blast_radius, explosion_damage)
	# TODO: should probably connect to animation ending instead
	# when we have animation
	get_tree().create_timer(0.5).timeout.connect(queue_free)


func _hitbox_entered(area: Area3D) -> void:
	if area is Hurtbox3D:
		hit(area)


func _explosion_hitbox_entered(area: Area3D) -> void:
	if area is Hurtbox3D:
		area.take_damage(explosion_damage)
