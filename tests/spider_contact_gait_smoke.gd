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
	for frame in range(120):
		spider.position.z += 0.95 / 60.0
		gait.advance(1.0 / 60.0)
		for plan in gait.get_step_plans():
			if not plan.has("end") or not plan.has("start"):
				push_error("CONTACT GAIT FAIL: each moving foot needs a committed destination")
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
