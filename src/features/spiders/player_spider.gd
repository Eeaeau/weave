class_name PlayerSpider3D
extends BaseSpider3D
## Player-specific behavior can be added here when match rules are chosen.

@export var is_active: bool = true
@export var speed = 2

var remaining_movement: float = 0

@onready var selected_indicator: Sprite3D = $SelectedIndicator


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if not is_active:
		selected_indicator.visible = false
		return
	selected_indicator.visible = true

	var velocity = Vector3.ZERO

	if Input.is_action_pressed("move_left"):
		velocity.x -= 1
	if Input.is_action_pressed("move_right"):
		velocity.x += 1
	if Input.is_action_pressed("move_up"):
		velocity.z -= 1
	if Input.is_action_pressed("move_down"):
		velocity.z += 1

	if velocity.length() > 0:
		velocity = velocity.normalized() * speed
		if remaining_movement > 0:
			var to_move = velocity * delta
			if to_move.length() > remaining_movement:
				to_move = to_move.normalized() * remaining_movement
			remaining_movement -= to_move.length()
			position += to_move
