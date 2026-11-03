extends SceneTree
# gdstyle:ignore-file=quality/allocation-in-loop


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var web := Web3D.new()
	web.position = Vector3(5, -3, 2)
	web.rotation = Vector3(0.8, 0.4, -0.2)
	web.scale.x = 2.0
	for point in [Vector3(-2, 0, -1), Vector3(2, 0, -1), Vector3(0, 0, 2), Vector3(2, 0, 2)]:
		var anchor := Marker3D.new()
		anchor.position = point
		web.add_child(anchor)
		web.valid_nodes.append(anchor)
	web.edges = [Vector2i(0, 1), Vector2i(1, 2), Vector2i(2, 0), Vector2i(1, 3), Vector2i(3, 2)]
	root.add_child(web)
	var segments := web.get_support_segments()
	var normal := web.global_basis.y.normalized()
	for sample in range(20):
		var local_point := Vector3(sin(sample) * 3, 0, cos(sample * 0.7) * 3)
		var point := web.to_global(local_point)
		for radius: float in [0.0, 0.04, 0.32, 1.5]:
			if not _contains_nearby(web, point + normal * 3, radius, segments):
				push_error("WEB SUPPORT QUERY FAIL: omitted support or reordered candidates")
				quit(1)
				return
	assert(web.get_support_segments_near(web.global_position, 0.04).size() < segments.size() / 2,
		"Local queries must not scan the whole web")
	web.remove_edge(0, 1)
	assert(web.get_support_segments_near(web.global_position, 12).size()
		== web.get_support_segments().size(), "Topology changes must invalidate shared queries")
	web.edges = []
	assert(web.get_support_segments_near(web.global_position, 12).is_empty(),
		"Destroyed support must not remain in the query cache")
	web.edges = [Vector2i(0, 3)]
	assert(_contains_nearby(web, web.valid_nodes[0].global_position, 0.1,
		web.get_support_segments()), "Standalone strands must remain queryable")
	web.queue_free()
	await process_frame
	print("WEB SUPPORT QUERY PASS: conservative, ordered, rotated, rebuilt and standalone support")
	quit(0)


func _contains_nearby(web: Web3D, point: Vector3, radius: float,
		segments: Array[Dictionary]) -> bool:
	var nearby := web.get_support_segments_near(point, radius)
	var previous := -1
	for segment in nearby:
		var index := segments.find(segment)
		if index <= previous:
			print("QUERY ORDER: ", index, " after ", previous, " segment=", segment)
			return false
		previous = index
	var normal := web.global_basis.y.normalized()
	var projected := point - normal * (point - web.global_position).dot(normal)
	for segment in segments:
		var start: Vector3 = segment.start
		var line: Vector3 = segment.end - start
		var along := (projected - start).dot(line) / maxf(line.length_squared(), 0.000001)
		var closest := start + line * clampf(along, 0.0, 1.0)
		if projected.distance_to(closest) <= radius and not nearby.has(segment):
			print("QUERY OMITTED: point=", point, " radius=", radius, " segment=", segment)
			return false
	return true
