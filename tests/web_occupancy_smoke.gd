extends SceneTree
# gdstyle:ignore-file=quality/allocation-in-loop

const SPIDER_SCENE := preload("res://src/features/spiders/base_spider.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var web := Web3D.new()
	web.rotation.x = PI / 2.0
	for shift in [0.0, 12.0]:
		for point in [Vector3(-3, 0, -2), Vector3(3, 0, -2), Vector3(0, 0, 3)]:
			var anchor := Marker3D.new()
			anchor.position = point + Vector3.RIGHT * shift
			web.add_child(anchor)
			web.valid_nodes.append(anchor)
	web.edges = [Vector2i(0, 1), Vector2i(1, 2), Vector2i(2, 0),
		Vector2i(3, 4), Vector2i(4, 5), Vector2i(5, 3)]
	root.add_child(web)
	var service := web.get_deformation() as WebDeformation3D
	await process_frame
	await process_frame
	var cold_sleeping := not service.is_processing() and not service.visible
	var spider := SPIDER_SCENE.instantiate() as BaseSpider3D
	spider.rotation.x = PI / 2.0
	root.add_child(spider)
	spider.set_process(false)
	var gait := spider.get_node("SpiderRig/LegController") as SpiderContactGait3D
	gait.set_process(false)
	gait.support_web = web
	service.set_process(false)
	for frame in range(30):
		gait.advance(1.0 / 60.0)
		service.advance_visuals(1.0 / 60.0)
	if not cold_sleeping or not service.is_region_dynamic(0) or service.is_region_dynamic(1):
		_fail("Only the occupied patch should use dynamic rendering")
		return
	var first_samples: int = service.model.simulated_point_count()
	if first_samples == 0 or first_samples >= service.model._points.size():
		_fail("A distant empty patch must not add spring integration work")
		return
	spider.position.x = 12.0
	for frame in range(180):
		gait.advance(1.0 / 60.0)
		service.advance_visuals(1.0 / 60.0)
	if service.is_region_dynamic(0) or not service.is_region_dynamic(1):
		_fail("Leaving a patch must settle it and wake the destination patch")
		return
	service.unregister_gait(gait)
	for frame in range(180):
		service.advance_visuals(1.0 / 60.0)
	if (service.visible or service.is_region_dynamic(0) or service.is_region_dynamic(1)
			or service.model.simulated_point_count() != 0 or service.is_processing()):
		_fail("An empty web must return to static rendering and stop processing")
		return
	service.register_gait(gait)
	service.advance_visuals(1.0 / 60.0)
	if not service.visible or not service.is_processing():
		_fail("A returning spider must wake a sleeping web")
		return
	web.valid_nodes = []
	service.advance_visuals(3.0)
	if service.visible or service._static_mesh.mesh.get_surface_count() != 0:
		_fail("Removing every anchor must discard both dynamic and dormant geometry")
		return
	spider.queue_free()
	web.queue_free()
	await process_frame
	if await _check_shared_boundary():
		await create_timer(0.2).timeout
		print("WEB OCCUPANCY PASS: local patches sleep, settle and wake with spiders")
		quit(0)


func _check_shared_boundary() -> bool:
	var web := Web3D.new()
	web.rotation.x = PI / 2.0
	web.outer_curvature = 0.0
	for point in [Vector3(-8, 0, -6), Vector3(0, 0, -6),
			Vector3(-8, 0, 6), Vector3(0, 0, 6)]:
		var anchor := Marker3D.new()
		anchor.position = point
		web.add_child(anchor)
		web.valid_nodes.append(anchor)
	web.edges = [Vector2i(0, 1), Vector2i(1, 2), Vector2i(2, 0),
		Vector2i(1, 3), Vector2i(3, 2)]
	root.add_child(web)
	var spider := SPIDER_SCENE.instantiate() as BaseSpider3D
	spider.rotation.x = PI / 2.0
	spider.position = Vector3(-7, 5, 0)
	root.add_child(spider)
	spider.set_process(false)
	var gait := spider.get_node("SpiderRig/LegController") as SpiderContactGait3D
	gait.set_process(false)
	gait.support_web = web
	var service := web.get_deformation() as WebDeformation3D
	service.set_process(false)
	gait.advance(1.0 / 60.0)
	service.advance_visuals(1.0 / 60.0)
	var dormant := web.polygon_container.get_child(1) as WebPolygon3D
	var expected := (dormant.get_support_segments().size() - web.curve_segments) * 6
	var passed: bool = (service.is_region_dynamic(0) and not service.is_region_dynamic(1)
		and service._static_mesh.mesh.surface_get_array_len(0) == expected)
	spider.queue_free()
	web.queue_free()
	await process_frame
	if not passed:
		_fail("A sleeping neighbor must not draw an undeformed copy of the shared dynamic border")
	return passed


func _fail(message: String) -> void:
	push_error("WEB OCCUPANCY FAIL: " + message)
	quit(1)
