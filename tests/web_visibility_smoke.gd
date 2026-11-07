extends SceneTree
# gdstyle:ignore-file=quality/allocation-in-loop

const SPIDER := preload("res://src/features/spiders/base_spider.tscn")

var _failed := false
var _service: WebDeformation3D


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 6.0
	camera.position.z = 10.0
	root.add_child(camera)
	camera.current = true
	var web := Web3D.new()
	web.rotation.x = PI / 2.0
	for shift in [0.0, 20.0]:
		for point in [Vector3(-2, 0, -1), Vector3(2, 0, -1), Vector3(0, 0, 2)]:
			var anchor := Marker3D.new()
			anchor.position = point + Vector3.RIGHT * shift
			web.add_child(anchor)
			web.valid_nodes.append(anchor)
	web.edges = [Vector2i(0, 1), Vector2i(1, 2), Vector2i(2, 0),
		Vector2i(3, 4), Vector2i(4, 5), Vector2i(5, 3)]
	root.add_child(web)
	var spiders: Array[BaseSpider3D] = []
	for offset in [0.0, 20.0]:
		var spider := SPIDER.instantiate() as BaseSpider3D
		spider.rotation.x = PI / 2.0
		spider.position.x = offset
		root.add_child(spider)
		spiders.append(spider)
		spider.set_process(false)
		var gait := spider.get_node("SpiderRig/LegController") as SpiderContactGait3D
		gait.support_web = web
		gait.set_process(false)
		gait.advance(1.0 / 60.0)
	_service = web.get_deformation() as WebDeformation3D
	_service.set_process(false)
	_advance(180)
	_expect(_service.is_region_dynamic(0) and not _service.is_region_dynamic(1),
		"Only the visible occupied patch should simulate")
	camera.position.x = 11.0
	_advance(1)
	_expect(not camera.is_position_in_frustum(Vector3(18, 1, 0))
		and _service.is_region_dynamic(1), "The margin must wake a patch before it enters view")
	camera.position.x = 40.0
	_advance(1)
	_expect(_service.is_region_dynamic(0) and _service.is_region_dynamic(1),
		"Brief camera movement must retain the settling grace period")
	_advance(180)
	_expect(_service.model.simulated_point_count() == 0,
		"Fully offscreen patches must stop spring integration")
	camera.position.x = 20.0
	camera.size = 60.0
	_advance(1)
	_expect(_service.is_region_dynamic(0) and _service.is_region_dynamic(1),
		"Zooming out must wake newly visible patches immediately")
	camera.rotation.y = PI
	_advance(180)
	_expect(_service.model.simulated_point_count() == 0,
		"Patches behind the camera must sleep")
	camera.rotation = Vector3.ZERO
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 60.0
	_advance(1)
	_expect(_service.is_region_dynamic(1), "Perspective cameras must also wake visible patches")
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.position.x = 0.0
	camera.size = 4.0
	web.valid_nodes[0].position = Vector3(-12, 0, -12)
	web.valid_nodes[1].position = Vector3(12, 0, -12)
	web.valid_nodes[2].position = Vector3(0, 0, 12)
	web.rebuild()
	_advance(1)
	var corners_outside := true
	for index in range(3):
		corners_outside = corners_outside and not camera.is_position_in_frustum(
			web.valid_nodes[index].global_position)
	_expect(corners_outside and _service.is_region_dynamic(0),
		"A patch spanning the view must stay awake even when every corner is offscreen")
	_service.set("pause_offscreen", false)
	_advance(1)
	_expect(_service.is_region_dynamic(1), "Visibility culling must be switchable for comparisons")
	_service.set("pause_offscreen", true)
	camera.free()
	_advance(1)
	_expect(_service.is_region_dynamic(0) and _service.is_region_dynamic(1),
		"Headless scenes without a camera must retain normal simulation")
	_advance(180)
	spiders[0].position.x = 100.0
	_advance(180)
	var body := spiders[0].visual_rig.get_node("BoneAttachment3D/BodyOffset/Body") as Sprite3D
	var shown_offset: Vector3 = body.material_override.get_shader_parameter("world_offset")
	_expect(shown_offset.distance_to(_service.displacement_at(spiders[0].global_position)) < 0.0001,
		"A spider leaving every patch must release its previous body deformation")
	for spider in spiders:
		spider.queue_free()
	web.queue_free()
	await process_frame
	await create_timer(0.2).timeout
	if not _failed:
		print("WEB VISIBILITY PASS: buffered camera culling, pan, zoom and no-camera fallback")
	quit(1 if _failed else 0)


func _advance(frames: int) -> void:
	for frame in range(frames):
		_service.advance_visuals(1.0 / 60.0)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error("WEB VISIBILITY FAIL: " + message)
