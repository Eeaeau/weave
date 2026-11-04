class_name WebSpringModel3D
extends RefCounted
## Bounded displacement field; decorative strands never become spring particles.

const MINIMUM_SPACING := 0.75
const MAX_AXIS_SAMPLES := 24

var effect_enabled := true
var weight := 3.0
var tension := 10.0
var damping := 0.35
var maximum_sag := 0.3
var depth_sway := 0.035
var load_direction := Vector3.DOWN
var peak_sag := 0.0
var peak_depth := 0.0
var field_size := Vector2i.ONE
var spacing := MINIMUM_SPACING
var _points := PackedVector3Array()
var _offsets := PackedVector2Array()
var _velocities := PackedVector2Array()
var _stiffnesses := PackedFloat32Array()
var _anchor_strength := PackedFloat32Array()
var _active := PackedByteArray()
var _edges: Array[Vector2i] = []
var _segments: Array[Dictionary] = []
var _anchors := PackedVector3Array()
var _normal := Vector3.FORWARD
var _axis_u := Vector3.RIGHT
var _axis_v := Vector3.UP
var _origin := Vector3.ZERO
var _region_samples: Dictionary = {}
var _simulation_points := PackedInt32Array()
var _simulation_edges: Array[Vector2i] = []
var _occupied := PackedByteArray()
var _region_selection: Array = []


func setup(web: Web3D) -> void:
	_segments = web.get_support_segments()
	_normal = web.global_basis.y.normalized()
	_axis_u = web.global_basis.x.normalized()
	_axis_v = web.global_basis.z.normalized()
	_anchors.clear()
	var connected: Dictionary = {}
	for edge in web.edges:
		connected[edge.x] = true
		connected[edge.y] = true
	for index: int in connected:
		if index >= 0 and index < web.valid_nodes.size():
			var anchor := web.valid_nodes[index]
			if is_instance_valid(anchor):
				_anchors.append(anchor.global_position)
	_edges.clear()
	_region_samples.clear()
	_region_selection.clear()
	_simulation_points.clear()
	_simulation_edges.clear()
	peak_sag = 0.0
	peak_depth = 0.0
	if _segments.is_empty():
		_origin = web.global_position
		field_size = Vector2i.ONE
		_resize(1)
		return
	var minimum := Vector2(INF, INF)
	var maximum := Vector2(-INF, -INF)
	for segment in _segments:
		for point: Vector3 in [segment.start, segment.end]:
			var projected := Vector2(point.dot(_axis_u), point.dot(_axis_v))
			minimum = minimum.min(projected)
			maximum = maximum.max(projected)
	var extent := maximum - minimum
	spacing = maxf(MINIMUM_SPACING, maxf(extent.x, extent.y) / (MAX_AXIS_SAMPLES - 3))
	field_size = Vector2i(ceili(extent.x / spacing) + 3, ceili(extent.y / spacing) + 3)
	field_size = field_size.min(Vector2i(MAX_AXIS_SAMPLES, MAX_AXIS_SAMPLES))
	var plane_depth: float = _segments[0].start.dot(_normal)
	_origin = (_axis_u * (minimum.x - spacing) + _axis_v * (minimum.y - spacing)
		+ _normal * plane_depth)
	_resize(field_size.x * field_size.y)
	var faces: Array[PackedVector2Array] = []
	for face in web.find_faces():
		var outline := PackedVector2Array()
		for vertex in face:
			outline.append(_project(web.valid_nodes[vertex].global_position))
		faces.append(outline)
	for index in range(_points.size()):
		var cell := Vector2i(index % field_size.x, index / field_size.x)
		var point := _origin + (_axis_u * cell.x + _axis_v * cell.y) * spacing
		_points[index] = point
		_active[index] = int(_covers(point, faces))
		for anchor in _anchors:
			var distance := point.distance_to(anchor) / (spacing * 1.5)
			_anchor_strength[index] += 4.0 * (1.0 - smoothstep(0.0, 1.0, distance))
		_stiffnesses[index] = _anchor_strength[index]
	for row in range(field_size.y):
		for column in range(field_size.x):
			var index := row * field_size.x + column
			if column + 1 < field_size.x:
				_connect(index, index + 1)
			if row + 1 < field_size.y:
				_connect(index, index + field_size.x)
	_index_regions(web)
	for index in range(_points.size()):
		if _active[index] != 0:
			_simulation_points.append(index)
	_simulation_edges = _edges.duplicate()
	_occupied = _active.duplicate()


func _index_regions(web: Web3D) -> void:
	for region in range(web.polygon_container.get_child_count()):
		var polygon := web.polygon_container.get_child(region) as WebPolygon3D
		if polygon == null:
			continue
		var minimum := Vector2(INF, INF)
		var maximum := Vector2(-INF, -INF)
		for point in polygon.points:
			var projected := _project(polygon.to_global(point)) / spacing
			minimum = minimum.min(projected)
			maximum = maximum.max(projected)
		var first := Vector2i((minimum - Vector2.ONE).floor()).max(Vector2i.ZERO)
		var last := Vector2i((maximum + Vector2.ONE).ceil()).min(field_size - Vector2i.ONE)
		var samples := PackedInt32Array()
		for row in range(first.y, last.y + 1):
			for column in range(first.x, last.x + 1):
				var index := row * field_size.x + column
				if _active[index] != 0:
					samples.append(index)
		_region_samples[region] = samples


func set_active_regions(active_regions: Array, occupied_regions: Array) -> void:
	var selection := [active_regions, occupied_regions]
	if selection == _region_selection:
		return
	_region_selection = selection.duplicate(true)
	var selected := PackedByteArray()
	selected.resize(_points.size())
	_occupied.resize(_points.size())
	_occupied.fill(0)
	for region: int in active_regions:
		for index: int in _region_samples.get(region, []):
			selected[index] = 1
	for region: int in occupied_regions:
		for index: int in _region_samples.get(region, []):
			_occupied[index] = 1
	_simulation_points.clear()
	for index in range(_points.size()):
		if selected[index] != 0:
			_simulation_points.append(index)
		else:
			_offsets[index] = Vector2.ZERO
			_velocities[index] = Vector2.ZERO
	_simulation_edges.clear()
	for edge in _edges:
		if selected[edge.x] != 0 or selected[edge.y] != 0:
			_simulation_edges.append(edge)


func simulated_point_count() -> int:
	return _simulation_points.size()


func _resize(count: int) -> void:
	_points.resize(count)
	_points.fill(Vector3.ZERO)
	_offsets.resize(count)
	_offsets.fill(Vector2.ZERO)
	_velocities.resize(count)
	_velocities.fill(Vector2.ZERO)
	_stiffnesses.resize(count)
	_stiffnesses.fill(0.0)
	_anchor_strength.resize(count)
	_anchor_strength.fill(0.0)
	_active.resize(count)
	_active.fill(0)


func _project(point: Vector3) -> Vector2:
	var offset := point - _origin
	return Vector2(offset.dot(_axis_u), offset.dot(_axis_v))


func _covers(point: Vector3, faces: Array[PackedVector2Array]) -> bool:
	var projected := _project(point)
	for face in faces:
		if Geometry2D.is_point_in_polygon(projected, face):
			return true
	var limit := spacing * spacing
	for segment in _segments:
		var line: Vector3 = segment.end - segment.start
		var start: Vector3 = segment.start
		var along := (point - start).dot(line) / maxf(line.length_squared(), 0.000001)
		var closest: Vector3 = segment.start + line * clampf(along, 0.0, 1.0)
		if point.distance_squared_to(closest) <= limit:
			return true
	return false


func _connect(start: int, finish: int) -> void:
	if _active[start] == 0 or _active[finish] == 0:
		return
	_edges.append(Vector2i(start, finish))
	_stiffnesses[start] += 1.0
	_stiffnesses[finish] += 1.0


func advance(delta: float, contacts: Array[Dictionary]) -> void:
	if _simulation_points.is_empty():
		return
	if not effect_enabled:
		_offsets.fill(Vector2.ZERO)
		_velocities.fill(Vector2.ZERO)
		return
	var loads := PackedVector2Array()
	loads.resize(_points.size())
	loads.fill(Vector2.ZERO)
	var mass := maxf(0.25, spacing * spacing)
	for contact in contacts:
		_deposit(contact, loads, mass)
	var drag := PackedFloat32Array()
	drag.resize(_points.size())
	for index in _simulation_points:
		drag[index] = 2.0 * damping * sqrt(tension * _stiffnesses[index] * mass)
	var elapsed := clampf(delta, 0.0, 0.05)
	var steps := maxi(1, ceili(elapsed * 120.0))
	var dt := elapsed / steps
	for iteration in range(steps):
		var forces := loads.duplicate()
		for edge in _simulation_edges:
			var force := tension * (_offsets[edge.y] - _offsets[edge.x])
			forces[edge.x] += force
			forces[edge.y] -= force
		for index in _simulation_points:
			var force := forces[index] - tension * _anchor_strength[index] * _offsets[index]
			_velocities[index] += (force - drag[index] * _velocities[index]) / mass * dt
			_offsets[index] += _velocities[index] * dt
			if absf(_offsets[index].x) > maximum_sag:
				_offsets[index].x = clampf(_offsets[index].x, -maximum_sag, maximum_sag)
				_velocities[index].x = 0.0
			if absf(_offsets[index].y) > depth_sway:
				_offsets[index].y = clampf(_offsets[index].y, -depth_sway, depth_sway)
				_velocities[index].y = 0.0
			peak_sag = maxf(peak_sag, absf(_offsets[index].x))
			peak_depth = maxf(peak_depth, absf(_offsets[index].y))
	var relaxation := exp(-8.0 * elapsed)
	for index in _simulation_points:
		if _occupied[index] == 0:
			_offsets[index] *= relaxation
			_velocities[index] *= relaxation


func _deposit(contact: Dictionary, loads: PackedVector2Array, mass: float) -> void:
	var coordinates := _project(contact.point) / spacing
	if (coordinates.x < 0 or coordinates.y < 0
			or coordinates.x > field_size.x - 1 or coordinates.y > field_size.y - 1):
		return
	var cell := Vector2i(floori(coordinates.x), floori(coordinates.y))
	var fraction := coordinates - Vector2(cell)
	var share: float = contact.get("weight", 1.0)
	for offset: Vector2i in [Vector2i.ZERO, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.ONE]:
		var sample := (cell + offset).min(field_size - Vector2i.ONE)
		var index := sample.y * field_size.x + sample.x
		if _occupied[index] == 0:
			continue
		var blend := (1.0 - fraction.x if offset.x == 0 else fraction.x)
		blend *= 1.0 - fraction.y if offset.y == 0 else fraction.y
		loads[index].x += weight * 2.5 * share * blend
		if contact.get("impact", false):
			var impulse: float = contact.get("side", 1.0) * depth_sway * 6.0 * weight * share
			_velocities[index].y += impulse * blend / mass


func anchor_factor(point: Vector3) -> float:
	point -= _normal * (point - _origin).dot(_normal)
	var distance_squared := INF
	for anchor in _anchors:
		distance_squared = minf(distance_squared, point.distance_squared_to(anchor))
	return smoothstep(0.0, spacing * 1.5, sqrt(distance_squared))


func displacement_at(point: Vector3) -> Vector3:
	if not effect_enabled or _segments.is_empty():
		return Vector3.ZERO
	var maximum := Vector2(field_size - Vector2i.ONE)
	var coordinates := (_project(point) / spacing).clamp(Vector2.ZERO, maximum)
	var cell := Vector2i(floori(coordinates.x), floori(coordinates.y))
	var finish := (cell + Vector2i.ONE).min(field_size - Vector2i.ONE)
	var fraction := coordinates - Vector2(cell)
	var top := _offsets[cell.y * field_size.x + cell.x].lerp(
		_offsets[cell.y * field_size.x + finish.x], fraction.x)
	var bottom := _offsets[finish.y * field_size.x + cell.x].lerp(
		_offsets[finish.y * field_size.x + finish.x], fraction.x)
	var offset := top.lerp(bottom, fraction.y) * anchor_factor(point)
	return load_direction.normalized() * offset.x + _normal * offset.y


func segment_offset(segment_index: int, t: float) -> Vector3:
	if segment_index < 0 or segment_index >= _segments.size():
		return Vector3.ZERO
	return displacement_at(_segments[segment_index].start.lerp(_segments[segment_index].end, t))


func segment_count() -> int:
	return _segments.size()
