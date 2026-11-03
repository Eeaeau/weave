extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var spider := load("res://src/features/spiders/base_spider.tscn").instantiate() as BaseSpider3D
	root.add_child(spider)
	var gait := spider.get_node("SpiderRig/LegController")
	if not gait.has_method("get_step_plans"):
		push_error("CONTACT GAIT FAIL: the game rig must use the accepted coordinated gait")
		quit(1)
		return
	gait.set_process(false)
	spider.set_process(false)
	gait.targeting_mode = SpiderLegController3D.TargetingMode.FREE_STEP_DEBUG
	await process_frame
	if not _end_leg_intent(gait):
		push_error("CONTACT GAIT FAIL: front/rear feet must favour axial pull and push")
		quit(1)
		return
	var stepped: Array[Dictionary] = [{}, {}]
	for frame in range(240):
		var phase := 0 if frame < 120 else 1
		spider.position.z += (1.0 if phase == 0 else -1.0) * 0.95 / 60.0
		gait.advance(1.0 / 60.0)
		for plan in gait.get_step_plans():
			stepped[phase][plan.index] = true
			if not plan.has("end") or not plan.has("start"):
				push_error("CONTACT GAIT FAIL: each moving foot needs a committed destination")
				quit(1)
				return
	for phase in stepped:
		for index in [0, 1, 6, 7]:
			if not phase.has(index):
				push_error("CONTACT GAIT FAIL: front/rear foot stopped stepping while walking")
				quit(1)
				return
	if not is_equal_approx(
		gait.minimum_stride,
		0.24,
	) or not is_equal_approx(spider.visual_turn_speed, 2.1):
		push_error("CONTACT GAIT FAIL: accepted stride and turn tuning was lost")
		quit(1)
		return
	spider.queue_free()
	await process_frame
	await create_timer(0.2).timeout
	print("CONTACT GAIT PASS: production rig uses planned, coordinated steps and accepted tuning")
	quit(0)


func _end_leg_intent(gait: SpiderContactGait3D) -> bool:
	var rig := gait.get_parent() as Node3D
	var right := rig.global_basis.x.normalized()
	var forward := rig.global_basis.z.normalized()
	var middle_rest := _intent_target(gait, 2, Vector3.ZERO)
	var middle_side := absf((_intent_target(gait, 2, right) - middle_rest).dot(right))
	for index in [0, 1, 6, 7]:
		var outward := forward if index < 2 else -forward
		var rest := _intent_target(gait, index, Vector3.ZERO)
		var side := absf((_intent_target(gait, index, right) - rest).dot(right))
		var reach := _intent_target(gait, index, outward)
		var push := _intent_target(gait, index, -outward)
		var forward_stride := (reach - rest).dot(outward)
		if side >= forward_stride * 0.75 or middle_side < side * 2.0:
			print("END LEG INTENT: foot=%s side=%s reach=%s" % [index, side, forward_stride])
			return false
		if (push - gait.get_leg_origin(index)).dot(outward) < 0.1:
			return false
		if reach.distance_to(gait.get_leg_origin(index)) > gait.get_leg_reach(index) + 0.0001:
			return false
	gait._cycle.rig_moved = false
	return true


func _intent_target(gait: SpiderContactGait3D, index: int, direction: Vector3) -> Vector3:
	gait._cycle.rig_moved = not direction.is_zero_approx()
	gait._cycle.travel_direction = direction
	gait._travel_speed = 0.95
	return gait._rest_destination(index)
