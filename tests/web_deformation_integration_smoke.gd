extends SceneTree
# gdstyle:ignore-file=quality/allocation-in-loop,quality/await-in-loop

var _samples := 0
var _contact_error := 0.0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var web := Web3D.new()
	web.rotation.x = PI / 2.0
	web.rings = 4
	web.curve_segments = 1
	for point in [Vector3(-3, 0, -2), Vector3(3, 0, -2), Vector3(0, 0, 3)]:
		var anchor := Marker3D.new()
		web.add_child(anchor)
		anchor.position = point
		web.valid_nodes.append(anchor)
	web.edges = [Vector2i(0, 1), Vector2i(1, 2), Vector2i(2, 0)]
	root.add_child(web)
	var spiders: Array[BaseSpider3D] = []
	var gaits: Array[SpiderContactGait3D] = []
	for side in range(2):
		var scene := load("res://src/features/spiders/base_spider.tscn")
		var spider := scene.instantiate() as BaseSpider3D
		spider.rotation.x = PI / 2.0
		spider.position.x = -0.2 if side == 0 else 0.2
		root.add_child(spider)
		spiders.append(spider)
		spider.set_process(false)
		var gait := spider.get_node("SpiderRig/LegController") as SpiderContactGait3D
		gait.support_web = web
		gait.set_process(false)
		gaits.append(gait)
	var service := web.get_deformation() as WebDeformation3D
	service.set_process(false)
	if gaits[0].get_deformation() != service or gaits[1].get_deformation() != service:
		_fail("Spiders sharing a web must share its deformation service")
		return
	for index in range(spiders.size()):
		var strokes := spiders[index].get_node("SpiderRig/LegStrokes") as SpiderLegStroke3D
		strokes.pose_drawn.connect(_capture.bind(strokes, gaits[index], service))
	for frame in range(120):
		for gait in gaits:
			gait.advance(1.0 / 60.0)
		service.advance_visuals(1.0 / 60.0)
		await process_frame
	if _samples == 0 or _contact_error > 0.0001:
		var details := [_samples, _contact_error]
		_fail("Rendered feet separated from the web: %s samples, %s error" % details)
		return
	var damage_bar := web.polygon_container.get_node("EdgeHealthBar_0") as Node3D
	damage_bar.show()
	service.advance_visuals(1.0 / 60.0)
	if not damage_bar.is_visible_in_tree():
		_fail("Deformed strands must preserve web damage indicators")
		return
	for spider in spiders:
		if not spider.body.visible or not spider.body.material_override is ShaderMaterial:
			_fail("Body deformation must preserve the original visible sprite")
			return
	web.remove_edge(0, 1)
	if service.model.segment_count() != web.get_support_segments().size():
		_fail("The live deformation graph retained destroyed strands")
		return
	spiders[0].queue_free()
	await process_frame
	if service._groups.size() != 1:
		_fail("A removed spider left stale load registrations")
		return
	spiders[1].queue_free()
	var detached := spiders[1].get_node("SpiderRig/LegStrokes")
	detached._queue_redraw()
	detached.get_parent().remove_child(detached)
	await process_frame
	detached.free()
	web.queue_free()
	await process_frame
	await create_timer(0.2).timeout
	print("WEB DEFORMATION INTEGRATION PASS: %s contacts, topology and cleanup" % _samples)
	quit(0)


func _capture(
	strokes: SpiderLegStroke3D,
	gait: SpiderContactGait3D,
	service: WebDeformation3D,
) -> void:
	if not is_instance_valid(service):
		return
	for leg in range(strokes.LEG_SPECS.size()):
		if leg >= strokes.mesh.get_surface_count():
			continue
		var index := SpiderLegController3D.FOOT_NAMES.find(strokes.LEG_SPECS[leg][3])
		var binding := service.contact_target(gait, index)
		if binding.is_empty():
			continue
		var raw_tip: Vector3 = service._groups[gait].tips.get(index, Vector3.INF)
		if raw_tip.distance_to(binding.anchor) > service.maximum_contact_gap:
			continue
		var vertices: PackedVector3Array = strokes.mesh.surface_get_arrays(leg)[Mesh.ARRAY_VERTEX]
		var tip := strokes.to_global((vertices[-2] + vertices[-1]) * 0.5)
		_contact_error = maxf(_contact_error, tip.distance_to(binding.point))
		_samples += 1


func _fail(message: String) -> void:
	push_error("WEB DEFORMATION INTEGRATION FAIL: " + message)
	quit(1)
