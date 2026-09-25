extends Camera3D
## Gentle camera sway reveals the distance between foreground and canopy.

@export var sway_distance: float = 0.45
@export var sway_speed: float = 0.65

var _origin: Vector3
var _elapsed: float = 0.0


func _ready() -> void:
	_origin = position
	look_at(Vector3.ZERO)


func _process(delta: float) -> void:
	_elapsed += delta
	position.x = _origin.x + sin(_elapsed * sway_speed) * sway_distance
	look_at(Vector3.ZERO)
