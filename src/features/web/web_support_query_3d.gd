extends RefCounted
## Conservative planar lookup; source order keeps equal-score landings stable.

const CELL_SIZE := 0.75

var _segments: Array[Dictionary]
var _cells: Dictionary = {}
var _origin: Vector3
var _axis_u: Vector3
var _axis_v: Vector3


func _init(segments: Array[Dictionary], plane: Transform3D) -> void:
	_segments = segments
	_origin = plane.origin
	_axis_u = plane.basis.x.normalized()
	_axis_v = plane.basis.z.normalized()
	for index in range(_segments.size()):
		var segment := _segments[index]
		var start := _project(segment.start)
		var finish := _project(segment.end)
		var minimum := _cell(start.min(finish))
		var maximum := _cell(start.max(finish))
		for row in range(minimum.y, maximum.y + 1):
			for column in range(minimum.x, maximum.x + 1):
				var key := Vector2i(column, row)
				if not _cells.has(key):
					_cells[key] = []
				_cells[key].append(index)


func find(point: Vector3, radius: float) -> Array[Dictionary]:
	var center := _project(point)
	var extent := Vector2.ONE * (maxf(radius, 0.0) + 0.0001)
	var minimum := _cell(center - extent)
	var maximum := _cell(center + extent)
	var found: Dictionary = {}
	for row in range(minimum.y, maximum.y + 1):
		for column in range(minimum.x, maximum.x + 1):
			for index: int in _cells.get(Vector2i(column, row), []):
				found[index] = true
	var indices := found.keys()
	indices.sort()
	var result: Array[Dictionary] = []
	for index: int in indices:
		result.append(_segments[index])
	return result


func _project(point: Vector3) -> Vector2:
	var relative := point - _origin
	return Vector2(relative.dot(_axis_u), relative.dot(_axis_v))


func _cell(point: Vector2) -> Vector2i:
	return Vector2i(floori(point.x / CELL_SIZE), floori(point.y / CELL_SIZE))
