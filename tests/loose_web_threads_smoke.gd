extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var web := Web3D.new()
	web.rotation.x = PI / 2.0
	web.max_strand_length = 10.0
	var nodes: Array[Node3D] = [
		_add_anchor(web, Vector3.ZERO),
		_add_anchor(web, Vector3(3, 0, 0)),
		_add_anchor(web, Vector3(0, 0, 3)),
	]
	web.valid_nodes = nodes
	web.edges = [Vector2i(0, 1), Vector2i(1, 2), Vector2i(2, 0)]
	root.add_child(web)
	var inside := web.to_global(Vector3(0.5, 0, 0.5))
	var face := web.find_catch_face(inside)
	var initial := web.get_node_or_null("LooseThreads")
	var clean_start: bool = initial == null or initial.get_connection_count() == 0
	web.remove_edge(0, 1)
	var loose := web.get_node_or_null("LooseThreads") as MeshInstance3D
	if loose == null:
		web.free()
		_fail("Destroyed connection left no loose threads")
		return
	if (not _check_sway(loose, nodes[0]) or not _check_gust(loose)
			or not _check_mirrored(web, loose, nodes[0])):
		web.free()
		return
	if web.has_catch_face(face) or not clean_start:
		web.free()
		_fail("Initial webs must be clean and destroyed triangles must stop catching")
		return
	web.remove_edge(1, 2)
	web.remove_edge(2, 0)
	web.rebuild()
	if not web.get_support_segments().is_empty() or loose.get_connection_count() != 3:
		web.free()
		_fail("Remnants became walkable or duplicated during rebuild")
		return
	loose.advance(100.0)
	if loose.get_connection_count() != 3:
		web.free()
		_fail("Loose threads expired before their connections were rebuilt")
		return
	if not _check_repair(web, loose):
		web.free()
		return
	web.free()
	await process_frame
	print("LOOSE THREADS PASS: destruction, anchored sway, repair and cosmetic-only support")
	quit(0)


func _check_sway(loose: MeshInstance3D, anchor: Node3D) -> bool:
	loose.set_process(false)
	if loose.get_connection_count() != 1 or loose.mesh.get_surface_count() == 0:
		return _fail("One destroyed edge must produce a rendered pair of thread ends")
	var before: PackedVector3Array = loose.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	loose.advance(0.5)
	var after: PackedVector3Array = loose.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	if before == after:
		return _fail("Loose threads did not sway in ambient wind")
	anchor.position.x += 0.2
	loose.advance(0.0)
	after = loose.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	if not ((after[0] + after[1]) * 0.5).is_equal_approx(loose.to_local(anchor.global_position)):
		return _fail("The attached thread end did not follow its anchor")
	if not loose.find_children("*", "CollisionObject3D", true, false).is_empty():
		return _fail("Cosmetic threads created physics collision")
	return true


func _check_repair(web: Web3D, loose: MeshInstance3D) -> bool:
	for edge in [Vector2i(0, 1), Vector2i(1, 2), Vector2i(2, 0)]:
		if not web.add_edge(edge.x, edge.y):
			return _fail("A cosmetic remnant prevented rebuilding its connection")
	if loose.get_connection_count() != 0 or loose.visible:
		return _fail("Rebuilt connections kept their loose ends")
	var midpoint := (web.valid_nodes[0].global_position + web.valid_nodes[1].global_position) * 0.5
	web.deal_damage(Vector2(midpoint.x, midpoint.y), 0.2, 1000)
	if loose.get_connection_count() != 1:
		return _fail("Damage must create remnants once despite repeated geometry rebuilds")
	return true


func _fail(message: String) -> bool:
	push_error("LOOSE THREADS FAIL: " + message)
	quit(1)
	return false


func _add_anchor(web: Web3D, point: Vector3) -> Marker3D:
	var anchor := Marker3D.new()
	anchor.position = point
	web.add_child(anchor)
	return anchor


func _check_gust(loose: MeshInstance3D) -> bool:
	var wind: WindEvent3D = load("res://src/features/wind/wind_event.tscn").instantiate()
	root.add_child(wind)
	wind.set_process(false)
	wind.is_active = true
	loose.advance(1.0)
	var amplified := float(loose.get("_gust_strength")) > 0.99
	wind.is_active = false
	loose.advance(1.0)
	var settled := float(loose.get("_gust_strength")) < 0.01
	wind.free()
	if not amplified or not settled:
		return _fail("Threads must respond to the real wind event and settle after it ends")
	return true


func _check_mirrored(web: Web3D, loose: MeshInstance3D, anchor: Node3D) -> bool:
	web.rotation.x = -PI / 2.0
	web.scale.x = -1.0
	return _check_sway(loose, anchor)
