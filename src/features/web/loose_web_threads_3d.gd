class_name LooseWebThreads3D
extends MeshInstance3D
## Draws animated broken ends separately from walkable and catchable web geometry.

const SEGMENTS := 8

var thread_width := 0.01
var thread_color := Color.WHITE
var thread_length := 0.65
var sway_strength := 0.04
var _previous: Dictionary = {}
var _broken: Dictionary = {}
var _initialized := false
var _elapsed := 0.0
var _gust_strength := 0.0
var _ribbon := ImmediateMesh.new()
var _material := StandardMaterial3D.new()


func _ready() -> void:
	mesh = _ribbon
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material_override = _material
	set_process(false)
	visible = false


func _process(delta: float) -> void:
	advance(delta)


func synchronize(connections: Dictionary) -> void:
	if _initialized:
		for key in _previous:
			if not connections.has(key):
				_broken[key] = _previous[key]
	for key in connections:
		_broken.erase(key)
	_previous = connections.duplicate()
	_initialized = true
	_redraw()
	set_process(not _broken.is_empty())


func get_connection_count() -> int:
	return _broken.size()


func advance(delta: float) -> void:
	delta = maxf(0.0, delta)
	_elapsed += delta
	var gust := false
	for event in get_tree().get_nodes_in_group("wind_events"):
		if event.get("is_active") == true:
			gust = true
			break
	_gust_strength = move_toward(_gust_strength, 1.0 if gust else 0.0, delta * 1.5)
	_redraw()


func _redraw() -> void:
	_ribbon.clear_surfaces()
	_material.albedo_color = thread_color
	var drawing := false
	for key in _broken.keys():
		var record: Dictionary = _broken[key]
		if not is_instance_valid(record.a) or not is_instance_valid(record.b):
			_broken.erase(key)
			continue
		var a := to_local((record.a as Node3D).global_position)
		var b := to_local((record.b as Node3D).global_position)
		if a.distance_squared_to(b) < 0.0001:
			continue
		if not drawing:
			_ribbon.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
			drawing = true
		var phase := float(abs(str(key).hash()) % 1000) * TAU / 1000.0
		_append_thread(_sample_points(a, b, phase))
		_append_thread(_sample_points(b, a, phase + 2.7))
	if drawing:
		_ribbon.surface_end()
	visible = drawing
	if _broken.is_empty():
		_gust_strength = 0.0
		set_process(false)


func _sample_points(start: Vector3, target: Vector3, phase: float) -> PackedVector3Array:
	var length := minf(thread_length, start.distance_to(target) * 0.25)
	var direction := start.direction_to(target)
	var inverse := global_basis.inverse()
	var down := inverse * Vector3.DOWN
	down.y = 0.0
	if down.is_zero_approx():
		down = Vector3.BACK
	down = down.normalized()
	var wind := inverse * Vector3.RIGHT
	wind.y = 0.0
	wind = wind.normalized()
	var amplitude := minf(sway_strength * (1.0 + _gust_strength * 2.0), length * 0.3)
	var points := PackedVector3Array()
	for index in range(SEGMENTS + 1):
		var t := float(index) / SEGMENTS
		var flutter := sin(_elapsed * 1.7 + phase + t * 2.0)
		flutter += 0.3 * sin(_elapsed * 2.9 + phase * 1.7 + t * 3.0)
		var point := start + direction * length * t
		point += down * length * 0.45 * t * t
		point += wind * amplitude * flutter * t * t
		point += Vector3.UP * amplitude * 0.35 * sin(_elapsed * 1.3 + phase) * t * t
		points.append(point)
	return points


func _append_thread(points: PackedVector3Array) -> void:
	for index in range(points.size() - 1):
		var tangent := points[index + 1] - points[index]
		var side := Vector3.UP.cross(tangent).normalized()
		if side.is_zero_approx():
			side = Vector3.RIGHT
		var start_side := side * thread_width * lerpf(1.0, 0.45, float(index) / SEGMENTS)
		var end_side := side * thread_width * lerpf(1.0, 0.45, float(index + 1) / SEGMENTS)
		var a := points[index]
		var b := points[index + 1]
		for vertex in [a - start_side, a + start_side, b + end_side,
				a - start_side, b + end_side, b - end_side]:
			_ribbon.surface_add_vertex(vertex)
