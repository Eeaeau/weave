extends Camera3D
## Gentle camera sway reveals the distance between foreground and canopy.

@export var sway_distance: float = 0.45
@export var sway_speed: float = 0.65

var _origin_transform: Transform3D
var _elapsed: float = 0.0


func _ready() -> void:
	_origin_transform = transform


func _process(delta: float) -> void:
	_elapsed += delta
	var offset := sin(_elapsed * sway_speed) * sway_distance
	transform = _origin_transform.translated_local(Vector3(offset, 0.0, 0.0))
