class_name BranchCanopy3D
extends Node3D
## Layered 2D artwork placed at several depths in the 3D arena.

const BRANCH_WIGGLE_AMPLITUDE := PI / 150.0
const BRANCH_WIGGLE_ANGULAR_SPEED := TAU * 0.55
const BRANCH_WIGGLE_PHASE_OFFSET := 0.7
const BRANCH_WIGGLE_BLEND_SPEED := 3.0

var _left_branch_rest_rotation := Vector3.ZERO
var _right_branch_rest_rotation := Vector3.ZERO
var _wind_active := false
var _wiggle_intensity := 0.0
var _wiggle_elapsed := 0.0

@onready var _wind_event: WindEvent3D = $WindEvent
@onready var _left_branch_visuals: Node3D = $LeftBranch/Visuals
@onready var _right_branch_visuals: Node3D = $RightBranch/Visuals


func _ready() -> void:
	_left_branch_rest_rotation = _left_branch_visuals.rotation
	_right_branch_rest_rotation = _right_branch_visuals.rotation
	_wind_event.event_started.connect(_on_wind_event_started)
	_wind_event.event_finished.connect(_on_wind_event_finished)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("8f6575")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("f0ae7d")
	environment.ambient_light_energy = 0.62
	$WorldEnvironment.environment = environment


func _process(delta: float) -> void:
	var step := maxf(delta, 0.0)
	_wiggle_elapsed += step
	var target_intensity := 1.0 if _wind_active else 0.0
	_wiggle_intensity = move_toward(
			_wiggle_intensity, target_intensity, BRANCH_WIGGLE_BLEND_SPEED * step
	)
	var phase := _wiggle_elapsed * BRANCH_WIGGLE_ANGULAR_SPEED
	var left_angle := sin(phase) * BRANCH_WIGGLE_AMPLITUDE * _wiggle_intensity
	var right_angle := (sin(phase + BRANCH_WIGGLE_PHASE_OFFSET)
			* BRANCH_WIGGLE_AMPLITUDE * _wiggle_intensity)
	_left_branch_visuals.rotation = _left_branch_rest_rotation + Vector3(0.0, 0.0, left_angle)
	_right_branch_visuals.rotation = _right_branch_rest_rotation + Vector3(0.0, 0.0, right_angle)


func _on_wind_event_started(_round_number: int) -> void:
	_wind_active = true


func _on_wind_event_finished(_round_number: int) -> void:
	_wind_active = false
