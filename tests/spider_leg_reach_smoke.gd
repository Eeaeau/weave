extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var spider: BaseSpider3D = load("res://src/features/spiders/base_spider.tscn").instantiate()
	root.add_child(spider)
	spider.process_mode = Node.PROCESS_MODE_DISABLED
	var rig := spider.get_node("SpiderRig")
	var strokes: SpiderLegStroke3D = rig.get_node("LegStrokes")
	var foot: Node3D = rig.get_node("FootTargets/FootBackLeft")
	foot.global_position += Vector3(30, 0, 30)
	var points := strokes._collect_leg_points(0)
	if points[-1].distance_to(points[-2]) > 0.24:
		spider.free()
		push_error("LEG REACH FAIL: the drawn toe stretched beyond its authored length")
		quit(1)
		return
	var gait: SpiderLegController3D = rig.get_node("LegController")
	gait.targeting_mode = SpiderLegController3D.TargetingMode.FREE_STEP_DEBUG
	for tick in range(90):
		spider.position.x += 0.06
		gait.advance(1.0 / 60.0)
		for index in range(gait.FOOT_NAMES.size()):
			var target: Node3D = rig.get_node("FootTargets/" + gait.FOOT_NAMES[index])
			var distance := target.global_position.distance_to(gait._hip_position(index))
			if distance > gait._physical_reach(index) + 0.001:
				spider.free()
				push_error("LEG REACH FAIL: a moving foot exceeded its physical reach")
				quit(1)
				return
	spider.free()
	print("SPIDER LEG REACH PASS: physical reach and authored toe length")
	quit(0)
