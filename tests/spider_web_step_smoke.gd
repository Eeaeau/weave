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
	if not await _check_opposite_side_only_support():
		quit(1)
		return
	if not await _check_all_feet_share_one_strand():
		quit(1)
		return
	if not await _check_dense_web_cases():
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
	_freeze_spider_animation(spider)
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


func _check_opposite_side_only_support() -> bool:
	var spider := SPIDER_SCENE.instantiate() as BaseSpider3D
	root.add_child(spider)
	var controller := spider.get_node("SpiderRig/LegController") as Node
	controller.set_process(false)
	await process_frame
	_freeze_spider_animation(spider)
	var foot_position := (
		spider.get_node("SpiderRig/FootTargets/FootFrontLeft") as Marker3D
	).global_position
	var web := _make_line_web(
		Vector3(0.02, foot_position.y, foot_position.z),
		Vector3(0.2, foot_position.y, foot_position.z)
	)
	root.add_child(web)
	await process_frame
	controller.set("support_web", web)
	_mark_feet_dangling(controller)
	var landing: Dictionary = controller.call("_choose_destination", 0)
	if landing.is_empty():
		_free_nodes(spider, web)
		return _fail("Web mode must accept reachable support on the opposite side")
	var local_landing: Vector3 = spider.get_node("SpiderRig").to_local(landing["point"])
	if local_landing.x <= 0.0:
		_free_nodes(spider, web)
		return _fail("The only visible support must be reachable across the body's center")
	controller.set("targeting_mode", SpiderLegController3D.TargetingMode.FREE_STEP_DEBUG)
	if controller.call("can_land", 0, landing["point"]):
		_free_nodes(spider, web)
		return _fail("Free-step debug must keep its natural-side landing restriction")
	_free_nodes(spider, web)
	return true


func _check_all_feet_share_one_strand() -> bool:
	var spider := SPIDER_SCENE.instantiate() as BaseSpider3D
	root.add_child(spider)
	var controller := spider.get_node("SpiderRig/LegController") as Node
	controller.set_process(false)
	await process_frame
	_freeze_spider_animation(spider)
	var web := _make_line_web(Vector3(0.0, 0.5, -5.0), Vector3(0.0, 0.5, 5.0))
	root.add_child(web)
	await process_frame
	controller.set("support_web", web)
	_mark_feet_dangling(controller)
	var destinations: Array[Vector3] = []
	var strand_ids: Array[String] = []
	for foot_index in range(8):
		var landing: Dictionary = controller.call("_choose_destination", foot_index)
		if landing.is_empty():
			_free_nodes(spider, web)
			return _fail("All eight feet must find room on a long shared web strand")
		var point: Vector3 = landing["point"]
		var strand_id: String = landing["strand_id"]
		if not controller.call("has_web_support", point):
			_free_nodes(spider, web)
			return _fail("Every shared-strand destination must lie on visible support")
		if strand_ids.size() > 0 and strand_id != strand_ids[0]:
			_free_nodes(spider, web)
			return _fail("All eight destinations must use the same physical strand")
		if not _keeps_shared_landing_clear(controller, foot_index, point, destinations):
			_free_nodes(spider, web)
			return _fail("Shared-strand destinations must stay spaced and non-crossing")
		if not _is_within_leg_reach(controller, foot_index, point):
			_free_nodes(spider, web)
			return _fail("Shared-strand landings must remain within leg reach")
		_set_foot_support(controller, foot_index, point, strand_id)
		destinations.append(point)
		strand_ids.append(strand_id)
	_free_nodes(spider, web)
	return true


func _check_dense_web_cases() -> bool:
	if not await _check_removed_web_releases_cached_support():
		return false
	return await _check_dense_web_landings()


func _check_dense_web_landings() -> bool:
	var web := Web3D.new()
	web.rings = 8
	web.curve_segments = 8
	web.valid_nodes.append(_add_web_node(web, Vector3(0.0, 0.5, 0.0)))
	for index in range(8):
		var angle := TAU * float(index) / 8.0
		web.valid_nodes.append(_add_web_node(
			web, Vector3(cos(angle) * 3.0, 0.5, sin(angle) * 3.0)
		))
		web.edges.append(Vector2i(index + 1, (index + 1) % 8 + 1))
		web.edges.append(Vector2i(0, index + 1))
	root.add_child(web)
	var spider := SPIDER_SCENE.instantiate() as BaseSpider3D
	root.add_child(spider)
	var controller := spider.get_node("SpiderRig/LegController") as Node
	controller.set_process(false)
	await process_frame
	_freeze_spider_animation(spider)
	controller.set("support_web", web)
	_mark_feet_dangling(controller)
	var segments: Array = web.get_support_segments()
	if segments.size() < 1000:
		_free_nodes(spider, web)
		return _fail("Dense web fixture must include at least 1000 visible segments")
	var start := Time.get_ticks_usec()
	for foot_index in range(8):
		var landing: Dictionary = controller.call("_choose_destination", foot_index)
		if landing.is_empty():
			_free_nodes(spider, web)
			return _fail("Every foot must find a dense-web landing")
		var point: Vector3 = landing["point"]
		if (not controller.call("has_web_support", point)
				or not _is_within_leg_reach(controller, foot_index, point)
				or not controller.call("can_land", foot_index, point)):
			_free_nodes(spider, web)
			return _fail("Dense-web landings must be visible, reachable, and non-crossing")
		_set_foot_support(controller, foot_index, point, landing["strand_id"])
	var duration_ms := float(Time.get_ticks_usec() - start) / 1000.0
	print("DENSE WEB TARGET BENCH: %d segments, eight feet, %.2f ms" % [
		segments.size(), duration_ms,
	])
	start = Time.get_ticks_usec()
	for frame in range(60):
		controller.call("advance", 0.016)
	print("DENSE WEB ADVANCE BENCH: 60 frames, %.2f ms/frame" % (
		float(Time.get_ticks_usec() - start) / 60.0 / 1000.0
	))
	var passed := _check_dense_web_support_invalidation(controller, web)
	_free_nodes(spider, web)
	return passed


func _check_dense_web_support_invalidation(controller: Node, web: Web3D) -> bool:
	var foot_states: Array = controller.get("_feet")
	var moved_foot := foot_states[0].get("marker") as Marker3D
	moved_foot.global_position += Vector3.UP * 2.0
	controller.call("advance", 0.016)
	if not controller.call("is_dangling", 0):
		return _fail("Moving a planted foot off the web must invalidate cached support")
	web.edges.clear()
	web.rebuild()
	for foot_index in range(1, 8):
		if not controller.call("is_dangling", foot_index):
			return _fail("Removing dense-web geometry must invalidate planted support")
	return true


func _check_removed_web_releases_cached_support() -> bool:
	var spider := SPIDER_SCENE.instantiate() as BaseSpider3D
	root.add_child(spider)
	var controller := spider.get_node("SpiderRig/LegController") as Node
	controller.set_process(false)
	await process_frame
	_freeze_spider_animation(spider)
	var foot := spider.get_node("SpiderRig/FootTargets/FootFrontLeft") as Marker3D
	var web := _make_support_web(foot.global_position)
	root.add_child(web)
	await process_frame
	controller.set("support_web", web)
	controller.call("_release_crossed_feet")
	if controller.call("is_dangling", 0):
		_free_nodes(spider, web)
		return _fail("A planted foot must remain supported while its web exists")
	web.free()
	controller.call("advance", 0.016)
	var released: bool = controller.call("is_dangling", 0)
	spider.free()
	if not released:
		return _fail("Removing a web must release support cached by the controller")
	return true


func _make_line_web(start: Vector3, end: Vector3) -> Web3D:
	var web := Web3D.new()
	web.rings = 0
	web.curve_segments = 2
	web.valid_nodes = [_add_web_node(web, start), _add_web_node(web, end)]
	web.edges = [Vector2i(0, 1)]
	return web


func _mark_feet_dangling(controller: Node) -> void:
	var foot_states: Array = controller.get("_feet")
	for foot_state in foot_states:
		foot_state.set("dangling", true)
		foot_state.set("strand_id", "")


func _freeze_spider_animation(spider: BaseSpider3D) -> void:
	var animation_player := spider.get_node("SpiderRig/AnimationPlayer") as AnimationPlayer
	animation_player.stop()
	animation_player.seek(0.0, true)


func _keeps_shared_landing_clear(
	controller: Node,
	foot_index: int,
	point: Vector3,
	destinations: Array[Vector3]
) -> bool:
	var rig := controller.get_parent() as Node3D
	var lift_targets := rig.get_node("LiftTargets")
	var lift_name: String = SpiderLegController3D.FOOT_NAMES[foot_index].replace(
		"Foot", "Lift"
	)
	var start_point := (lift_targets.get_node(lift_name) as Marker3D).global_position
	for previous_index in range(destinations.size()):
		if point.distance_to(destinations[previous_index]) < 0.12:
			return false
		var previous_lift_name: String = SpiderLegController3D.FOOT_NAMES[previous_index].replace(
			"Foot", "Lift"
		)
		var previous_start := (
			lift_targets.get_node(previous_lift_name) as Marker3D
		).global_position
		if controller.call(
			"_paths_cross",
			Vector2(start_point.x, start_point.z),
			Vector2(point.x, point.z),
			Vector2(previous_start.x, previous_start.z),
			Vector2(destinations[previous_index].x, destinations[previous_index].z)
		):
			return false
	return true


func _is_within_leg_reach(controller: Node, foot_index: int, point: Vector3) -> bool:
	var lift_name: String = SpiderLegController3D.FOOT_NAMES[foot_index].replace(
		"Foot", "Lift"
	)
	var lift := (
		controller.get_parent().get_node("LiftTargets/" + lift_name) as Marker3D
	).global_position
	var reach: float = controller.call("_max_leg_reach", foot_index)
	return lift.distance_to(point) <= reach + 0.001


func _set_foot_support(
	controller: Node,
	foot_index: int,
	point: Vector3,
	strand_id: String
) -> void:
	var foot_states: Array = controller.get("_feet")
	var marker := foot_states[foot_index].get("marker") as Marker3D
	marker.global_position = point
	foot_states[foot_index].set("dangling", false)
	foot_states[foot_index].set("strand_id", strand_id)


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
