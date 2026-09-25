extends Node3D

class_name WebPolygon3D

@export var points: Array[Vector3] = []

@export_range(1, 30)
var rings: int = 8

@export_range(2, 20)
var curve_segments: int = 8

@export_range(0.0, 1.0)
var ring_curvature: float = 0.25

@export_range(0.0, 1.0)
var outer_curvature: float = 0.15

@export var line_color := Color.WHITE

var mesh_instance: MeshInstance3D


func _ready() -> void:
	mesh_instance = MeshInstance3D.new()
	add_child(mesh_instance)

	draw()


func draw() -> void:
	if points.size() < 3:
		return

	var mesh := ImmediateMesh.new()

	mesh.surface_begin(Mesh.PRIMITIVE_LINES)

	var center := Vector3.ZERO

	for point in points:
		center += point

	center /= points.size()

	# -------------------------------------------------
	# Outer polygon
	# -------------------------------------------------

	for i in range(points.size()):
		var a := points[i]
		var b := points[(i + 1) % points.size()]

		add_curved_line(
			mesh,
			a,
			b,
			center,
			outer_curvature,
			curve_segments
		)

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
				mesh,
				a,
				b,
				center,
				ring_curvature,
				curve_segments
			)

	# -------------------------------------------------
	# Strands from center to the outer points 
	# -------------------------------------------------

	for point in points:
		mesh.surface_add_vertex(point)
		mesh.surface_add_vertex(center)

	mesh.surface_end()

	mesh_instance.mesh = mesh

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = line_color

	mesh_instance.material_override = material

func add_curved_line(
	mesh: ImmediateMesh,
	start: Vector3,
	end: Vector3,
	center: Vector3,
	bend: float,
	segments: int
) -> void:

	var midpoint := (start + end) / 2.0

	# Pull the control point toward the center.
	var control := midpoint.lerp(center, bend)

	var previous := start

	for i in range(1, segments + 1):
		var t := float(i) / float(segments)

		var p := (
			start.lerp(control, t)
			.lerp(control.lerp(end, t), t)
		)

		mesh.surface_add_vertex(previous)
		mesh.surface_add_vertex(p)

		previous = p
