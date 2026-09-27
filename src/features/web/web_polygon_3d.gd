@tool
class_name WebPolygon3D
extends Node3D

@export var points: Array[Vector3] = []:
	set(value):
		points = value
		if is_inside_tree():
			draw()
@export_range(1, 30)
var rings: int = 8:
	set(value):
		rings = value
		if is_inside_tree():
			draw()
@export_range(2, 20)
var curve_segments: int = 8:
	set(value):
		curve_segments = value
		if is_inside_tree():
			draw()
@export_range(0.0001, 0.1)
var web_width: float = 0.1:
	set(value):
		web_width = value
		if is_inside_tree():
			draw()
@export_range(0.0, 1.0)
var ring_curvature: float = 0.25:
	set(value):
		ring_curvature = value
		if is_inside_tree():
			draw()
@export_range(0.0, 1.0)
var outer_curvature: float = 0.15:
	set(value):
		outer_curvature = value
		if is_inside_tree():
			draw()
@export var line_color := Color.WHITE:
	set(value):
		line_color = value
		if is_inside_tree():
			draw()
@export var filled := true:
	set(value):
		filled = value
		if is_inside_tree():
			draw()

var mesh_container: Node3D


func _ready() -> void:
	draw()


func draw() -> void:
	if not is_inside_tree():
		return

	# Don't let the editor continuously create geometry.
	if mesh_container:
		mesh_container.queue_free()

	mesh_container = Node3D.new()
	mesh_container.name = "GeneratedWeb"
	add_child(mesh_container)

	if points.size() < 2:
		return

	var center := Vector3.ZERO

	for point in points:
		center += point

	center /= points.size()

	# Create one material shared by all cylinders.
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = line_color

	# -------------------------------------------------
	# Outer polygon
	# -------------------------------------------------

	for i in range(points.size()):
		var a := points[i]
		var b := points[(i + 1) % points.size()]

		add_curved_line(
			a,
			b,
			center,
			outer_curvature,
			curve_segments,
			material
		)

	if not filled:
		return

	# -------------------------------------------------
	# Inner rings
	# -------------------------------------------------

	for ring in range(1, rings + 1):

		var t := float(ring) / float(rings + 1)

		var ring_points: Array[Vector3] = []

		for point in points:
			ring_points.append(point.lerp(center, t))

		for i in range(ring_points.size()):

			var a := ring_points[i]
			var b := ring_points[(i + 1) % ring_points.size()]

			add_curved_line(
				a,
				b,
				center,
				ring_curvature,
				curve_segments,
				material
			)

	# -------------------------------------------------
	# Strands from center to outer points
	# -------------------------------------------------

	for point in points:
		add_cylinder_between(
			point,
			center,
			material
		)


func add_curved_line(
	start: Vector3,
	end: Vector3,
	center: Vector3,
	bend: float,
	segments: int,
	material: Material
) -> void:
	var previous := start

	for i in range(1, segments + 1):
		var t := float(i) / float(segments)

		var p := _curve_point(start, end, center, bend, t)

		add_cylinder_between(
			previous,
			p,
			material
		)

		previous = p


## Returns the exact local line segments created by draw(), grouped by strand.
func get_support_segments() -> Array[Dictionary]:
	var segments: Array[Dictionary] = []
	if points.size() < 2:
		return segments
	var center := Vector3.ZERO
	for point in points:
		center += point
	center /= points.size()
	for side in range(points.size()):
		_append_curved_support(
			segments,
			points[side],
			points[(side + 1) % points.size()],
			center,
			outer_curvature,
		_support_strand_id("outer:%d" % side)
		)
	if not filled:
		return segments
	for ring in range(1, rings + 1):
		var t := float(ring) / float(rings + 1)
		var ring_points: Array[Vector3] = []
		for point in points:
			ring_points.append(point.lerp(center, t))
		for side in range(ring_points.size()):
			_append_curved_support(
				segments,
				ring_points[side],
				ring_points[(side + 1) % ring_points.size()],
				center,
				ring_curvature,
				_support_strand_id("ring:%d:%d" % [ring, side])
			)
	for point_index in range(points.size()):
		segments.append({
		"start": points[point_index],
		"end": center,
		"strand_id": _support_strand_id("radial:%d" % point_index),
	})
	return segments


func _support_strand_id(family_id: String) -> String:
	return "line" if points.size() == 2 else family_id


func _append_curved_support(
	segments: Array[Dictionary],
	start: Vector3,
	end: Vector3,
	center: Vector3,
	bend: float,
	strand_id: String
) -> void:
	var previous := start
	for segment_index in range(1, curve_segments + 1):
		var t := float(segment_index) / float(curve_segments)
		var point := _curve_point(start, end, center, bend, t)
		segments.append({
			"start": previous,
			"end": point,
			"strand_id": strand_id,
		})
		previous = point


## The catch boundary uses the same sampled curves as the visible outer strands.
func get_catch_outline() -> PackedVector2Array:
	var outline := PackedVector2Array()
	if points.size() != 3 or not filled:
		return outline
	var center := (points[0] + points[1] + points[2]) / 3.0
	for side in range(3):
		var start: Vector3 = points[side]
		var end: Vector3 = points[(side + 1) % 3]
		for index in range(curve_segments):
			var t := float(index) / float(curve_segments)
			var point := _curve_point(start, end, center, outer_curvature, t)
			outline.append(Vector2(point.x, point.z))
	return outline


func _curve_point(start: Vector3, end: Vector3, center: Vector3,
		bend: float, t: float) -> Vector3:
	var control := ((start + end) * 0.5).lerp(center, bend)
	return start.lerp(control, t).lerp(control.lerp(end, t), t)


func add_cylinder_between(
	a: Vector3,
	b: Vector3,
	material: Material
) -> void:

	var direction := b - a
	var length := direction.length()

	if length <= 0.00001:
		return

	var cylinder := CylinderMesh.new()

	cylinder.top_radius = web_width
	cylinder.bottom_radius = web_width
	cylinder.height = length
	cylinder.radial_segments = 6
	cylinder.rings = 1

	var instance := MeshInstance3D.new()

	instance.mesh = cylinder
	instance.material_override = material

	# Put the cylinder halfway between the endpoints.
	instance.position = (a + b) * 0.5

	# CylinderMesh points along local +Y.
	# Rotate +Y so that it follows the segment.
	instance.quaternion = Quaternion(
		Vector3.UP,
		direction.normalized()
	)

	mesh_container.add_child(instance)
