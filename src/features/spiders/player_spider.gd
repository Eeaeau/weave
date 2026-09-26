class_name PlayerSpider3D
extends BaseSpider3D

const AIM_ARROW_OFFSET: Vector3 = Vector3(0.75, 0, 0)
const AIM_SPEED: float = 3.0

## Player-specific behavior can be added here when match rules are chosen.

@export var is_active: bool = true
@export var speed = 2
@export var n_remaining_actions: int = 0

var remaining_movement: float = 0
var aim_angle: float = 0
var aim_magnitude: float = 0

@onready var selected_indicator: Sprite3D = $SelectedIndicator
@onready var aim_arrow: Sprite3D = $AimingArrow


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if not is_active:
		selected_indicator.visible = false
		aim_arrow.visible = false
		return
	selected_indicator.visible = true
	aim_arrow.visible = true
	aim_arrow.position = AIM_ARROW_OFFSET.rotated(Vector3(0, 1, 0), aim_angle)
	aim_arrow.rotation.y = aim_angle

	var velocity = get_movement_direction() * speed
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
		n_remaining_actions -= 1


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
