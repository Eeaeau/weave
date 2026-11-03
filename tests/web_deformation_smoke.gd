extends SceneTree
# gdstyle:ignore-file=quality/allocation-in-loop,quality/await-in-loop


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var web := Web3D.new()
	web.rotation.x = PI / 2.0
	web.rings = 2
	web.curve_segments = 2
	for point in [Vector3(-2, 0, -1), Vector3(2, 0, -1), Vector3(0, 0, 2)]:
		var anchor := Marker3D.new()
		web.add_child(anchor)
		anchor.position = point
		web.valid_nodes.append(anchor)
	web.edges = [Vector2i(0, 1), Vector2i(1, 2), Vector2i(2, 0)]
	root.add_child(web)
	await process_frame
	var model := WebSpringModel3D.new()
	model.setup(web)
	var coarse_points: int = model._points.size()
	web.curve_segments = 24
	model.setup(web)
	if model._points.size() != coarse_points or model._points.size() > 24 * 24:
		_fail("Decorative curve detail must not increase global simulation resolution")
		return
	model.maximum_sag = 1.0
	var loads: Array[Dictionary] = [{ "point": Vector3.ZERO, "weight": 0.25 }]
	for frame in range(600):
		model.advance(1.0 / 120.0, loads)
	var first: Vector3 = model.displacement_at(Vector3.ZERO)
	if first.y >= -0.001:
		_fail("A spider load must pull the web downward")
		return
	loads.append({ "point": Vector3.ZERO, "weight": 0.25 })
	for frame in range(600):
		model.advance(1.0 / 120.0, loads)
	var second: Vector3 = model.displacement_at(Vector3.ZERO)
	if absf(second.y) <= absf(first.y) * 1.5:
		_fail("Two spiders sharing a web must both contribute load")
		return
	for anchor in web.valid_nodes:
		if model.displacement_at(anchor.global_position).length() > 0.00001:
			_fail("Authored web nodes must stay fixed")
			return
	model.effect_enabled = false
	model.advance(0.1, loads)
	if not model.displacement_at(Vector3.ZERO).is_zero_approx():
		_fail("Disabling deformation must restore the undeformed presentation")
		return
	web.remove_edge(0, 1)
	model.setup(web)
	if model.segment_count() != web.get_support_segments().size():
		_fail("A rebuilt graph must discard removed strands")
		return
	web.scale *= 100.0
	model.setup(web)
	assert(model._points.size() <= 24 * 24, "A growing map must retain a bounded simulation")
	web.queue_free()
	await process_frame
	await create_timer(0.2).timeout
	print("WEB DEFORMATION PASS: fixed nodes, combined loads, gravity, disabling and rebuilds")
	quit(0)


func _fail(message: String) -> void:
	push_error("WEB DEFORMATION FAIL: " + message)
	quit(1)
