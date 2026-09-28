class_name BackgroundParallax3D
extends Node3D
## Gives orthographic background cards depth-dependent motion during camera pans.

@export var camera_path: NodePath = NodePath("../ParallaxCamera")
@export var plane_path: NodePath = NodePath("../WindEvent/WebPlane")
@export_range(0.0, 1.0, 0.01) var strength: float = 0.45

var _camera: Camera3D
var _camera_origin: Vector3
var _cards: Array[Dictionary] = []


func _ready() -> void:
	_camera = get_node_or_null(camera_path) as Camera3D
	var plane := get_node_or_null(plane_path) as Node3D
	if _camera == null or plane == null:
		set_process(false)
		return
	_camera_origin = _camera.global_position
	var normal := _camera.global_basis.z.normalized()
	var camera_depth := absf((_camera_origin - plane.global_position).dot(normal))
	for node in find_children("*", "Sprite3D", true, false):
		var card := node as Sprite3D
		var depth := maxf(0.0, (plane.global_position - card.global_position).dot(normal))
		_cards.append({
			"node": card,
			"origin": card.global_position,
			"factor": strength * depth / maxf(camera_depth + depth, 0.001),
		})


func _process(_delta: float) -> void:
	if not is_instance_valid(_camera):
		return
	var normal := _camera.global_basis.z.normalized()
	var pan := _camera.global_position - _camera_origin
	pan -= normal * pan.dot(normal)
	for card_data in _cards:
		var card: Sprite3D = card_data["node"]
		if is_instance_valid(card):
			card.global_position = card_data["origin"] + pan * card_data["factor"]
