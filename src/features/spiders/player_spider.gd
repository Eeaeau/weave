class_name PlayerSpider3D
extends BaseSpider3D

const AIM_SPEED: float = 3.0
const MOVE_SPEED: float = 2.0

@export var is_active: bool = false
@export var n_remaining_actions: int = 0

var remaining_movement: float = 0
var aim_angle: float = 0
var action_charged_time: float = 0
var charging_action: bool = false
var aim_arrow_offset: Vector3 = Vector3(0.75, 0, 0)
var weapons: Array[Weapon3D]
var selected_weapon_idx: int = 0
var scene_weapon_no_action = preload(
	"res://src/features/collectibles/weapons/weapon_no_action.tscn")
var health: float = 1.0

@onready var selected_indicator: Sprite3D = $SelectedIndicator
@onready var aim_arrow: Node3D = $AimingArrow
@onready var hitbox: Area3D = $Hitbox


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	aim_arrow_offset = aim_arrow.position
	assert(aim_arrow, "PlayerSpider3D {0} needs aim_arrow".format([name]))
	assert(selected_indicator, "PlayerSpider3D {0} needs selected_indicator".format([name]))
	var no_action = scene_weapon_no_action.instantiate()
	add_child(no_action)
	pick_up(no_action)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if not is_active:
		selected_indicator.visible = false
		aim_arrow.visible = false
		return

	selected_indicator.visible = true

	var aim_magnitude: float = 0.2 + (sin(action_charged_time * 2) + 1)

	var selected_weapon: Weapon3D = weapons[selected_weapon_idx]
	if not selected_weapon or selected_weapon is WeaponNoAction:
		aim_arrow.visible = false
	else:
		aim_arrow.visible = true
		aim_arrow.position = aim_arrow_offset.rotated(Vector3(0, 1, 0), aim_angle)
		aim_arrow.scale.x = aim_magnitude
		aim_arrow.rotation.y = aim_angle

	var velocity = get_movement_direction() * MOVE_SPEED
	if velocity.length() > 0:
		if remaining_movement > 0:
			var to_move = velocity * delta
			if to_move.length() > remaining_movement:
				to_move = to_move.normalized() * remaining_movement
			remaining_movement -= to_move.length()
			position += to_move

	if Input.is_action_pressed("aim_left"):
		aim_angle += AIM_SPEED * delta
	if Input.is_action_pressed("aim_right"):
		aim_angle -= AIM_SPEED * delta
	if Input.is_action_just_pressed("action"):
		charging_action = true
	if Input.is_action_just_released("action"):
		charging_action = false
		if selected_weapon:
			selected_weapon.fire(aim_angle, aim_magnitude)
			if selected_weapon.is_used_up():
				weapons.remove_at(selected_weapon_idx)
				remove_child(selected_weapon)
				selected_weapon_idx = 0

		n_remaining_actions -= 1

	if charging_action:
		action_charged_time += delta
	else:
		action_charged_time = 0

	var number_input = get_number_input()
	if number_input > 0 and not charging_action and number_input <= len(weapons):
		selected_weapon_idx = number_input - 1
		print("selected " + str(selected_weapon_idx))


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
	return -1


func get_movement_direction() -> Vector3:
	var direction = Vector3.ZERO
	if Input.is_action_pressed("move_left"):
		direction.x -= 1
	if Input.is_action_pressed("move_right"):
		direction.x += 1
	if Input.is_action_pressed("move_up"):
		direction.z -= 1
	if Input.is_action_pressed("move_down"):
		direction.z += 1
	return direction.normalized()


func is_done() -> bool:
	return n_remaining_actions <= 0 or is_dead()


func pick_up(collectible: Collectible3D) -> bool:
	if collectible is Weapon3D:
		collectible.call_deferred("reparent", self)
		weapons.append(collectible)
	return true


func take_damage(damage: float) -> void:
	print("ouch")
	health -= damage
	if is_dead():
		visible = false
		hitbox.monitorable = false
		hitbox.monitoring = false


func is_dead() -> bool:
	return health <= 0
