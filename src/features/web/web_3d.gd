@tool
class_name Web3D
extends Node3D


# ============================================================
# Nodes
# ============================================================

@export_category("Nodes")

## The nodes that can be connected by the web.
@export var valid_nodes: Array[Node3D] = []:
	set(value):
		valid_nodes = value
		if is_inside_tree():
			rebuild()
# ============================================================
# Edges
# ============================================================
@export_category("Edges")

## Each Vector2i contains the indices of two valid_nodes.
##
## Example:
## Vector2i(0, 2)
##
## means:
## valid_nodes[0] <-> valid_nodes[2]
##
@export var edges: Array[Vector2i] = []:
	set(value):
		edges = value
		if is_inside_tree():
			rebuild()
# ============================================================
# Web appearance
# ============================================================
@export_category("Web")

@export_range(0, 30, 1)
var rings: int = 8:
	set(value):
		rings = value
		if is_inside_tree():
			rebuild()
@export_range(2, 32, 1)
var curve_segments: int = 8:
	set(value):
		curve_segments = value
		if is_inside_tree():
			rebuild()
@export_range(0.0001, 0.01, 0.0001)
var web_width: float = 0.0025:
	set(value):
		web_width = value
		if is_inside_tree():
			rebuild()
@export_range(0.0, 1.0, 0.01)
var ring_curvature: float = 0.25:
	set(value):
		ring_curvature = value
		if is_inside_tree():
			rebuild()
@export_range(0.0, 1.0, 0.01)
var outer_curvature: float = 0.15:
	set(value):
		outer_curvature = value
		if is_inside_tree():
			rebuild()
@export
var line_color: Color = Color.WHITE:
	set(value):
		line_color = value
		if is_inside_tree():
			rebuild()

var _last_node_positions: Array[Vector3] = []
# ============================================================
# Generated geometry
# ============================================================
var polygon_container: Node3D


# ============================================================
# Lifecycle
# ============================================================


func _ready() -> void:

	if Engine.is_editor_hint():
		set_process(true)
		call_deferred("rebuild")
	else:
		set_process(false)
		rebuild()


func _process(_delta: float) -> void:

	if not Engine.is_editor_hint():
		return

	if _nodes_moved():
		rebuild()


func _nodes_moved() -> bool:

	var current_positions: Array[Vector3] = []

	for node in valid_nodes:

		if node == null:
			current_positions.append(Vector3.ZERO)
		else:
			current_positions.append(node.global_position)

	# First check after initialization.
	if current_positions.size() != _last_node_positions.size():
		_last_node_positions = current_positions
		return true

	for i in range(current_positions.size()):

		if not current_positions[i].is_equal_approx(
			_last_node_positions[i]
		):
			_last_node_positions = current_positions
			return true

	return false


# ============================================================
# Rebuild
# ============================================================


func rebuild() -> void:

	if not is_inside_tree():
		return

	_clear_polygons()

	if valid_nodes.size() < 2:
		return

	polygon_container = Node3D.new()
	polygon_container.name = "GeneratedPolygons"

	add_child(polygon_container)

	# Generated geometry should not become part
	# of the saved scene.
	if Engine.is_editor_hint():
		polygon_container.owner = null

	# --------------------------------------------------------
	# Find all triangular faces first.
	# --------------------------------------------------------

	var faces := find_faces()

	# --------------------------------------------------------
	# Collect every edge that belongs to a face.
	#
	# These edges will already be represented by the
	# triangular WebPolygon3D, so they should not also
	# be rendered as standalone edges.
	# --------------------------------------------------------

	var face_edges: Dictionary = {}

	for face in faces:

		if face.size() != 3:
			continue

		var a: int = face[0]
		var b: int = face[1]
		var c: int = face[2]

		face_edges[_edge_key(a, b)] = true
		face_edges[_edge_key(b, c)] = true
		face_edges[_edge_key(c, a)] = true

	# --------------------------------------------------------
	# Render edges that are NOT part of a face.
	# --------------------------------------------------------

	for edge in edges:

		var a: int = edge.x
		var b: int = edge.y

		if face_edges.has(_edge_key(a, b)):
			continue

		create_polygon([a, b])

	# --------------------------------------------------------
	# Render the triangular faces.
	# --------------------------------------------------------

	for face in faces:
		create_polygon(face)


# ============================================================
# Clear generated polygons
# ============================================================


func _clear_polygons() -> void:

	if polygon_container == null:
		return

	if is_instance_valid(polygon_container):
		polygon_container.free()

	polygon_container = null


# ============================================================
# Edge API
# ============================================================


## Checks if we can add an edge between two valid nodes.
##
## Returns true if the edge would be valid.
func can_add_edge(a: int, b: int) -> bool:

	if a == b or a < 0 or a >= valid_nodes.size() or b < 0 or b > valid_nodes.size():
		return false

	if has_edge(a, b):
		return false

	# Don't allow an edge to pass through another node.
	if edge_passes_through_node(a, b):
		return false

	# Don't allow edges to cross or overlap.
	if edge_intersects_existing(a, b):
		return false

	return true


## Adds an edge between two valid nodes.
##
## Returns true if the edge was successfully added.
## Returns false if the edge would be invalid.
func add_edge(a: int, b: int) -> bool:

	if not can_add_edge(a, b):
		return false

	edges.append(Vector2i(a, b))

	rebuild()

	return true


## Removes an edge between two nodes.
func remove_edge(a: int, b: int) -> bool:

	for i in range(edges.size()):

		var edge := edges[i]

		if (
			(edge.x == a and edge.y == b)
			or
			(edge.x == b and edge.y == a)
		):

			edges.remove_at(i)

			rebuild()

			return true

	return false


## Returns true if an edge already exists.
func has_edge(a: int, b: int) -> bool:

	for edge in edges:

		if (
			(edge.x == a and edge.y == b)
			or
			(edge.x == b and edge.y == a)
		):

			return true

	return false


# ============================================================
# Edge intersection
# ============================================================


func edge_intersects_existing(a: int, b: int) -> bool:

	var a_pos := _node_position_2d(a)
	var b_pos := _node_position_2d(b)

	for edge in edges:

		var c := edge.x
		var d := edge.y

		# Edges sharing a vertex are allowed.
		if a == c or a == d or b == c or b == d:
			continue

		var c_pos := _node_position_2d(c)
		var d_pos := _node_position_2d(d)

		if segments_intersect(
			a_pos,
			b_pos,
			c_pos,
			d_pos
		):
			return true

	return false


# ============================================================
# Prevent edges passing through nodes
# ============================================================


func edge_passes_through_node(a: int, b: int) -> bool:

	var start := _node_position_2d(a)
	var end := _node_position_2d(b)

	for i in range(valid_nodes.size()):

		if i == a or i == b:
			continue

		var point := _node_position_2d(i)

		if point_on_segment(
			point,
			start,
			end
		):
			return true

	return false


# ============================================================
# 2D geometry
# ============================================================


## Returns true when two segments have a proper intersection
## or overlap along a non-zero-length interval.
##
## Touching at an endpoint is not considered an intersection.
func segments_intersect(
	a: Vector2,
	b: Vector2,
	c: Vector2,
	d: Vector2
) -> bool:

	var r := b - a
	var s := d - c

	var denominator := r.cross(s)
	var q := c - a

	# --------------------------------------------------------
	# Non-parallel segments.
	# --------------------------------------------------------

	if not is_zero_approx(denominator):

		var t := q.cross(s) / denominator
		var u := q.cross(r) / denominator

		return (
			t > 0.0
			and t < 1.0
			and u > 0.0
			and u < 1.0
		)

	# --------------------------------------------------------
	# Parallel but not collinear.
	# --------------------------------------------------------

	if not is_zero_approx(q.cross(r)):
		return false

	# --------------------------------------------------------
	# Collinear.
	#
	# Check whether the segments overlap.
	# --------------------------------------------------------

	var rr := r.length_squared()

	if is_zero_approx(rr):
		return false

	var t0 := q.dot(r) / rr
	var t1 := (d - a).dot(r) / rr

	# A non-zero overlap exists when the intervals
	# overlap inside the first segment.
	#
	# Endpoint touching is allowed.
	return max(t0, t1) > 0.0 and min(t0, t1) < 1.0


## Returns true when point lies anywhere on the segment.
func point_on_segment(
	point: Vector2,
	a: Vector2,
	b: Vector2
) -> bool:

	var ab := b - a
	var ap := point - a

	# Cross product tells us whether the point
	# lies on the line.
	if abs(ab.cross(ap)) > 0.00001:
		return false

	var dot := ap.dot(ab)

	if dot < 0.0:
		return false

	if dot > ab.length_squared():
		return false

	return true


# ============================================================
# Node positions
# ============================================================


func _node_position_2d(index: int) -> Vector2:

	var node := valid_nodes[index]

	if node == null:
		return Vector2.ZERO

	var local_position := (
		global_transform.affine_inverse()
		* node.global_position
	)

	return Vector2(
		local_position.x,
		local_position.z
	)


# ============================================================
# Find triangular faces
# ============================================================


## Finds every triangle in the graph.
##
## A triangle exists when three different nodes are connected
## by all three edges:
##
##     A ----- B
##      \     /
##       \   /
##         C
##
## Required edges:
##
##     A <-> B
##     B <-> C
##     C <-> A
##
## Every returned face contains exactly three node indices.
func find_faces() -> Array:

	var faces: Array = []

	# --------------------------------------------------------
	# Check every unique combination of three nodes.
	#
	# Using:
	#
	#     a < b < c
	#
	# ensures that each combination is tested exactly once.
	# --------------------------------------------------------

	for a in range(valid_nodes.size()):

		if valid_nodes[a] == null:
			continue

		for b in range(a + 1, valid_nodes.size()):

			if valid_nodes[b] == null:
				continue

			# A-B must exist.
			if not has_edge(a, b):
				continue

			for c in range(b + 1, valid_nodes.size()):

				if valid_nodes[c] == null:
					continue

				# A-C must exist.
				if not has_edge(a, c):
					continue

				# B-C must exist.
				if not has_edge(b, c):
					continue

				# All three edges exist, so this is a triangle.
				var face: Array[int] = [a, b, c]

				# Ignore degenerate triangles.
				var area := polygon_area(face)

				if abs(area) <= 0.00001:
					continue

				# Keep a consistent winding direction.
				if area < 0.0:
					face.reverse()

				faces.append(face)

	return faces


# ============================================================
# Edge key
# ============================================================


## Returns a direction-independent key for an edge.
##
## This means:
##
##     _edge_key(2, 5)
##
## and:
##
##     _edge_key(5, 2)
##
## return the same key.
func _edge_key(a: int, b: int) -> String:

	if a < b:
		return "%d:%d" % [a, b]

	return "%d:%d" % [b, a]


# ============================================================
# Polygon area
# ============================================================


func polygon_area(face: Array[int]) -> float:

	var area := 0.0

	for i in range(face.size()):

		var a := _node_position_2d(
			face[i]
		)

		var b := _node_position_2d(
			face[(i + 1) % face.size()]
		)

		area += a.x * b.y
		area -= b.x * a.y

	return area * 0.5


# ============================================================
# Create WebPolygon3D
# ============================================================


func create_polygon(node_indices: Array[int]) -> void:

	# Must be either:
	#
	#   2 nodes = standalone edge
	#   3 nodes = triangular face
	#
	if node_indices.size() != 2 and node_indices.size() != 3:
		return

	var polygon := WebPolygon3D.new()
	polygon.name = "WebPolygon"

	polygon_container.add_child(polygon)

	# Generated editor nodes should not be saved.
	if Engine.is_editor_hint():
		polygon.owner = null

	polygon.points.clear()

	for node_index in node_indices:

		if node_index < 0 or node_index >= valid_nodes.size():
			continue

		var node := valid_nodes[node_index]

		if node == null:
			continue

		var local_position := (
			global_transform.affine_inverse()
			* node.global_position
		)

		polygon.points.append(local_position)

	polygon.rings = rings
	polygon.curve_segments = curve_segments
	polygon.web_width = web_width
	polygon.ring_curvature = ring_curvature
	polygon.outer_curvature = outer_curvature
	polygon.line_color = line_color

	polygon.draw()
