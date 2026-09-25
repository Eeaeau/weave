class_name WindFlight3D
extends Node3D
## Moves one flat collectible on a curved path through the web plane.

signal plane_crossed(item: Collectible3D, world_point: Vector3)
signal finished

const CONTACT_FRACTION := 0.72

var item: Collectible3D
var _start: Vector3
var _contact: Vector3
var _exit: Vector3
var _duration: float
var _sway: float
var _elapsed: float = 0.0
var _crossed: bool = false
var _done: bool = false
var _phase: float = 0.0


func _process(delta: float) -> void:
	advance(delta)


func configure(collectible: Collectible3D, path_points: PackedVector3Array,
		duration: float, sway: float) -> void:
	item = collectible
	_start = path_points[0]
	_contact = path_points[1]
	_exit = path_points[2]
	_duration = maxf(duration, 0.01)
	_sway = maxf(sway, 0.0)
	_elapsed = 0.0
	_crossed = false
	_done = false
	_phase = _start.x * 1.37 + _contact.z
	add_child(item)
	item.position = Vector3.ZERO
	global_position = _start
	set_process(true)


func advance(delta: float) -> void:
	if _done:
		return
	if not is_instance_valid(item):
		_complete()
		return
	var previous := _elapsed
	_elapsed = minf(_elapsed + maxf(delta, 0.0), _duration)
	if is_equal_approx(_elapsed, _duration):
		_elapsed = _duration
	var contact_time := _duration * CONTACT_FRACTION
	if not _crossed and previous < contact_time and _elapsed >= contact_time:
		_crossed = true
		global_position = _contact
		plane_crossed.emit(item, _contact)
		if not is_instance_valid(item):
			_complete()
			return
	global_position = _position_at(_elapsed / _duration)
	if _elapsed >= _duration:
		_complete()


func _position_at(progress: float) -> Vector3:
	if progress <= CONTACT_FRACTION:
		var step := progress / CONTACT_FRACTION
		var control := _start.lerp(_contact, 0.5) + Vector3(_sway, 0.5, 0.0)
		return _quadratic(_start, control, _contact, step) + _wobble(step)
	var step := (progress - CONTACT_FRACTION) / (1.0 - CONTACT_FRACTION)
	var control := _contact.lerp(_exit, 0.5) + Vector3(-_sway, 0.25, 0.0)
	return _quadratic(_contact, control, _exit, step) + _wobble(step)


func _quadratic(a: Vector3, control: Vector3, b: Vector3, t: float) -> Vector3:
	return a * (1.0 - t) * (1.0 - t) + control * 2.0 * (1.0 - t) * t + b * t * t


func _wobble(t: float) -> Vector3:
	var envelope := sin(PI * t)
	return Vector3(sin(t * TAU * 1.3 + _phase) * envelope * _sway * 0.4,
		cos(t * TAU * 1.8 + _phase) * envelope * _sway * 0.1, 0.0)


func _complete() -> void:
	if _done:
		return
	_done = true
	set_process(false)
	finished.emit()
