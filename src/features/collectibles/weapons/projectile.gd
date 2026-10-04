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
	var start := global_position
	var destination := start + velocity * delta
	var contact := _first_plane_hit(start, destination)
	if not contact.is_empty():
		global_position = start.lerp(destination, contact["fraction"])
		_hitbox_entered(contact["area"])
		if freeze:
			return
	global_position = destination
	velocity.y -= 9.81 * delta
	if global_position.y <= despawn_below_y:
		hit(null)


## Sweeps across the gameplay plane so display depth and frame rate cannot skip targets.
func _first_plane_hit(start: Vector3, destination: Vector3) -> Dictionary:
	var from := Vector2(start.x, start.y)
	var to := Vector2(destination.x, destination.y)
	var projectile_radius := _projectile_plane_radius()
	var earliest := 2.0
	var result: Dictionary = {}
	for node in get_tree().get_nodes_in_group("projectile_plane_targets"):
		var area := node as Area3D
		if area == null or not is_instance_valid(area) or not area.monitorable \
				or area.is_queued_for_deletion():
			continue
		if (area.collision_layer & hitbox.collision_mask) == 0:
			continue
		var center := _target_plane_center(area)
		var target_radius := _target_plane_radius(area)
		var fraction := _segment_circle_contact(from, to, center,
			target_radius + projectile_radius)
		if fraction < 0.0 or fraction >= earliest:
			continue
		var contact_position := start.lerp(destination, fraction)
		if not _can_hit_area(area, contact_position):
			continue
		earliest = fraction
		result = { "area": area, "fraction": fraction }
	return result


func _projectile_plane_radius() -> float:
	for child in hitbox.get_children():
		var collider := child as CollisionShape3D
		if collider != null and collider.shape is SphereShape3D:
			var scale_factor := maxf(collider.global_basis.x.length(),
				collider.global_basis.y.length())
			return (collider.shape as SphereShape3D).radius * scale_factor
	return 0.0


func _target_plane_radius(area: Area3D) -> float:
	if area is Hurtbox3D:
		return (area as Hurtbox3D).plane_hit_radius
	return float(area.get_meta("plane_hit_radius", 0.0))


func _target_plane_center(area: Area3D) -> Vector2:
	for child in area.get_children():
		if child is CollisionShape3D:
			return Vector2(child.global_position.x, child.global_position.y)
	return Vector2(area.global_position.x, area.global_position.y)


func _segment_circle_contact(start: Vector2, end: Vector2, center: Vector2,
		radius: float) -> float:
	var offset := start - center
	if offset.length_squared() <= radius * radius:
		return 0.0
	var motion := end - start
	var motion_squared := motion.length_squared()
	if is_zero_approx(motion_squared):
		return -1.0
	var along := offset.dot(motion)
	var discriminant := along * along - motion_squared * (
		offset.length_squared() - radius * radius)
	if discriminant < 0.0:
		return -1.0
	var fraction := (-along - sqrt(discriminant)) / motion_squared
	return fraction if fraction >= 0.0 and fraction <= 1.0 else -1.0


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
	if not _can_hit_area(area, global_position):
		return
	if area.is_in_group("web_anchor_hitboxes"):
		hit(null)
		return
	var target := area as Hurtbox3D
	hit(target)


func _can_hit_area(area: Area3D, contact_position: Vector3) -> bool:
	var contact_2d := Vector2(contact_position.x, contact_position.y)
	var launch_2d := Vector2(_launch_position.x, _launch_position.y)
	var within_grace := contact_2d.distance_to(launch_2d) < launch_ally_grace_distance
	if area.is_in_group("web_anchor_hitboxes"):
		return not is_instance_valid(source_hurtbox) or not within_grace
	var target := area as Hurtbox3D
	if target == null or target == source_hurtbox:
		return false
	return not (within_grace and _is_shooter_teammate(target))


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
