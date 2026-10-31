extends Node

signal event_ready(payload: Dictionary)

const STATE := preload("res://src/features/multiplayer/match_state.gd")
const GUIDED := preload("res://src/features/collectibles/weapons/guided_rocket.gd")
const SCENES := [
	preload("res://src/features/collectibles/weapons/pebble_projectile.tscn"),
	preload("res://src/features/collectibles/weapons/rocket_projectile.tscn"),
	preload("res://src/features/collectibles/weapons/guided_rocket_projectile.tscn"),
]
const MAX_ACTIVE := 32

var _arena: Node
var _host := false
var _clock: Callable
var _sequence := 0
var _latest_id := 0
var _descriptions: Dictionary = {}
var _nodes: Dictionary = {}


func setup(arena: Node, host: bool, clock: Callable) -> void:
	_arena = arena
	_host = host
	_clock = clock


func register(projectile: Projectile3D) -> void:
	if not _host or _nodes.size() >= MAX_ACTIVE:
		return
	var type_id := -1
	for index in range(SCENES.size()):
		if SCENES[index].resource_path == projectile.scene_file_path:
			type_id = index
	if type_id < 0:
		return
	_sequence += 1
	var id := _sequence
	projectile.set_process(false)
	_nodes[id] = projectile
	var description := {"action": "launch", "id": id, "type": type_id,
		"position": STATE.pack_vector(projectile.global_position),
		"velocity": STATE.pack_vector(projectile.velocity),
		"rotation": STATE.pack_vector(projectile.rotation), "time": float(_clock.call())}
	if projectile is GUIDED:
		description.merge({ "steer": 0, "steer_revision": 0, "turn_speed": projectile.turn_speed })
		projectile.steering_changed.connect(_on_steer.bind(id))
	_descriptions[id] = description
	projectile.impacted.connect(_on_impact.bind(id))
	projectile.tree_exiting.connect(_on_removed.bind(id))
	event_ready.emit(description)


func _on_steer(id: int) -> void:
	if not _nodes.has(id) or _nodes[id].freeze:
		return
	var rocket: Projectile3D = _nodes[id]
	var description: Dictionary = _descriptions[id]
	description.position = STATE.pack_vector(rocket.global_position)
	description.velocity = STATE.pack_vector(rocket.velocity)
	description.rotation = STATE.pack_vector(rocket.rotation)
	description.time = float(_clock.call())
	description.steer = rocket.get("steering")
	description.steer_revision += 1
	var event := description.duplicate(true)
	event.action = "steer"
	event_ready.emit(event)


func has_guided_rocket() -> bool:
	for projectile in _nodes.values():
		if projectile is GUIDED and not projectile.freeze:
			return true
	return false


func _on_impact(point: Vector3, id: int) -> void:
	if not _descriptions.has(id) or _descriptions[id].has("impact"):
		return
	var impact := {"action": "impact", "id": id, "position": STATE.pack_vector(point),
		"time": float(_clock.call())}
	_descriptions[id]["impact"] = impact
	event_ready.emit(impact)


func _on_removed(id: int) -> void:
	_nodes.erase(id)
	_descriptions.erase(id)
	if is_instance_valid(_arena) and not _arena.is_queued_for_deletion():
		event_ready.emit({ "action": "remove", "id": id })


func receive(payload: Dictionary) -> void:
	if _host or not payload.get("id") is int or payload.id <= 0:
		return
	var id: int = payload.id
	match payload.get("action"):
		"steer":
			if (_nodes.has(id) and _descriptions[id].type == 2 and not _nodes[id].freeze
					and _valid_launch(payload) and payload.type == 2
					and payload.steer_revision > _descriptions[id].steer_revision
					and payload.time >= _descriptions[id].time):
				_descriptions[id] = payload.duplicate(true)
				_descriptions[id].action = "launch"
				present()
		"launch":
			if id > _latest_id and _valid_launch(payload) and _nodes.size() < MAX_ACTIVE:
				_latest_id = id
				_create(payload)
		"impact":
			if _nodes.has(id) and _valid_impact(payload):
				_descriptions[id]["impact"] = payload.duplicate(true)
				_nodes[id].present_impact(STATE.unpack_vector(payload.position))
		"remove":
			_latest_id = maxi(_latest_id, id)
			_remove(id)


func _create(description: Dictionary) -> void:
	var projectile := SCENES[description.type].instantiate() as Projectile3D
	projectile.network_replica = true
	_arena.add_child(projectile)
	projectile.set_process(false)
	projectile.hitbox.monitoring = false
	projectile.hitbox.monitorable = false
	projectile.rotation = STATE.unpack_vector(description.rotation)
	_nodes[description.id] = projectile
	_descriptions[description.id] = description.duplicate(true)
	if description.has("impact"):
		projectile.present_impact(STATE.unpack_vector(description.impact.position))
	present()


func present() -> void:
	if _host:
		return
	for id in _nodes:
		var projectile := _nodes[id] as Projectile3D
		if projectile.freeze:
			continue
		var description: Dictionary = _descriptions[id]
		var elapsed := clampf(float(_clock.call()) - float(description.time), 0.0, 30.0)
		if projectile is GUIDED:
			projectile.steering = description.steer
			var motion := GUIDED.sample_flight(STATE.unpack_vector(description.position),
				STATE.unpack_vector(description.velocity),
				description.steer * description.turn_speed, elapsed)
			projectile.global_position = motion.position
			projectile.velocity = motion.velocity
			projectile.face_velocity()
			continue
		projectile.global_position = STATE.unpack_vector(description.position) \
			+ STATE.unpack_vector(description.velocity) * elapsed \
			+ Vector3.DOWN * 4.905 * elapsed * elapsed


func capture() -> Array:
	return _descriptions.values().duplicate(true)


func restore(descriptions: Variant) -> bool:
	if _host or not descriptions is Array or descriptions.size() > MAX_ACTIVE:
		return false
	var incoming: Dictionary = {}
	for description in descriptions:
		if not description is Dictionary or not _valid_launch(description) \
				or incoming.has(description.id):
			return false
		incoming[description.id] = description
	for id in _nodes.keys():
		_remove(id)
	for id in incoming:
		_latest_id = maxi(_latest_id, id)
		_create(incoming[id])
	return true


func _remove(id: int) -> void:
	if _nodes.has(id) and is_instance_valid(_nodes[id]):
		_nodes[id].free()
	_nodes.erase(id)
	_descriptions.erase(id)


func _valid_launch(value: Dictionary) -> bool:
	return value.get("id") is int and value.id > 0 \
		and value.get("type") is int and value.type >= 0 and value.type < SCENES.size() \
		and STATE._valid_vector(value.get("position")) \
		and STATE._valid_vector(value.get("velocity")) \
		and STATE._valid_vector(value.get("rotation")) \
		and value.get("time") is float and is_finite(value.time) \
		and (value.type != 2 or _valid_guidance(value)) \
		and (not value.has("impact") \
			or (value.impact is Dictionary and _valid_impact(value.impact)))


func _valid_impact(value: Dictionary) -> bool:
	return STATE._valid_vector(value.get("position")) \
		and value.get("time") is float and is_finite(value.time)


func _valid_guidance(value: Dictionary) -> bool:
	return value.get("steer") is int and value.steer >= -1 and value.steer <= 1 \
		and value.get("steer_revision") is int \
		and value.steer_revision >= 0 and value.steer_revision <= 1_000_000 \
		and value.get("turn_speed") is float and is_finite(value.turn_speed) \
		and value.turn_speed >= 0.2 and value.turn_speed <= 5.0
