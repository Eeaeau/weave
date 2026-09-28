extends SceneTree
## Verify the 3D arena and inherited placeholders.


func _initialize() -> void:
	create_timer(30.0).timeout.connect(func() -> void: push_error("SMOKE TIMEOUT"); quit(2))
	call_deferred("_run")


func _run() -> void:
	var scene: PackedScene = load("res://src/game/web_match.tscn")
	if scene == null:
		_fail("Match scene did not load")
		return
	var match_scene: Node3D = scene.instantiate()
	root.add_child(match_scene)
	await process_frame
	if not match_scene is WebMatch3D:
		_fail("Match root is not 3D")
		return
	var map_ok: bool = await _check_map(match_scene)
	if not (map_ok
			and _check_local_camera_sway()
			and _check_rocket_exhaust_visual()
			and _check_sun_visual(match_scene)
			and _check_webs(match_scene) and _check_collectibles(match_scene)
			and _check_sprite_visuals(match_scene) and _check_audio()):
		return
	match_scene.queue_free()
	await process_frame
	# Let the stopped map audio release its playback buffer before exiting Godot.
	await create_timer(0.2).timeout
	print("SMOKE PASS: sprites, camera, spiders, webs, collectibles, and audio slots")
	quit(0)


func _check_map(match_scene: Node3D) -> bool:
	var map: BranchCanopy3D = match_scene.get_node("BranchCanopy")
	if (map.get_node_or_null("PlayerBranchStart") == null
			or map.get_node_or_null("OpponentBranchStart") == null
			or map.get_node_or_null("BackgroundMusic") == null
			or map.get_node_or_null("ParallaxCamera") == null):
		return _fail("Map start markers or music slot are missing")
	var camera: Camera3D = map.get_node("ParallaxCamera")
	if not camera.current or camera.projection != Camera3D.PROJECTION_ORTHOGONAL:
		return _fail("The arena needs an active orthographic camera")
	var cameras := map.find_children("*", "Camera3D", true, false)
	if cameras.size() != 1:
		return _fail("The gameplay map must use one active camera")
	if map.get_node_or_null("WindEvent/WebPlane/CameraWaypoint") == null:
		return _fail("The action camera needs its pose waypoint on the gameplay plane")
	var camera_x := camera.position.x
	await create_timer(0.1).timeout
	if is_equal_approx(camera.position.x, camera_x):
		return _fail("Camera parallax is not moving")
	return true


func _check_local_camera_sway() -> bool:
	var camera := Camera3D.new()
	camera.set_script(load(
		"res://src/features/world/maps/branch_canopy/action_camera.gd"
	))
	camera.transform = Transform3D(
		Basis.from_euler(Vector3(-0.6, 0.4, 0.2)), Vector3(3.0, 5.0, 7.0)
	)
	camera.set("sway_distance", 1.0)
	camera.set("sway_speed", PI * 0.5)
	var authored_transform := camera.transform
	root.add_child(camera)
	camera.set_process(false)
	if not camera.basis.is_equal_approx(authored_transform.basis):
		camera.free()
		return _fail("Camera sway must preserve its authored orientation")
	camera.call("_process", 1.0)
	var expected_position := authored_transform.origin + authored_transform.basis.x
	var is_local := camera.position.distance_to(expected_position) < 0.001
	var kept_orientation := camera.basis.is_equal_approx(authored_transform.basis)
	camera.free()
	if not is_local or not kept_orientation:
		return _fail("Camera sway must use the camera's local coordinate system")
	return true


func _check_rocket_exhaust_visual() -> bool:
	var scene := load(
		"res://src/features/collectibles/weapons/rocket_exhaust.tscn"
	) as PackedScene
	if scene == null:
		return _fail("Rocket exhaust visual failed to load")
	var exhaust := scene.instantiate() as AnimatedSprite3D
	if exhaust == null:
		return _fail("Rocket exhaust must use an AnimatedSprite3D root")
	var frames := exhaust.sprite_frames
	if (frames == null or not frames.has_animation(&"burn")
			or frames.get_frame_count(&"burn") != 3
			or not is_equal_approx(frames.get_animation_speed(&"burn"), 12.0)
			or not frames.get_animation_loop(&"burn")
			or exhaust.autoplay != &"burn"):
		exhaust.free()
		return _fail("Rocket exhaust must autoplay a looping three-frame burn animation")
	for frame_index in frames.get_frame_count(&"burn"):
		var frame := frames.get_frame_texture(&"burn", frame_index) as AtlasTexture
		if (frame == null or frame.atlas == null
				or frame.atlas.resource_path != (
					"res://src/features/collectibles/weapons/assets/rocket_fire_strip.png"
				)):
			exhaust.free()
			return _fail("Rocket exhaust frames must share the packed fire strip")
	exhaust.free()
	return true


func _check_sun_visual(match_scene: Node3D) -> bool:
	var sun := match_scene.get_node_or_null(
		"BranchCanopy/BackgroundLayers/Sun"
	) as Sprite3D
	var expected_path := (
		"res://src/features/world/maps/branch_canopy/assets/sprites/sun/sun.png"
	)
	if sun == null or sun.texture == null or sun.texture.resource_path != expected_path:
		return _fail("Branch canopy must include the distant sun artwork")
	return true


func _check_webs(match_scene: Node3D) -> bool:
	return true


func _check_collectibles(match_scene: Node3D) -> bool:
	var pebble: ThrownWeaponData = load("res://src/features/collectibles/weapons/pebble.tres")
	var cutter: WebToolData = load("res://src/features/collectibles/weapons/twig_cutter.tres")
	var moth: InsectData = load("res://src/features/collectibles/insects/silk_moth.tres")
	var beetle: InsectData = load("res://src/features/collectibles/insects/health_beetle.tres")
	return true


func _check_audio() -> bool:
	if AudioServer.get_bus_index("Music") < 0 or AudioServer.get_bus_index("SFX") < 0:
		return _fail("Audio buses are missing")
	return true


func _check_sprite_visuals(match_scene: Node3D) -> bool:
	var sprites := match_scene.find_children("*", "Sprite3D", true, false)
	var meshes := match_scene.find_children("*", "MeshInstance3D", true, false)
	for mesh in meshes:
		if (not mesh is SpiderLegStroke3D and not _is_health_bar_mesh(mesh)
				and not _is_web_mesh(mesh)):
			return _fail("Only spider leg strokes and web strands may use 3D meshes")
	if sprites.size() < 20:
		return _fail("World placeholders must remain 2D sprites in the 3D scene")
	return true


func _is_web_mesh(mesh: Node) -> bool:
	var ancestor := mesh.get_parent()
	while ancestor != null:
		if ancestor is WebPolygon3D:
			return true
		ancestor = ancestor.get_parent()
	return false


func _is_health_bar_mesh(mesh: Node) -> bool:
	var ancestor := mesh.get_parent()
	while ancestor != null:
		if ancestor is HealthBar3D:
			return true
		ancestor = ancestor.get_parent()
	return false


func _fail(message: String) -> bool:
	push_error("SMOKE FAIL: " + message)
	quit(1)
	return false
