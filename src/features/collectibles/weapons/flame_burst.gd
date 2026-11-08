class_name FlameBurst3D
extends Node3D

const DURATION := 0.65

var _elapsed := 0.0


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= DURATION:
		queue_free()


func configure(point: Vector3, direction: float, reach: float) -> void:
	global_position = point
	global_basis = Basis(Vector3.BACK, direction - PI / 2.0)
	var flame: Node3D = load(
		"res://src/features/collectibles/weapons/rocket_exhaust.tscn").instantiate()
	add_child(flame)
	flame.scale = Vector3(0.28, reach / 2.79, 1.0)
	add_to_group("camera_focus_projectiles")
	if get_node("/root/OnlineSession").is_match_active():
		set_process(get_node("/root/GDSync").get_client_id()
			!= get_node("/root/OnlineSession").host_id)
