extends SceneTree
# gdstyle:ignore-file=quality/await-in-loop,quality/allocation-in-loop

const SPIDER := preload("res://src/features/spiders/base_spider.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var previous: Dictionary = await _sample(true)
	var calmer: Dictionary = await _sample(false)
	print("IDLE GAIT samples: previous=%s calmer=%s" % [previous, calmer])
	if (previous.count == 0 or calmer.count == 0 or calmer.count > previous.count * 0.75
			or calmer.duration < previous.duration * 1.3 or calmer.walk_delay > 0.18):
		push_error("IDLE GAIT FAIL: calmer idle steps must preserve walking response")
		quit(1)
		return
	await create_timer(0.2).timeout
	print("IDLE GAIT PASS: calmer idle foot placement and immediate walking recovery")
	quit(0)


func _sample(previous: bool) -> Dictionary:
	var web := Web3D.new()
	for point in [Vector3(-3, 0, -2), Vector3(3, 0, -2), Vector3(0, 0, 3)]:
		var anchor := Marker3D.new()
		anchor.position = point
		web.add_child(anchor)
		web.valid_nodes.append(anchor)
	web.edges = [Vector2i(0, 1), Vector2i(1, 2), Vector2i(2, 0)]
	root.add_child(web)
	var spider := SPIDER.instantiate() as BaseSpider3D
	spider.get_node("SpiderRig/BoneAttachment3D/BodyOffset").randomize_idle_phase = false
	root.add_child(spider)
	spider.process_mode = Node.PROCESS_MODE_DISABLED
	var gait := spider.get_node("SpiderRig/LegController") as SpiderContactGait3D
	gait.support_web = web
	var deformation := web.get_deformation() as WebDeformation3D
	deformation.set_process(false)
	var skeleton := spider.get_node("SpiderRig/ImportedRig/RIG_spider/Skeleton3D")
	skeleton.process_mode = Node.PROCESS_MODE_ALWAYS
	if previous:
		gait.set("idle_step_interval", gait.lift_spacing)
		gait.set("idle_step_duration", gait.step_duration)
	var animation := spider.get_node("SpiderRig/AnimationPlayer") as AnimationPlayer
	animation.play("eye_idle")
	animation.seek(0.0, true)
	for frame in range(120):
		animation.advance(1.0 / 60.0)
		gait.advance(1.0 / 60.0)
		deformation.advance_visuals(1.0 / 60.0)
		await process_frame
	var count := 0
	var duration := 0.0
	for frame in range(600):
		animation.advance(1.0 / 60.0)
		gait.advance(1.0 / 60.0)
		deformation.advance_visuals(1.0 / 60.0)
		for plan in gait.get_step_plans():
			if is_zero_approx(plan.elapsed):
				count += 1
				duration += plan.duration
		await process_frame
	var found_idle_step := false
	for frame in range(240):
		animation.advance(1.0 / 60.0)
		gait.advance(1.0 / 60.0)
		deformation.advance_visuals(1.0 / 60.0)
		await process_frame
		if _new_step(gait):
			found_idle_step = true
			break
	var delay := INF
	if found_idle_step:
		spider.position.z += 0.45
		for frame in range(12):
			spider.position.z += 0.95 / 60.0
			gait.advance(1.0 / 60.0)
			if _new_step(gait):
				delay = (frame + 1) / 60.0
				break
	spider.queue_free()
	web.queue_free()
	await process_frame
	return { "count": count, "duration": duration / maxi(count, 1), "walk_delay": delay }


func _new_step(gait: SpiderContactGait3D) -> bool:
	for plan in gait.get_step_plans():
		if is_zero_approx(plan.elapsed):
			return true
	return false
