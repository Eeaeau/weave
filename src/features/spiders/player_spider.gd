class_name PlayerSpider3D
extends BaseSpider3D

const AIM_SPEED: float = 3.0
const MOVE_SPEED: float = 2.0

## Player-specific behavior can be added here when match rules are chosen.

@export var is_active: bool = false
@export var n_remaining_actions: int = 0

var remaining_movement: float = 0
var aim_angle: float = 0
var action_charged_time: float = 0
var charging_action: bool = false
var aim_arrow_offset: Vector3 = Vector3(0.75, 0, 0)

@onready var selected_indicator: Sprite3D = $SelectedIndicator
@onready var aim_arrow: Node3D = $AimingArrow


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	aim_arrow_offset = aim_arrow.position


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if not is_active:
		selected_indicator.visible = false
		aim_arrow.visible = false
		return
	if selected_indicator:
		selected_indicator.visible = true
	if aim_arrow:
		aim_arrow.visible = true
		aim_arrow.position = aim_arrow_offset.rotated(Vector3(0, 1, 0), aim_angle)
		var aim_magnitude: float = 0.2 + (sin(action_charged_time * 2) + 1)
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
		n_remaining_actions -= 1

	if charging_action:
		action_charged_time += delta
	else:
		action_charged_time = 0


func activate() -> void:
	is_active = true


func deactivate() -> void:
	is_active = false


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
	return n_remaining_actions <= 0
