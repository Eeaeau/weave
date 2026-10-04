@tool
class_name WebTopology
extends RefCounted
## Pure graph and planar geometry decisions for a Web3D.

var nodes: Array[Node3D] = []
var edges: Array[Vector2i] = []
var web_transform := Transform3D.IDENTITY


func configure(web_nodes: Array[Node3D], web_edges: Array[Vector2i],
		current_transform: Transform3D) -> void:
	nodes = web_nodes
	edges = web_edges
	web_transform = current_transform


func can_add_edge(a: int, b: int) -> bool:
	if a == b or a < 0 or a >= nodes.size() or b < 0 or b >= nodes.size():
		return false
	return not has_edge(a, b) and not edge_passes_through_node(a, b) \
		and not edge_intersects_existing(a, b)


func has_edge(a: int, b: int) -> bool:
	for edge in edges:
		if (edge.x == a and edge.y == b) or (edge.x == b and edge.y == a):
			return true
	return false


func edge_intersects_existing(a: int, b: int) -> bool:
	var start := node_position_2d(a)
	var end := node_position_2d(b)
	for edge in edges:
		if a == edge.x or a == edge.y or b == edge.x or b == edge.y:
			continue
		if segments_intersect(start, end,
				node_position_2d(edge.x), node_position_2d(edge.y)):
			return true
	return false


func edge_passes_through_node(a: int, b: int) -> bool:
	var start := node_position_2d(a)
	var end := node_position_2d(b)
	for index in range(nodes.size()):
		if index != a and index != b and point_on_segment(
				node_position_2d(index), start, end):
			return true
	return false


func node_position_2d(index: int) -> Vector2:
	var node := nodes[index]
	if node == null:
		return Vector2.ZERO
	var local_position := web_transform.affine_inverse() * node.global_position
	return Vector2(local_position.x, local_position.z)


func find_faces() -> Array:
	var faces: Array = []
	for a in range(nodes.size()):
		if nodes[a] == null:
			continue
		for b in range(a + 1, nodes.size()):
			if nodes[b] == null or not has_edge(a, b):
				continue
			for c in range(b + 1, nodes.size()):
				if nodes[c] == null or not has_edge(a, c) or not has_edge(b, c):
					continue
				var face: Array[int] = [a, b, c]
				var area := polygon_area(face)
				if absf(area) <= 0.00001:
					continue
				if area < 0.0:
					face.reverse()
				faces.append(face)
	return faces


func polygon_area(face: Array[int]) -> float:
	var area := 0.0
	for index in range(face.size()):
		var a := node_position_2d(face[index])
		var b := node_position_2d(face[(index + 1) % face.size()])
		area += a.x * b.y - b.x * a.y
	return area * 0.5


## Endpoint contact is allowed; a crossing or nonzero overlap is not.
static func segments_intersect(a: Vector2, b: Vector2, c: Vector2,
		d: Vector2) -> bool:
	var r := b - a
	var s := d - c
	var denominator := r.cross(s)
	var offset := c - a
	if not is_zero_approx(denominator):
		var t := offset.cross(s) / denominator
		var u := offset.cross(r) / denominator
		return t > 0.0 and t < 1.0 and u > 0.0 and u < 1.0
	if not is_zero_approx(offset.cross(r)):
		return false
	var length_squared := r.length_squared()
	if is_zero_approx(length_squared):
		return false
	var t0 := offset.dot(r) / length_squared
	var t1 := (d - a).dot(r) / length_squared
	return maxf(t0, t1) > 0.0 and minf(t0, t1) < 1.0


static func point_on_segment(point: Vector2, a: Vector2, b: Vector2) -> bool:
	var ab := b - a
	var ap := point - a
	if absf(ab.cross(ap)) > 0.00001:
		return false
	var distance := ap.dot(ab)
	return distance >= 0.0 and distance <= ab.length_squared()
