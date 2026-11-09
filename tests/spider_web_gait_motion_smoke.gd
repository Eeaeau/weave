extends SceneTree
# gdstyle:ignore-file=quality/await-in-loop,quality/allocation-in-loop

const SPIDER := preload("res://src/features/spiders/base_spider.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var dense: Dictionary = await _sample(6)
	var sparse: Dictionary = await _sample(1)
	print("WEB GAIT samples: dense=%s sparse=%s" % [dense, sparse])
	if (not dense.clear_front or not sparse.clear_front or not dense.rear_steps
			or not dense.directional_safe
			or not sparse.rear_steps or not sparse.rear_alternative):
		push_error("WEB GAIT MOTION FAIL: front reach or rear-foot replants regressed")
		quit(1)
		return
	await create_timer(0.2).timeout
	print("WEB GAIT MOTION PASS: front clearance and rear replants on dense and sparse webs")
	quit(0)


func _sample(rings: int) -> Dictionary:
	var web := Web3D.new()
	web.rings = rings
	web.curve_segments = 1
	for point in [Vector3(-2.8, 0, -2.1), Vector3(2.8, 0, -2.1), Vector3(0, 0, 3.2)]:
		var anchor := Marker3D.new()
		anchor.position = point
		web.add_child(anchor)
		web.valid_nodes.append(anchor)
	web.edges = [Vector2i(0, 1), Vector2i(1, 2), Vector2i(2, 0)]
	root.add_child(web)
	var spider := SPIDER.instantiate() as BaseSpider3D
	spider.get_node("SpiderRig/BoneAttachment3D/BodyOffset").randomize_idle_phase = false
	spider.position.z = -1.0
	root.add_child(spider)
	spider.process_mode = Node.PROCESS_MODE_DISABLED
	var gait := spider.get_node("SpiderRig/LegController") as SpiderContactGait3D
	gait.support_web = web
	var skeleton := spider.get_node("SpiderRig/ImportedRig/RIG_spider/Skeleton3D")
	skeleton.process_mode = Node.PROCESS_MODE_ALWAYS
	var animation := spider.get_node("SpiderRig/AnimationPlayer") as AnimationPlayer
	animation.play("eye_idle")
	animation.seek(0.0, true)
	var deformation := web.get_deformation() as WebDeformation3D
	deformation.set_process(false)
	var counts := PackedInt32Array([0, 0, 0, 0, 0, 0, 0, 0])
	var inside := 0
	var front_total := Vector2.ZERO
	var front_minimum := Vector2(INF, INF)
	var rear_alternative := false
	for frame in range(240):
		if frame >= 120:
			spider.position.z += 0.95 / 60.0
		animation.advance(1.0 / 60.0)
		gait.advance(1.0 / 60.0)
		deformation.advance_visuals(1.0 / 60.0)
		if frame >= 120:
			for plan in gait.get_step_plans():
				if is_zero_approx(plan.elapsed):
					counts[plan.index] += 1
			for index in range(2):
				var foot: Vector3 = gait._feet[index].marker.global_position
				if gait._inside_body(foot):
					inside += 1
				var forward: float = (foot - gait._body_sprite.global_position).dot(
					gait._rig.global_basis.z.normalized())
				front_minimum[index] = minf(front_minimum[index], forward)
				front_total[index] += forward
			if rings == 1 and not rear_alternative:
				rear_alternative = _has_wider_rear_target(gait)
		await process_frame
	var clear_front := (inside <= 10 and front_minimum.x > -0.25 and front_minimum.y > -0.25
		and (front_total.x + front_total.y) / 120.0 > 0.95)
	var rear_steps := counts[6] >= 2 and counts[7] >= 2
	var directional_safe := true
	if rings == 6:
		directional_safe = await _check_directions(spider, gait, deformation, animation)
	spider.queue_free()
	web.queue_free()
	await process_frame
	return {"clear_front": clear_front, "rear_steps": rear_steps,
		"directional_safe": directional_safe,
		"rear_alternative": rear_alternative, "inside_frames": inside,
		"front_minimum": front_minimum, "steps": counts}


func _has_wider_rear_target(gait: SpiderContactGait3D) -> bool:
	var found := false
	for index in [6, 7]:
		var foot = gait._feet[index]
		if foot.dangling or gait._is_stepping(index):
			continue
		var desired := gait._rest_destination(index)
		gait._query_foot = index
		gait._query_direction = desired - foot.marker.global_position
		var normal := gait._depth_normal()
		gait._query_direction -= normal * gait._query_direction.dot(normal)
		gait._query_direction = gait._query_direction.normalized()
		var near := gait._find_landing_near(index, desired, gait.landing_adjustment)
		var wide := gait._find_landing_near(index, desired, gait.landing_adjustment * 2.0)
		if near.is_empty() and not wide.is_empty():
			var landing := gait._choose_web_destination(index)
			found = (not landing.is_empty() and gait.has_web_support(landing.point)
				and gait.can_land(index, landing.point))
		gait._query_foot = -1
		if found:
			break
	return found


func _check_directions(spider: BaseSpider3D, gait: SpiderContactGait3D,
		deformation: WebDeformation3D, animation: AnimationPlayer) -> bool:
	var safe := true
	for direction in [Vector3.FORWARD, Vector3.RIGHT]:
		for frame in range(60):
			var previous: Array[Vector3] = []
			for foot in gait._feet:
				previous.append(foot.marker.global_position)
			spider.position += direction * (0.95 / 60.0)
			animation.advance(1.0 / 60.0)
			gait.advance(1.0 / 60.0)
			deformation.advance_visuals(1.0 / 60.0)
			for index in range(gait._feet.size()):
				if gait._feet[index].marker.global_position.distance_to(previous[index]) > 0.15:
					safe = false
			for plan in gait.get_step_plans():
				if (is_zero_approx(plan.elapsed) and (not gait.has_web_support(plan.end)
						or not gait.can_land(plan.index, plan.end))):
					safe = false
			await process_frame
	return safe
