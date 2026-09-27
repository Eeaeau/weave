@tool
class_name HealthBar3D
extends Node3D

@export var max_health: float = 100.0

var current_health: float = 100

@onready var mesh: MeshInstance3D = $MeshInstance3D


func _ready() -> void:
	set_health(max_health)


func set_health(new_health: float) -> void:
	current_health = clamp(new_health, 0.0, max_health)
	var progress = current_health / max_health

	var mat = mesh.get_active_material(0) as ShaderMaterial
	if mat:
		mat.set_shader_parameter("health_progress", progress)
