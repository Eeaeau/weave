class_name Projectile3D extends Node3D

@export var damage: float = 0.0
@export var explosion_damage: float = 0.0
@export_range(0.1, 3.0, 0.1) var launch_speed_multiplier: float = 1.0
@export var hitbox: Area3D
@export var explosion_hitbox: Area3D
@export var explosion_sprite: SpriteBase3D
@export var hide_on_hit: Array[Node3D]
@export_range(0.0, 3.0, 0.1) var launch_ally_grace_distance: float = 1.5
@export var despawn_below_y: float = -20.0

var velocity: Vector3 = Vector3.ZERO
var freeze: bool = false
var ready_for_removal: bool = false
var source_hurtbox: Hurtbox3D
var _launch_position: Vector3


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	add_to_group("camera_focus_projectiles")
	hitbox.area_entered.connect(_hitbox_entered)
	if explosion_hitbox:
		explosion_hitbox.area_entered.connect(_explosion_hitbox_entered)
		explosion_hitbox.monitoring = false
		explosion_hitbox.monitorable = false
	if explosion_sprite:
		explosion_sprite.visible = false


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if freeze:
		return
	global_position += velocity * delta
	velocity.y -= 9.81 * delta
	if global_position.y <= despawn_below_y:
		hit(null)


func hit(hurtbox: Hurtbox3D) -> void:
	if freeze:
		return
	for node in hide_on_hit:
		node.visible = false
	freeze = true
	if hurtbox:
		hurtbox.take_damage(damage)

	hitbox.set_deferred("monitorable", false)
	hitbox.set_deferred("monitoring", false)
	explode()


func launch(direction: float, power: float) -> void:
	_launch_position = global_position
	velocity = (Vector3(4.0 * cos(direction), 4.0 * sin(direction) + 2.0, 0.0)
		* power * launch_speed_multiplier)
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
	explosion_hitbox.set_deferred("monitoring", true)

	var blast_radius: float = 0.0
	var hitbox_children = explosion_hitbox.get_children()
	for child in hitbox_children:
		if child is CollisionShape3D:
			if child.shape is SphereShape3D:
				blast_radius = child.shape.radius
				break

	var point2d: Vector2 = Vector2(global_position.x, global_position.y)
	var webs: Array[Web3D] = get_all_webs()
	for web in webs:
		web.deal_damage(point2d, blast_radius, explosion_damage)
	# TODO: should probably connect to animation ending instead
	# when we have animation
	get_tree().create_timer(0.5).timeout.connect(queue_free)


func _hitbox_entered(area: Area3D) -> void:
	var target := area as Hurtbox3D
	if target == null or target == source_hurtbox:
		return
	if (global_position.distance_to(_launch_position) < launch_ally_grace_distance
			and _is_shooter_teammate(target)):
		return
	hit(target)


func _is_shooter_teammate(target: Hurtbox3D) -> bool:
	if not is_instance_valid(source_hurtbox):
		return false
	var shooter := source_hurtbox.get_parent() as PlayerSpider3D
	var other_spider := target.get_parent() as PlayerSpider3D
	return (shooter != null and other_spider != null
		and shooter.get_parent() is Team
		and shooter.get_parent() == other_spider.get_parent())


func _explosion_hitbox_entered(area: Area3D) -> void:
	if area is Hurtbox3D:
		area.take_damage(explosion_damage)
