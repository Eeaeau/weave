extends SceneTree
## Keep the current forest artwork visible with orthographic layer parallax.

const MATCH_SCENE := preload("res://src/game/web_match.tscn")
const MAX_SUPPORTED_ASPECT := 21.0 / 9.0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var match_scene := MATCH_SCENE.instantiate() as WebMatch3D
	root.add_child(match_scene)
	await process_frame
	var map := match_scene.get_node("BranchCanopy") as BranchCanopy3D
	var layers := map.get_node("BackgroundLayers") as BackgroundParallax3D
	var camera := map.get_node("ParallaxCamera") as ActionCamera3D
	var sky := layers.get_node("SunsetSky") as Sprite3D
	var sun := layers.get_node("Sun") as Sprite3D
	var forest := layers.get_node("MidForest4") as Sprite3D
	var okay := _check_artwork(sky, sun, forest, camera)
	okay = _check_parallax(layers, camera, sky, forest) and okay
	okay = _check_sky_gradient(sky) and okay
	okay = _check_environment(map) and okay
	_stop_audio(match_scene)
	match_scene.free()
	await create_timer(0.5).timeout
	if not okay:
		quit(1)
		return
	print("BACKGROUND LAYERS PASS: forest artwork, orthographic coverage, and parallax")
	quit(0)


func _check_artwork(sky: Sprite3D, sun: Sprite3D, forest: Sprite3D,
		camera: Camera3D) -> bool:
	if (sky == null or sun == null or forest == null
			or sky.texture == null or sun.texture == null or forest.texture == null):
		return _fail("The sky, sun, and forest artwork must be present")
	if not (sky.global_position.z < sun.global_position.z
			and sun.global_position.z < forest.global_position.z):
		return _fail("The sky, sun, and forest must retain their depth order")
	var sky_size := sky.texture.get_size() * sky.pixel_size * Vector2(sky.scale.x, sky.scale.y)
	if (sky_size.x < camera.size * MAX_SUPPORTED_ASPECT
			or sky_size.y < camera.size):
		return _fail("The sky must cover the orthographic camera at wide aspect ratios")
	return true


func _check_parallax(layers: BackgroundParallax3D, camera: Camera3D,
		sky: Sprite3D, forest: Sprite3D) -> bool:
	camera.set_process(false)
	layers.set_process(false)
	layers._process(0.0)
	var sky_before := sky.global_position
	var forest_before := forest.global_position
	camera.global_position.x += 2.0
	layers._process(0.0)
	var sky_shift := sky.global_position.x - sky_before.x
	var forest_shift := forest.global_position.x - forest_before.x
	if sky_shift <= forest_shift or forest_shift <= 0.0:
		return _fail("Distant forest cards must move at different rates during pans")
	if (not is_equal_approx(sky.global_position.z, sky_before.z)
			or not is_equal_approx(forest.global_position.z, forest_before.z)):
		return _fail("Parallax must leave layer depth unchanged")
	return true


func _check_sky_gradient(sky: Sprite3D) -> bool:
	var image := sky.texture.get_image()
	if image.is_compressed() and image.decompress() != OK:
		return _fail("The sky texture must be readable")
	var sample_x := image.get_width() / 2
	var top := image.get_pixel(sample_x, 0)
	var bottom := image.get_pixel(sample_x, image.get_height() - 1)
	if bottom.get_luminance() <= top.get_luminance():
		return _fail("The sunset sky must brighten toward the horizon")
	return true


func _check_environment(map: BranchCanopy3D) -> bool:
	var environment := (map.get_node("WorldEnvironment") as WorldEnvironment).environment
	if (environment == null
			or environment.ambient_light_color.r <= environment.ambient_light_color.b):
		return _fail("The canopy must retain warm sunset ambient light")
	return true


func _stop_audio(node: Node) -> void:
	if node is AudioStreamPlayer:
		node.stop()
		node.stream = null
	for child in node.get_children():
		_stop_audio(child)


func _fail(message: String) -> bool:
	push_error("BACKGROUND LAYERS FAIL: " + message)
	return false
