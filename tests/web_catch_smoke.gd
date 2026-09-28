extends SceneTree
## Catch regions follow the visible curved web and update with its edges.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if not _check_triangle():
		quit(1)
		return
	if not _check_standalone_edge():
		quit(1)
		return
	if not _check_geometry_api():
		quit(1)
		return
	if not await _check_match_claim():
		quit(1)
		return
	print("WEB CATCH PASS: curved regions and wind claims")
	quit(0)


func _check_triangle() -> bool:
	var web := _make_web(true)
	root.add_child(web)
	var inside := web.to_global(Vector3(0.5, 0.1, 0.5))
	var curved_corner := web.to_global(Vector3(1.5, 0.1, 0.005))
	var face := web.find_catch_face(inside)
	if face.is_empty():
		web.free()
		return _fail("A contact inside the visible web must catch")
	if not web.find_catch_face(curved_corner).is_empty():
		web.free()
		return _fail("A point inside the straight triangle but outside its curved web must miss")
	if not web.find_catch_face(web.to_global(Vector3(0.5, 2.0, 0.5))).is_empty():
		web.free()
		return _fail("A contact on another depth plane must miss")
	web.remove_edge(0, 1)
	if not web.find_catch_face(inside).is_empty():
		web.free()
		return _fail("Removing a triangle edge must remove its catch region")
	web.add_edge(0, 1)
	if web.find_catch_face(inside) != face:
		web.free()
		return _fail("Rebuilding the same triangle must retain its face identity")
	web.free()
	return true


func _check_standalone_edge() -> bool:
	var web := _make_web(false)
	root.add_child(web)
	var missed := web.find_catch_face(web.to_global(Vector3(1.5, 0.1, 0.0))).is_empty()
	web.free()
	if not missed:
		return _fail("An isolated strand must not catch in the first version")
	return true


func _check_geometry_api() -> bool:
	var web := Web3D.new()
	var nodes: Array[Node3D] = []
	for point in [Vector3.ZERO, Vector3(3, 0, 0), Vector3(0, 0, 3), Vector3(3, 0, 3)]:
		nodes.append(_add_web_node(web, point))
	web.valid_nodes = nodes
	web.edges = [
		Vector2i(0, 1), Vector2i(1, 2), Vector2i(2, 0), Vector2i(2, 3),
	]
	web.position = Vector3(10, 20, 0)
	web.rotation.x = PI / 2.0
	root.add_child(web)
	web.rebuild()

	var triangles: Array = web.get_triangles()
	if triangles.size() != 1 or triangles[0].size() != 3:
		web.free()
		return _fail("get_triangles must return each connected triangular face once")
	var triangle: Array = triangles[0]
	if not _contains_point(triangle, Vector2(10, 20)) \
			or not _contains_point(triangle, Vector2(13, 20)) \
			or not _contains_point(triangle, Vector2(10, 17)):
		web.free()
		return _fail("get_triangles must return triangle vertex positions")

	var standalone: Array = web.get_stand_alone_edges()
	if standalone.size() != 1 or standalone[0].size() != 2:
		web.free()
		return _fail("get_stand_alone_edges must exclude triangle edges")
	var edge: Array = standalone[0]
	if not _contains_point(edge, Vector2(10, 17)) or not _contains_point(edge, Vector2(13, 17)):
		web.free()
		return _fail("get_stand_alone_edges must return standalone endpoint positions")
	web.free()
	return true


func _contains_point(points: Array, expected: Vector2) -> bool:
	for point in points:
		if point is Vector2 and point.is_equal_approx(expected):
			return true
	return false


func _check_match_claim() -> bool:
	var match_scene: WebMatch3D = load("res://src/game/web_match.tscn").instantiate()
	var event: WindEvent3D = match_scene.get_node("BranchCanopy/WindEvent")
	event.group_size = 1
	root.add_child(match_scene)
	var web := match_scene.get_node_or_null("WebA") as Web3D
	if web == null or web.get_node_or_null("CaughtItems") == null:
		_free_scene(match_scene)
		return _fail("The match needs a player web with a persistent caught-item container")
	var face: Array = web.find_faces()[0]
	var contact := Vector3.ZERO
	for node_index in face:
		contact += web.valid_nodes[node_index].global_position
	contact /= 3.0
	var flight: WindFlight3D = event.get_node("Flights").get_child(0)
	var item := flight.item
	if item.pickup_area.monitoring:
		_free_scene(match_scene)
		return _fail("An airborne collectible must not be pickable")
	flight.global_position = contact
	event._on_plane_crossed(item, 0, contact)
	var caught := web.get_node("CaughtItems")
	if caught.get_child_count() != 1 or item.get_parent() != caught.get_child(0):
		_free_scene(match_scene)
		return _fail("A web contact must claim the item exactly once")
	if not item.global_position.is_equal_approx(contact):
		_free_scene(match_scene)
		return _fail("Claiming must preserve the item at its web contact")
	var lifecycle_ok := await _check_caught_lifecycle(web, face, caught, item)
	_free_scene(match_scene)
	await create_timer(1.0).timeout
	return lifecycle_ok


func _check_caught_lifecycle(web: Web3D, face: Array, caught: Node,
		item: Collectible3D) -> bool:
	await process_frame
	if not item.pickup_area.monitoring:
		return _fail("A caught item must become pickable")
	var support := caught.get_child(0)
	web.remove_edge(face[0], face[1])
	await process_frame
	if not is_instance_valid(support) or item.pickup_area.monitoring:
		return _fail("Removing the supporting face must release its caught item")
	await create_timer(0.6).timeout
	if is_instance_valid(support):
		return _fail("An unsupported caught item must finish falling and disappear")
	return true


func _free_scene(node: Node) -> void:
	_stop_audio(node)
	node.free()


func _stop_audio(node: Node) -> void:
	if node is AudioStreamPlayer:
		node.stop()
		node.stream = null
	for child in node.get_children():
		_stop_audio(child)


func _make_web(triangle: bool) -> Web3D:
	var web := Web3D.new()
	web.rotation.x = PI / 2.0
	var nodes: Array[Node3D] = []
	for point in [Vector3.ZERO, Vector3(3, 0, 0), Vector3(0, 0, 3)]:
		nodes.append(_add_web_node(web, point))
	web.valid_nodes = nodes
	var edge_list: Array[Vector2i] = [Vector2i(0, 1)]
	if triangle:
		edge_list.append_array([Vector2i(1, 2), Vector2i(2, 0)])
	web.edges = edge_list
	return web


func _add_web_node(web: Web3D, point: Vector3) -> Node3D:
	var node := Node3D.new()
	web.add_child(node)
	node.position = point
	return node


func _fail(message: String) -> bool:
	push_error("WEB CATCH FAIL: " + message)
	return false
