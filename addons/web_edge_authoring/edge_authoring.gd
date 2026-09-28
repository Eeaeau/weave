@tool
extends RefCounted
## Converts selected branch markers to starting-web edges without manual indices.


static func edge_for_selection(anchors: Node3D, selected: Array[Node]) -> Vector2i:
	if selected.size() != 2:
		return Vector2i(-1, -1)
	var first := selected[0] as Marker3D
	var second := selected[1] as Marker3D
	if first == null or second == null or first == second:
		return Vector2i(-1, -1)
	if first.get_parent() != anchors or second.get_parent() != anchors:
		return Vector2i(-1, -1)
	var a := anchors.get_children().find(first)
	var b := anchors.get_children().find(second)
	return Vector2i(mini(a, b), maxi(a, b))


static func with_edge_added(edges: Array[Vector2i], edge: Vector2i) -> Array[Vector2i]:
	var updated := edges.duplicate()
	if edge.x < 0 or edge.y < 0 or edge.x == edge.y:
		return updated
	for existing in updated:
		if _same_edge(existing, edge):
			return updated
	updated.append(edge)
	return updated


static func with_edge_removed(edges: Array[Vector2i], edge: Vector2i) -> Array[Vector2i]:
	var updated := edges.duplicate()
	for index in range(updated.size()):
		if _same_edge(updated[index], edge):
			updated.remove_at(index)
			break
	return updated


static func _same_edge(a: Vector2i, b: Vector2i) -> bool:
	return (a.x == b.x and a.y == b.y) or (a.x == b.y and a.y == b.x)
