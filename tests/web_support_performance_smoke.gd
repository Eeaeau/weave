extends SceneTree
## A dense web renders one copy of each strand during creation and refresh.

var geometry_events := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var web := _make_dense_web()
	web.geometry_changed.connect(_on_geometry_changed)
	root.add_child(web)
	if not _check_single_render(web) or geometry_events != 1:
		web.free()
		quit(1)
		return
	var segments := web.get_support_segments()
	if segments.size() != 3942 or web.find_catch_face(Vector3(1.3, 0.0, 0.7)).is_empty():
		web.free()
		push_error("WEB SUPPORT PERFORMANCE FAIL: visible strands or catch area changed")
		quit(1)
		return
	web.valid_nodes[0].position.x -= 0.25
	web.rebuild()
	if not _check_single_render(web) or geometry_events != 2:
		web.free()
		quit(1)
		return
	if web.get_support_segments().size() != 3942:
		web.free()
		push_error("WEB SUPPORT PERFORMANCE FAIL: movement lost visible strands")
		quit(1)
		return
	web.free()
	print("WEB SUPPORT PERFORMANCE PASS: one render per polygon, strands, catch area, signals")
	quit(0)


func _make_dense_web() -> Web3D:
	var web := Web3D.new()
	var nodes: Array[Node3D] = []
	var edge_list: Array[Vector2i] = []
	for z in range(4):
		for x in range(4):
			nodes.append(_add_web_node(web, Vector3(x * 2.0, 0.0, z * 2.0)))
	for z in range(4):
		for x in range(4):
			var index := z * 4 + x
			if x < 3:
				edge_list.append(Vector2i(index, index + 1))
			if z < 3:
				edge_list.append(Vector2i(index, index + 4))
			if x < 3 and z < 3:
				edge_list.append(Vector2i(index, index + 5))
	web.valid_nodes = nodes
	web.edges = edge_list
	return web


func _add_web_node(web: Web3D, position: Vector3) -> Node3D:
	var node := Node3D.new()
	web.add_child(node)
	node.position = position
	return node


func _check_single_render(web: Web3D) -> bool:
	for polygon in web.polygon_container.get_children():
		if polygon.get_child_count() != 1:
			push_error("WEB SUPPORT PERFORMANCE FAIL: polygon generated duplicate mesh containers")
			return false
	return true


func _on_geometry_changed() -> void:
	geometry_events += 1
