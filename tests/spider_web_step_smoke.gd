extends SceneTree
## Keep spider support targets in sync with the visible web strands.

const SPIDER_SCENE := preload("res://src/features/spiders/base_spider.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if not await _check_drawn_strands_are_exposed():
		quit(1)
		return
	if not await _check_controller_support_refresh():
		quit(1)
		return
	if not await _check_web_step_threshold_and_replacement():
		quit(1)
		return
	print("SPIDER WEB STEP PASS: visible support, thresholds, and strand replacement")
	quit(0)


func _check_drawn_strands_are_exposed() -> bool:
	var web := Web3D.new()
	web.rings = 2
	web.curve_segments = 3
	web.valid_nodes = [
		_add_web_node(web, Vector3.ZERO),
		_add_web_node(web, Vector3(3.0, 0.0, 0.0)),
		_add_web_node(web, Vector3(0.0, 0.0, 3.0)),
	]
	web.edges = [Vector2i(0, 1), Vector2i(1, 2), Vector2i(2, 0)]
	root.add_child(web)
	await process_frame
	if not web.has_method("get_support_segments"):
		web.free()
		return _fail("Web drawing must expose its visible support segments")
	var segments: Array = web.call("get_support_segments")
	if segments.size() != 30:
		web.free()
		return _fail("Support segments must include outer curves, two rings, and radial strands")
	var families := { "outer": false, "ring": false, "radial": false }
	for segment in segments:
		if not segment is Dictionary or not segment.has("start") or not segment.has("end"):
			web.free()
			return _fail("Every support segment must expose its drawn endpoints")
		var strand_id: String = segment.get("strand_id", "")
		for family in families:
			if strand_id.contains(":" + family + ":"):
				families[family] = true
	if not families["outer"] or not families["ring"] or not families["radial"]:
		web.free()
		return _fail("Support segments must identify outer, ring, and radial strands")
	var previous_count := segments.size()
	web.remove_edge(0, 1)
	segments = web.call("get_support_segments")
	web.free()
	if segments.size() == previous_count:
		return _fail("Removing a web edge must refresh its exposed support geometry")
	return true


func _add_web_node(web: Web3D, point: Vector3) -> Node3D:
	var node := Node3D.new()
	web.add_child(node)
	node.position = point
	return node


func _check_controller_support_refresh() -> bool:
	var web := Web3D.new()
	web.rings = 0
	web.curve_segments = 2
	web.valid_nodes = [
		_add_web_node(web, Vector3.ZERO),
		_add_web_node(web, Vector3(3.0, 0.0, 0.0)),
	]
	web.edges = [Vector2i(0, 1)]
	root.add_child(web)
	var spider := SPIDER_SCENE.instantiate()
	root.add_child(spider)
	await process_frame
	var controller := spider.get_node("SpiderRig/LegController") as Node
	if not _has_property(controller, "targeting_mode") or not _has_property(
		controller, "support_web"
	):
		_free_nodes(spider, web)
		return _fail("Leg targeting mode and web support must be available in the inspector")
	if not controller.has_method("has_web_support"):
		_free_nodes(spider, web)
		return _fail("The leg controller must query cached web support")
	controller.set("targeting_mode", 1)
	controller.set("targeting_mode", 0)
	controller.set("support_web", web)
	var segments: Array = web.get_support_segments()
	var segment: Dictionary = segments[0]
	var point: Vector3 = (segment["start"] + segment["end"]) * 0.5
	if not controller.call("has_web_support", point):
		_free_nodes(spider, web)
		return _fail("Feet must be able to find a point on a visible web strand")
	web.edges.clear()
	web.rebuild()
	if controller.call("has_web_support", point):
		_free_nodes(spider, web)
		return _fail("Removing a web strand must immediately invalidate its support")
	_free_nodes(spider, web)
	return true


func _check_web_step_threshold_and_replacement() -> bool:
	var spider := SPIDER_SCENE.instantiate() as BaseSpider3D
	root.add_child(spider)
	var controller := spider.get_node("SpiderRig/LegController") as Node
	controller.set_process(false)
	controller.set("targeting_mode", 0)
	controller.set("step_distance", 0.2)
	controller.set("step_duration", 0.1)
	controller.set("idle_pose_step_distance", 1.0)
	await process_frame
	var foot := spider.get_node("SpiderRig/FootTargets/FootFrontLeft") as Marker3D
	var initial_foot_position := foot.global_position
	var web := _make_support_web(initial_foot_position)
	root.add_child(web)
	await process_frame
	controller.set("support_web", web)
	var passed: bool = controller.call("has_web_support", foot.global_position)
	if not passed:
		passed = _fail("A foot resting on a visible strand must remain supported")
	if passed:
		passed = _check_web_step_threshold(controller, spider, foot, initial_foot_position)
	if passed:
		controller.call("advance", 0.15)
		passed = _check_web_step_landing(controller, foot)
	if passed:
		passed = _check_web_step_replacement(controller, web, foot)
	if passed:
		passed = _check_web_hang_loose(controller, web)
	_free_nodes(spider, web)
	return passed


func _check_web_step_threshold(
	controller: Node,
	spider: BaseSpider3D,
	foot: Marker3D,
	initial_foot_position: Vector3
) -> bool:
	spider.position.x += 0.1
	controller.call("advance", 0.016)
	if not foot.global_position.is_equal_approx(initial_foot_position):
		return _fail("A foot must stay planted below its step threshold")
	spider.position.x += 0.2
	controller.call("advance", 0.016)
	if not controller.call("_is_stepping", 0):
		return _fail("A foot must start a lifted step after crossing its threshold")
	return true


func _check_web_step_landing(controller: Node, foot: Marker3D) -> bool:
	if (controller.call("is_dangling", 0)
			or not controller.call("has_web_support", foot.global_position)):
		return _fail("A completed web step must land on a reachable visible strand")
	return true


func _check_web_step_replacement(controller: Node, web: Web3D, foot: Marker3D) -> bool:
	web.edges = [Vector2i(2, 3)]
	if not controller.call("_is_stepping", 0):
		return _fail("A removed supporting strand must start replacement immediately")
	controller.call("advance", 0.15)
	if (controller.call("is_dangling", 0)
			or not controller.call("has_web_support", foot.global_position)):
		return _fail("A foot must re-place itself on another reachable strand")
	return true


func _check_web_hang_loose(controller: Node, web: Web3D) -> bool:
	web.edges = []
	if not controller.call("is_dangling", 0):
		return _fail("A foot must hang loose when its last support disappears")
	return true


func _make_support_web(foot_position: Vector3) -> Web3D:
	var web := Web3D.new()
	web.rings = 0
	web.curve_segments = 2
	web.valid_nodes = [
		_add_web_node(web, foot_position + Vector3(-0.12, 0.0, 0.0)),
		_add_web_node(web, foot_position + Vector3(0.12, 0.0, 0.0)),
		_add_web_node(web, foot_position + Vector3(-0.12, 0.0, 0.18)),
		_add_web_node(web, foot_position + Vector3(0.12, 0.0, 0.18)),
	]
	web.edges = [Vector2i(0, 1), Vector2i(2, 3)]
	return web


func _has_property(node: Object, property_name: String) -> bool:
	for property in node.get_property_list():
		if property.get("name") == property_name:
			return true
	return false


func _free_nodes(first: Node, second: Node) -> void:
	first.free()
	second.free()


func _fail(message: String) -> bool:
	push_error("SPIDER WEB STEP FAIL: " + message)
	return false
