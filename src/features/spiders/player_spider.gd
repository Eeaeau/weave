class_name PlayerSpider3D
extends BaseSpider3D

const AIM_SPEED: float = 3.0
const MOVE_SPEED: float = 2.0
const SILK_CAPACITY: int = 5
const STARTING_SILK: int = 3

@export var is_active: bool = false
@export var n_remaining_actions: int = 0
@export_range(0, 20) var silk_amount: int = STARTING_SILK
@export var webs: Array[Web3D] = []

var remaining_movement: float = 0
var aim_angle: float = 0
var action_charged_time: float = 0
var aim_arrow_offset: Vector3 = Vector3(0.75, 0, 0)
var weapons: Array[Weapon3D]
var selected_weapon_idx: int = 0
var health: float = 1.0
var silk_builder: SilkBuildAction3D

@onready var selected_indicator: Sprite3D = $SelectedIndicator
@onready var aim_arrow: Node3D = $AimingArrow
@onready var hurtbox: Hurtbox3D = $Hurtbox3D
@onready var spider_rig: Node3D = $SpiderRig


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	super._ready()
	aim_arrow_offset = aim_arrow.position
	assert(aim_arrow, "PlayerSpider3D {0} needs aim_arrow".format([name]))
	assert(selected_indicator, "PlayerSpider3D {0} needs selected_indicator".format([name]))
	var no_action = load(
		"res://src/features/collectibles/weapons/weapon_no_action.tscn"
	).instantiate()
	add_child(no_action)
	pick_up(no_action)
	var silk_action := load(
		"res://src/features/collectibles/weapons/silk_build_action.tscn"
	).instantiate() as SilkBuildAction3D
	silk_builder = silk_action
	add_child(silk_action)
	weapons.insert(1, silk_action)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:

	if not webs.is_empty() and not is_on_web(Vector2(global_position.x, global_position.y)) \
			and health > 0:
		take_damage(1)

	if not is_active:
		selected_indicator.visible = false
		aim_arrow.visible = false
		if silk_builder:
			silk_builder.hide_preview()
		return

	selected_indicator.visible = true

	var aim_magnitude: float = 0.2 + (sin(action_charged_time * 2) + 1)

	var selected_weapon: Weapon3D = weapons[selected_weapon_idx]
	if not selected_weapon or selected_weapon is WeaponNoAction:
		aim_arrow.visible = false
	elif selected_weapon is SilkBuildAction3D:
		aim_arrow.visible = false
	else:
		aim_arrow.visible = true
		aim_arrow.position = aim_arrow_offset.rotated(Vector3(0, 1, 0), aim_angle)
		aim_arrow.scale.x = aim_magnitude
		aim_arrow.rotation.y = aim_angle

	var movement_direction := get_movement_direction()
	if not movement_direction.is_zero_approx():
		spider_rig.rotation.y = atan2(movement_direction.x, -movement_direction.y)
	var velocity = movement_direction * MOVE_SPEED
	if velocity.length() > 0:
		if remaining_movement > 0:
			var to_move = velocity * delta
			if to_move.length() > remaining_movement:
				to_move = to_move.normalized() * remaining_movement

			var new_position := Vector2(
				global_position.x + to_move.x,
				global_position.y + to_move.y,
			)

			if is_on_web(new_position):
				remaining_movement -= to_move.length()
				global_position += to_move

	if Input.is_action_pressed("aim_left"):
		aim_angle += AIM_SPEED * delta
	if Input.is_action_pressed("aim_right"):
		aim_angle -= AIM_SPEED * delta
	_update_weapon_pose()
	if Input.is_action_just_pressed("action"):
		action_charged_time = 0.0
	if Input.is_action_just_released("action"):
		if selected_weapon is SilkBuildAction3D:
			silk_builder.try_build_selected_silk()
		elif selected_weapon:
			selected_weapon.fire(aim_angle, aim_magnitude)
			if selected_weapon.is_used_up():
				weapons.remove_at(selected_weapon_idx)
				selected_weapon.queue_free()
				select_weapon(0)
				selected_weapon = weapons[selected_weapon_idx]
			n_remaining_actions -= 1

	if Input.is_action_pressed("action"):
		action_charged_time += delta
	else:
		action_charged_time = 0

	var number_input = get_number_input()
	if (number_input > 0 and not Input.is_action_pressed("action")
			and number_input <= len(weapons)):
		select_weapon(number_input - 1)

	if selected_weapon is SilkBuildAction3D:
		if Input.is_action_just_pressed("cycle_silk_target_next"):
			silk_builder.cycle_silk_target(1)
		if Input.is_action_just_pressed("cycle_silk_target_previous"):
			silk_builder.cycle_silk_target(-1)
		if Input.is_action_just_pressed("cancel_silk_build"):
			cancel_silk_build()
		if selected_weapon_idx == 1:
			silk_builder.update_preview()
		else:
			silk_builder.hide_preview()
	else:
		if silk_builder:
			silk_builder.hide_preview()


func is_on_web(pos: Vector2) -> bool:
	for web in webs:
		var triangles = web.get_triangles()
		var stand_alone_edges = web.get_stand_alone_edges()

		for triangle in triangles:
			if Geometry2D.is_point_in_polygon(pos, PackedVector2Array(triangle)):
				return true

		for stand_alone_edge in stand_alone_edges:
			if is_point_on_line_segment(pos, stand_alone_edge[0],
			stand_alone_edge[1], 0.15):
				return true

	return false


func is_point_on_line_segment(p: Vector2, a: Vector2, b: Vector2, margin: float) -> bool:
	var ab = b - a
	var ap = p - a
	var line_len_squared = ab.length_squared()

	# Prevent division by zero if point A and point B are the same
	if line_len_squared == 0.0:
		return p.distance_to(a) <= margin

	# Find the projection of point P onto the line (clamped between 0.0 and 1.0)
	var t = clamp(ap.dot(ab) / line_len_squared, 0.0, 1.0)

	# Find the closest point on the segment
	var closest_point = a + ab * t

	# Check if the distance from P to the closest point is within the margin
	return p.distance_to(closest_point) <= margin


func activate() -> void:
	is_active = true


func deactivate() -> void:
	is_active = false


func get_number_input() -> int:
	if Input.is_action_just_pressed("select_1"):
		return 1
	if Input.is_action_just_pressed("select_2"):
		return 2
	if Input.is_action_just_pressed("select_3"):
		return 3
	if Input.is_action_just_pressed("select_4"):
		return 4
	if Input.is_action_just_pressed("select_5"):
		return 5
	return -1


func get_movement_direction() -> Vector3:
	var direction = Vector3.ZERO
	if Input.is_action_pressed("move_left"):
		direction.x -= 1
	if Input.is_action_pressed("move_right"):
		direction.x += 1
	if Input.is_action_pressed("move_up"):
		direction.y += 1
	if Input.is_action_pressed("move_down"):
		direction.y -= 1
	return direction.normalized()


func is_done() -> bool:
	return n_remaining_actions <= 0 or is_dead()


func pick_up(collectible: Collectible3D) -> bool:
	if collectible.collectible is InsectData:
		var insect_data := collectible.collectible as InsectData
		silk_amount = mini(get_silk_capacity(), silk_amount + insect_data.silk_amount)
		health = minf(1.0, health + insect_data.health_amount)
		return true
	if collectible is Weapon3D:
		weapons.append(collectible)
		call_deferred("_attach_weapon", collectible)
		return true
	return false


func select_weapon(index: int) -> bool:
	if index < 0 or index >= weapons.size():
		return false
	selected_weapon_idx = index
	_sync_equipped_weapon_visuals()
	return true


func _attach_weapon(weapon: Weapon3D) -> void:
	if not is_instance_valid(weapon):
		return
	weapon.reparent(_get_weapon_equip_target())
	weapon.transform = Transform3D.IDENTITY
	_sync_equipped_weapon_visuals()


func _sync_equipped_weapon_visuals() -> void:
	var equip_target := _get_weapon_equip_target()
	for index in range(weapons.size()):
		var weapon := weapons[index]
		if is_instance_valid(weapon) and weapon.get_parent() == equip_target:
			weapon.visible = index == selected_weapon_idx and not weapon is WeaponNoAction


func _update_weapon_pose() -> void:
	_get_weapon_equip_target().global_basis = Basis(Vector3.BACK, aim_angle)


func _get_weapon_equip_target() -> Marker3D:
	return get_node("SpiderRig/BoneAttachment3D/BodyOffset/WeaponEquipTarget") as Marker3D


func take_damage(damage: float) -> void:
	print("ouch")
	health -= damage
	if is_dead():
		visible = false
		hurtbox.set_deferred("monitorable", false)
		hurtbox.set_deferred("monitoring", false)


func is_dead() -> bool:
	return health <= 0


func _on_hurtbox_3d_hurt(damage: float) -> void:
	take_damage(damage)


func get_silk_capacity() -> int:
	return SILK_CAPACITY


func refresh_silk_build_options() -> void:
	silk_builder.refresh_silk_build_options()


func set_build_web(web: Web3D) -> void:
	if silk_builder:
		silk_builder.set_build_web(web)


func cycle_silk_target(direction: int) -> void:
	silk_builder.cycle_silk_target(direction)


## Cancels targeting by returning to the permanent pass option without spending anything.
func cancel_silk_build() -> void:
	select_weapon(0)
	silk_builder.hide_preview()


func try_build_selected_silk() -> bool:
	return silk_builder.try_build_selected_silk()


func build_silk_strand(web: Web3D, source_index: int, target_index: int) -> bool:
	return silk_builder.build_silk_strand(web, source_index, target_index)
