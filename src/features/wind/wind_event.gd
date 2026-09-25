class_name WindEvent3D
extends Node3D
## Schedules one group of windborne collectibles and reports web-plane contacts.

signal event_started(round_number: int)
signal item_contact(item: Collectible3D, side: int, local_point: Vector2, world_point: Vector3)
signal event_finished(round_number: int)

@export_range(1, 12) var group_size: int = 3
@export_range(0.1, 5.0, 0.1) var spawn_interval: float = 0.8
@export_range(1.0, 20.0, 0.1) var flight_duration_min: float = 7.0
@export_range(1.0, 20.0, 0.1) var flight_duration_max: float = 9.0
@export var random_seed: int = 0
@export var spawn_entries: Array[WindSpawnEntry] = [
	preload("res://src/features/wind/entries/pebble.tres"),
	preload("res://src/features/wind/entries/silk_moth.tres"),
	preload("res://src/features/wind/entries/twig_cutter.tres"),
	preload("res://src/features/wind/entries/health_beetle.tres"),
]

var is_active: bool = false
var _round_number: int = 0
var _elapsed: float = 0.0
var _spawned: int = 0
var _selection := WindSelection.new()
var _path_random := RandomNumberGenerator.new()
var _seeded: bool = false
var _active_flights: Array[WindFlight3D] = []


func _process(delta: float) -> void:
	advance(delta)


func start_round(round_number: int) -> void:
	if is_active:
		push_warning("Wind event is already active")
		return
	if not _seeded:
		var seed_value := random_seed if random_seed != 0 else randi()
		_selection.reset(seed_value)
		_path_random.seed = seed_value + 1
		_seeded = true
	_round_number = round_number
	_elapsed = 0.0
	_spawned = 0
	is_active = true
	event_started.emit(round_number)
	_spawn_next()


func advance(delta: float) -> void:
	if not is_active:
		return
	_elapsed += maxf(delta, 0.0)
	while _spawned < group_size and _elapsed >= _spawned * spawn_interval:
		_spawn_next()
		if not is_active:
			return
	for flight in _active_flights.duplicate():
		if is_instance_valid(flight):
			flight.advance(delta)
	if _spawned >= group_size and _active_flights.is_empty():
		_finish_event()


func _spawn_next() -> void:
	var entry := _selection.choose_entry(_round_number, spawn_entries)
	if entry == null:
		push_warning("No eligible wind collectibles for round %d" % _round_number)
		_spawned = group_size
		if _active_flights.is_empty():
			_finish_event()
		return
	var side := _selection.next_side()
	var lane := _choose_lane(side)
	if lane == null:
		push_warning("No wind lane for player side %d" % side)
		_spawned = group_size
		if _active_flights.is_empty():
			_finish_event()
		return
	var item := entry.scene.instantiate() as Collectible3D
	if item == null:
		push_warning("Wind entry scene must inherit Collectible3D")
		_spawned += 1
		return
	item.collectible = entry.data
	var duration := _path_random.randf_range(flight_duration_min, flight_duration_max)
	var sway := _path_random.randf_range(0.2, 0.5)
	var flight := WindFlight3D.new()
	$Flights.add_child(flight)
	flight.plane_crossed.connect(func(crossing_item: Collectible3D,
			world_point: Vector3) -> void: _on_plane_crossed(crossing_item, side, world_point))
	flight.finished.connect(func() -> void: _on_flight_finished(flight))
	_active_flights.append(flight)
	flight.configure(item, _sample_path(lane), duration, sway)
	flight.set_process(false)
	_spawned += 1


func _sample_path(lane: WindLane3D) -> PackedVector3Array:
	var local_x := _path_random.randf_range(lane.contact_rect.position.x,
			lane.contact_rect.end.x)
	var local_z := _path_random.randf_range(lane.contact_rect.position.y,
			lane.contact_rect.end.y)
	var plane: Node3D = $WebPlane
	var contact_world := plane.to_global(Vector3(local_x, 0.0, local_z))
	var start_world := lane.global_position + Vector3(
		_path_random.randf_range(-0.5, 0.5), _path_random.randf_range(-0.3, 0.3), 0.0)
	var exit_world := contact_world + Vector3(
		_path_random.randf_range(-0.7, 0.7), -2.0, 6.0)
	return PackedVector3Array([start_world, contact_world, exit_world])


func _choose_lane(side: int) -> WindLane3D:
	var choices: Array[WindLane3D] = []
	for node in $Lanes.get_children():
		if node is WindLane3D and node.side == side:
			choices.append(node)
	if choices.is_empty():
		return null
	return choices[_path_random.randi_range(0, choices.size() - 1)]


func _on_plane_crossed(item: Collectible3D, side: int, world_point: Vector3) -> void:
	var local: Vector3 = $WebPlane.to_local(world_point)
	item_contact.emit(item, side, Vector2(local.x, local.z), world_point)


func _on_flight_finished(flight: WindFlight3D) -> void:
	_active_flights.erase(flight)
	flight.queue_free()
	if is_active and _spawned >= group_size and _active_flights.is_empty():
		_finish_event()


func _finish_event() -> void:
	if not is_active:
		return
	is_active = false
	event_finished.emit(_round_number)
