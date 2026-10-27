# The actor exposes movement, inventory, web building and turn effects to the match.
# gdstyle:ignore-file=quality/max-public-methods
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
var network_controlled: bool = false
var match_finished := false
var burn_turns := 0
var _burn_tick_due := false
var _burn_visual: Node3D

@onready var selected_indicator: Sprite3D = $SelectedIndicator
@onready var aim_arrow: Node3D = $AimingArrow
@onready var hurtbox: Hurtbox3D = $Hurtbox3D
@onready var spider_rig: Node3D = $SpiderRig


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	super._ready()
	add_to_group("burnable_spiders")
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


func _process(delta: float) -> void:
	if not network_controlled:
		simulate(delta, PlayerCommand.from_input())


func simulate(delta: float, command: PlayerCommand) -> void:
	if match_finished:
		return

	if not webs.is_empty() and not is_on_web(Vector2(global_position.x, global_position.y)) \
			and health > 0:
		take_damage(1)

	update_presentation()
	if not is_active:
		return
	if not is_nan(command.final_aim):
		var margin := AIM_SPEED * PlayerCommand.MAX_TIMING_CORRECTION
		aim_angle = clampf(command.final_aim, aim_angle - margin, aim_angle + margin)
	if command.action_released and command.final_charge >= 0:
		var margin := PlayerCommand.MAX_TIMING_CORRECTION
		action_charged_time = clampf(command.final_charge,
			maxf(0.0, action_charged_time - margin), action_charged_time + margin)
	var aim_magnitude: float = 0.2 + (sin(action_charged_time * 2) + 1)
	var selected_weapon: Weapon3D = weapons[selected_weapon_idx]

	var movement_direction := command.movement_direction()
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

	if command.is_pressed("aim_left"):
		aim_angle += AIM_SPEED * delta
	if command.is_pressed("aim_right"):
		aim_angle -= AIM_SPEED * delta
	_update_weapon_pose()
	if command.action_pressed:
		action_charged_time = 0.0
	if command.action_released and n_remaining_actions > 0 and not command.cancel:
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

	if command.is_pressed("action"):
		action_charged_time += delta
	else:
		action_charged_time = 0

	var number_input := command.selection + 1
	if (number_input > 0 and not command.is_pressed("action")
			and number_input <= len(weapons)):
		select_weapon(number_input - 1)

	if selected_weapon is SilkBuildAction3D:
		if command.cycle > 0:
			silk_builder.cycle_silk_target(1)
		if command.cycle < 0:
			silk_builder.cycle_silk_target(-1)
		if command.cancel:
			cancel_silk_build()
		if selected_weapon_idx == 1:
			silk_builder.update_preview()
		else:
			silk_builder.hide_preview()
	else:
		if silk_builder:
			silk_builder.hide_preview()


func update_presentation() -> void:
	_update_burn_visual()
	selected_indicator.visible = is_active and health > 0
	aim_arrow.visible = selected_indicator.visible and selected_weapon_idx >= 2
	if aim_arrow.visible:
		aim_arrow.position = aim_arrow_offset.rotated(Vector3(0, 1, 0), aim_angle)
		aim_arrow.scale.x = 0.2 + (sin(action_charged_time * 2) + 1)
		aim_arrow.rotation.y = aim_angle
	_update_weapon_pose()
	if silk_builder:
		if is_active and selected_weapon_idx == 1:
			silk_builder.update_preview()
		else:
			silk_builder.hide_preview()


func is_on_web(pos: Vector2) -> bool:
	for web in webs:
		var triangles = web.get_triangles()

		for triangle in triangles:
			if Geometry2D.is_point_in_polygon(pos, PackedVector2Array(triangle)):
				return true

		# Face boundaries remain walkable strands after a triangle is filled.
		for edge in web.edges:
			if (edge.x < 0 or edge.x >= web.valid_nodes.size()
					or edge.y < 0 or edge.y >= web.valid_nodes.size()):
				continue
			var start := web.valid_nodes[edge.x]
			var end := web.valid_nodes[edge.y]
			if not is_instance_valid(start) or not is_instance_valid(end):
				continue
			if is_point_on_line_segment(pos,
					Vector2(start.global_position.x, start.global_position.y),
					Vector2(end.global_position.x, end.global_position.y), 0.15):
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


func get_movement_direction() -> Vector3:
	return PlayerCommand.from_input().movement_direction()


func is_done() -> bool:
	return n_remaining_actions <= 0 or is_dead()


func pick_up(collectible: Collectible3D) -> bool:
	if is_dead() or match_finished:
		return false
	if collectible.collectible is InsectData:
		var insect_data := collectible.collectible as InsectData
		silk_amount = mini(get_silk_capacity(), silk_amount + insect_data.silk_amount)
		health = minf(1.0, health + insect_data.health_amount)
		if insect_data.health_amount > 0:
			burn_turns = 0
			_burn_tick_due = false
		_update_burn_visual()
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
	if is_dead() or match_finished:
		return
	health -= damage
	if is_dead():
		burn_turns = 0
		is_active = false
		_update_burn_visual()
		visible = false
		hurtbox.set_deferred("monitorable", false)
		hurtbox.set_deferred("monitoring", false)


func is_dead() -> bool:
	return health <= 0


func ignite() -> void:
	if is_dead() or match_finished:
		return
	burn_turns = 3
	_burn_tick_due = false
	_update_burn_visual()


func begin_turn_effects() -> void:
	_burn_tick_due = burn_turns > 0


func end_turn_effects() -> void:
	if _burn_tick_due and burn_turns > 0 and not is_dead():
		burn_turns -= 1
		take_damage(0.1)
	_burn_tick_due = false
	_update_burn_visual()


func _update_burn_visual() -> void:
	if burn_turns > 0 and not is_dead():
		if not is_instance_valid(_burn_visual):
			_burn_visual = load(
				"res://src/features/collectibles/weapons/rocket_exhaust.tscn").instantiate()
			add_child(_burn_visual)
			_burn_visual.scale = Vector3(0.2, 0.22, 0.2)
			_burn_visual.global_basis = Basis.IDENTITY.scaled(_burn_visual.scale)
		_burn_visual.visible = true
	elif is_instance_valid(_burn_visual):
		_burn_visual.visible = false


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
