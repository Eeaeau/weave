class_name WebSpringModel3D
extends RefCounted

const FIELD_SPACING := 0.15
const SPRING_SPACING := 0.4

var effect_enabled := true
var weight := 3.0
var tension := 10.0
var damping := 0.35
var maximum_sag := 0.3
var depth_sway := 0.035
var load_direction := Vector3.DOWN
var peak_sag := 0.0
var peak_depth := 0.0
var _points: Array[Vector3] = []
var _offsets: Array[Vector2] = []
var _velocities: Array[Vector2] = []
var _masses: Array[float] = []
var _stiffnesses: Array[float] = []
var _pinned: Dictionary = {}
var _edges: Array[Dictionary] = []
var _lines: Array[Dictionary] = []
var _segments: Array[Dictionary] = []
var _normal := Vector3.FORWARD
var _field_bindings: Dictionary = {}
var _field_samples: Dictionary = {}
var _axis_u := Vector3.RIGHT
var _axis_v := Vector3.UP
var _origin := Vector3.ZERO


func setup(web: Web3D) -> void:
	_segments = web.get_support_segments()
	_normal = web.global_basis.y.normalized()
	_axis_u = web.global_basis.x.normalized()
	_axis_v = web.global_basis.z.normalized()
	for values in [_points, _offsets, _velocities, _masses, _stiffnesses, _edges, _lines]:
		values.clear()
	_pinned.clear()
	_field_bindings.clear()
	_field_samples.clear()
	peak_sag = 0.0
	peak_depth = 0.0
	var endpoints: Dictionary = {}
	for segment in _segments:
		endpoints[segment.start.snapped(Vector3.ONE * 0.0001)] = segment.start
		endpoints[segment.end.snapped(Vector3.ONE * 0.0001)] = segment.end
	var indices: Dictionary = {}
	for segment in _segments:
		var parameters: Array[float] = []
		var span: Vector3 = segment.end - segment.start
		var subdivisions := maxi(1, ceili(span.length() / SPRING_SPACING))
		for sample in range(subdivisions + 1):
			parameters.append(float(sample) / subdivisions)
		var line: Vector3 = segment.end - segment.start
		for endpoint: Vector3 in endpoints.values():
			var t := clampf(
				(endpoint - segment.start).dot(line) / maxf(line.length_squared(), 0.000001),
				0.0,
				1.0,
			)
			if segment.start.lerp(segment.end, t).distance_to(endpoint) < 0.0001:
				parameters.append(t)
		parameters.sort()
		var nodes: Array[int] = []
		var unique_parameters: Array[float] = []
		for t in parameters:
			if not unique_parameters.is_empty() and t - unique_parameters[-1] < 0.00001:
				continue
			unique_parameters.append(t)
			var point: Vector3 = segment.start.lerp(segment.end, t)
			var key := point.snapped(Vector3.ONE * 0.0001)
			if not indices.has(key):
				indices[key] = _points.size()
				_points.append(point)
			nodes.append(indices[key])
		_lines.append({ "nodes": nodes, "parameters": unique_parameters })
		for index in range(1, nodes.size()):
			if nodes[index - 1] == nodes[index]:
				continue
			var start := _points[nodes[index - 1]]
			var length := maxf(start.distance_to(_points[nodes[index]]), 0.001)
			_edges.append({ "a": nodes[index - 1], "b": nodes[index], "length": length })
	_origin = _points[0] if not _points.is_empty() else Vector3.ZERO
	for index in range(_points.size()):
		_offsets.append(Vector2.ZERO)
		_velocities.append(Vector2.ZERO)
		_masses.append(0.04)
		_stiffnesses.append(0.0)
		for anchor in web.valid_nodes:
			if _points[index].distance_to(anchor.global_position) < 0.0001:
				_pinned[index] = true
	for edge in _edges:
		for index in [edge.a, edge.b]:
			_masses[index] += edge.length * 0.5
			_stiffnesses[index] += 1.0 / edge.length


func advance(delta: float, contacts: Array[Dictionary]) -> void:
	_field_samples.clear()
	if not effect_enabled:
		_offsets.fill(Vector2.ZERO)
		_velocities.fill(Vector2.ZERO)
		return
	var loads: Array[Vector2] = []
	loads.resize(_points.size())
	loads.fill(Vector2.ZERO)
	for contact in contacts:
		if _points.is_empty():
			break
		var point: Vector3 = contact.point
		var closest := 0
		for index in range(1, _points.size()):
			var distance := _points[index].distance_squared_to(point)
			if distance < _points[closest].distance_squared_to(point):
				closest = index
		var share: float = contact.get("weight", 1.0)
		loads[closest].x += weight * 2.5 * share
		if contact.get("impact", false) and not _pinned.has(closest):
			var impulse: float = contact.get("side", 1.0) * depth_sway * 6.0 * weight * share
			_velocities[closest].y += impulse / _masses[closest]
	var elapsed := minf(delta, 0.05)
	var fastest := 1.0
	for index in range(_points.size()):
		fastest = maxf(fastest, sqrt(tension * _stiffnesses[index] / _masses[index]))
	var steps := maxi(1, ceili(elapsed / minf(0.003, 0.3 / fastest)))
	var dt := elapsed / steps
	for iteration in range(steps):
		var forces := loads.duplicate()
		for edge in _edges:
			var force: Vector2 = tension * (_offsets[edge.b] - _offsets[edge.a]) / edge.length
			forces[edge.a] += force
			forces[edge.b] -= force
		for index in range(_points.size()):
			if _pinned.has(index):
				continue
			var drag := 2.0 * damping * sqrt(tension * _stiffnesses[index] * _masses[index])
			_velocities[index] += (forces[index] - drag * _velocities[index]) / _masses[index] * dt
			_offsets[index] += _velocities[index] * dt
			if absf(_offsets[index].x) > maximum_sag:
				_offsets[index].x = clampf(_offsets[index].x, -maximum_sag, maximum_sag)
				_velocities[index].x = 0.0
			if absf(_offsets[index].y) > depth_sway:
				_offsets[index].y = clampf(_offsets[index].y, -depth_sway, depth_sway)
				_velocities[index].y = 0.0
			peak_sag = maxf(peak_sag, absf(_offsets[index].x))
			peak_depth = maxf(peak_depth, absf(_offsets[index].y))


func segment_offset(segment_index: int, t: float) -> Vector3:
	if not effect_enabled or segment_index < 0 or segment_index >= _lines.size():
		return Vector3.ZERO
	var line: Dictionary = _lines[segment_index]
	var after: int = clampi(line.parameters.bsearch(t), 1, line.nodes.size() - 1)
	var fraction := clampf(
		inverse_lerp(line.parameters[after - 1], line.parameters[after], t),
		0.0,
		1.0,
	)
	var offset := _offsets[line.nodes[after - 1]].lerp(_offsets[line.nodes[after]], fraction)
	return _world_offset(offset)


func displacement_at(point: Vector3) -> Vector3:
	if not effect_enabled or _points.is_empty():
		return Vector3.ZERO
	point -= _normal * (point - _origin).dot(_normal)
	for index in _pinned:
		if point.distance_squared_to(_points[index]) < 0.00000001:
			return Vector3.ZERO
	var offset := point - _origin
	var coordinates := Vector2(offset.dot(_axis_u), offset.dot(_axis_v)) / FIELD_SPACING
	var cell := Vector2i(floori(coordinates.x), floori(coordinates.y))
	var fraction := coordinates - Vector2(cell)
	var top := _sample_field(cell).lerp(_sample_field(cell + Vector2i.RIGHT), fraction.x)
	var bottom_left := _sample_field(cell + Vector2i.DOWN)
	var bottom := bottom_left.lerp(_sample_field(cell + Vector2i.ONE), fraction.x)
	return top.lerp(bottom, fraction.y)


func _sample_field(cell: Vector2i) -> Vector3:
	if _field_samples.has(cell):
		return _field_samples[cell]
	if not _field_bindings.has(cell):
		var position_in_plane := _origin + (_axis_u * cell.x + _axis_v * cell.y) * FIELD_SPACING
		var indices: Array[int] = []
		var distances: Array[float] = []
		for index in range(_points.size()):
			var distance := position_in_plane.distance_squared_to(_points[index])
			var slot := distances.bsearch(distance)
			if slot < 4:
				indices.insert(slot, index)
				distances.insert(slot, distance)
				if indices.size() > 4:
					indices.pop_back()
					distances.pop_back()
		var weights: Array[float] = []
		var total := 0.0
		for distance in distances:
			var influence := 1.0 / pow(0.02 + distance, 2.0)
			weights.append(influence)
			total += influence
		for index in range(weights.size()):
			weights[index] /= total
		_field_bindings[cell] = { "indices": indices, "weights": weights }
	var binding: Dictionary = _field_bindings[cell]
	var result := Vector2.ZERO
	for slot in range(binding.indices.size()):
		result += _offsets[binding.indices[slot]] * binding.weights[slot]
	var world := _world_offset(result)
	_field_samples[cell] = world
	return world


func segment_count() -> int:
	return _segments.size()


func _world_offset(offset: Vector2) -> Vector3:
	return load_direction.normalized() * offset.x + _normal * offset.y
