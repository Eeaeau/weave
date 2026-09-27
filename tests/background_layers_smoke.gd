extends SceneTree
## Verify the warm sunset forest background composition.

const MAP_SCENE_PATH := "res://src/features/world/maps/branch_canopy/branch_canopy.tscn"
const MAX_SUPPORTED_ASPECT := 21.0 / 9.0
const CAMERA_SWAY_MARGIN := 0.5
const EXPECTED_LAYERS := {
	"SunsetSky": "res://src/features/world/maps/branch_canopy/assets/background/sunset_sky.svg",
	"Sun": "res://src/features/world/maps/branch_canopy/assets/sprites/sun/sun.png",
	"FarForest": "res://src/features/world/maps/branch_canopy/assets/background/far_forest.svg",
	"MidForest": "res://src/features/world/maps/branch_canopy/assets/background/mid_forest.svg",
}
const EXPECTED_EFFECTS := {
	"Haze": "res://src/features/world/maps/branch_canopy/assets/background/atmosphere.svg",
	"GodRays": "res://src/features/world/maps/branch_canopy/assets/background/god_rays.svg",
}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene: PackedScene = load(MAP_SCENE_PATH)
	var map: BranchCanopy3D = scene.instantiate()
	root.add_child(map)
	await process_frame
	if not _check_layer_contract(map):
		return
	if not _check_atmospheric_effects(map):
		return
	if not _check_sky_gradient(map):
		return
	if not _check_forest_palette(map):
		return
	if not _check_warm_environment(map):
		return
	_stop_audio(map)
	map.free()
	scene = null
	await process_frame
	await create_timer(0.2).timeout
	print("BACKGROUND LAYERS PASS: bright gradient, parallax forest, and optional effects")
	quit(0)


func _check_layer_contract(map: BranchCanopy3D) -> bool:
	var layers := map.get_node_or_null("BackgroundLayers") as Node3D
	if layers == null:
		return _fail("BackgroundLayers must exist")
	if not is_equal_approx(layers.rotation.x, -PI * 0.5):
		return _fail("Background cards must share the fixed map orientation")
	var camera := map.get_node("ActionCamera") as Camera3D
	var previous_depth := -INF
	for layer_name: String in EXPECTED_LAYERS:
		var card := layers.get_node_or_null(layer_name) as Sprite3D
		if not _check_card(card, camera, layer_name, previous_depth):
			return false
		previous_depth = card.position.z
	return true


func _check_card(
	card: Sprite3D, camera: Camera3D, layer_name: String, previous_depth: float
) -> bool:
	if card == null or card.texture == null:
		return _fail("Background layer is missing: " + layer_name)
	if card.texture.resource_path != EXPECTED_LAYERS[layer_name]:
		return _fail("Background layer uses the wrong artwork: " + layer_name)
	if card.billboard != BaseMaterial3D.BILLBOARD_DISABLED:
		return _fail("Background layers must not billboard: " + layer_name)
	if card.position.z <= previous_depth:
		return _fail("Background layers must be ordered from far to near")
	if layer_name != "Sun" and not _covers_gameplay_camera(card, camera):
		return _fail("The full-frame color layer is undersized: " + layer_name)
	return true


func _covers_gameplay_camera(card: Sprite3D, camera: Camera3D) -> bool:
	var card_scale := Vector2(card.scale.x, card.scale.y)
	var world_size := card.texture.get_size() * card.pixel_size * card_scale
	var camera_depth := absf(camera.global_position.y - card.global_position.y)
	var viewport_height := 2.0 * camera_depth * tan(deg_to_rad(camera.fov) * 0.5)
	var horizontal_offset := absf(camera.global_position.x - card.global_position.x)
	var vertical_offset := absf(camera.global_position.z - card.global_position.z)
	var required_width := viewport_height * MAX_SUPPORTED_ASPECT
	required_width += 2.0 * (horizontal_offset + CAMERA_SWAY_MARGIN)
	var required_height := viewport_height + 2.0 * vertical_offset
	return world_size.x >= required_width and world_size.y >= required_height


func _check_atmospheric_effects(map: BranchCanopy3D) -> bool:
	var layers := map.get_node("BackgroundLayers") as Node3D
	var effects := layers.get_node_or_null("AtmosphericEffects") as Node3D
	if effects == null:
		return _fail("AtmosphericEffects must group every optional effect")
	for effect_name: String in EXPECTED_EFFECTS:
		var card := effects.get_node_or_null(effect_name) as Sprite3D
		if card == null or card.texture == null:
			return _fail("Atmospheric effect is missing: " + effect_name)
		if card.texture.resource_path != EXPECTED_EFFECTS[effect_name]:
			return _fail("Atmospheric effect uses the wrong artwork: " + effect_name)
		if card.billboard != BaseMaterial3D.BILLBOARD_DISABLED:
			return _fail("Atmospheric effects must remain parallel to the map")
	effects.visible = false
	for child: Sprite3D in effects.get_children():
		if child.is_visible_in_tree():
			return _fail("The effects toggle must hide every atmospheric sprite")
	effects.visible = true
	return true


func _check_sky_gradient(map: BranchCanopy3D) -> bool:
	var sky := map.get_node("BackgroundLayers/SunsetSky") as Sprite3D
	var image := sky.texture.get_image()
	if image.is_compressed() and image.decompress() != OK:
		return _fail("The sky texture could not be decompressed for validation")
	var sample_x := image.get_width() / 2
	var unique_colors := {}
	for step in range(21):
		var sample_y := step * (image.get_height() - 1) / 20
		unique_colors[image.get_pixel(sample_x, sample_y).to_html(false)] = true
	if unique_colors.size() < 12:
		return _fail("The sky must use a smooth gradient rather than hard color bands")
	var top := sky.texture.get_image().get_pixel(sample_x, 0)
	var bottom := sky.texture.get_image().get_pixel(sample_x, image.get_height() - 1)
	if bottom.get_luminance() <= top.get_luminance() or bottom.get_luminance() < 0.65:
		return _fail("The sky gradient must brighten toward the horizon")
	return true


func _check_forest_palette(map: BranchCanopy3D) -> bool:
	var layers := map.get_node("BackgroundLayers") as Node3D
	for layer_name in ["FarForest", "MidForest"]:
		var card := layers.get_node(layer_name) as Sprite3D
		var image := _readable_image(card.texture)
		var trunk := image.get_pixel(100, 500)
		if trunk.r <= trunk.g or trunk.g <= trunk.b:
			return _fail("Forest trunks must use a natural warm bark palette")
		var canopy := image.get_pixel(100, 50)
		if canopy.g <= canopy.r * 1.05:
			return _fail("Forest canopies must retain their green palette")
	var haze := layers.get_node("AtmosphericEffects/Haze") as Sprite3D
	var haze_color := _average_visible_color(haze.texture)
	if haze_color.b <= haze_color.r or haze_color.g <= haze_color.r:
		return _fail("Forest haze must use a cool blue-gray palette")
	return true


func _average_visible_color(texture: Texture2D) -> Color:
	var image := _readable_image(texture)
	var total := Vector3.ZERO
	var weight := 0.0
	for y in range(0, image.get_height(), 32):
		for x in range(0, image.get_width(), 32):
			var sample := image.get_pixel(x, y)
			if sample.a > 0.02:
				total += Vector3(sample.r, sample.g, sample.b) * sample.a
				weight += sample.a
	if is_zero_approx(weight):
		return Color.TRANSPARENT
	return Color(total.x / weight, total.y / weight, total.z / weight)


func _readable_image(texture: Texture2D) -> Image:
	var image := texture.get_image()
	if image.is_compressed():
		image.decompress()
	return image


func _check_warm_environment(map: BranchCanopy3D) -> bool:
	var environment: Environment = map.get_node("WorldEnvironment").environment
	if environment == null:
		return _fail("The canopy environment must exist")
	var background: Color = environment.background_color
	var ambient: Color = environment.ambient_light_color
	if background.r <= background.b:
		return _fail("The fallback background must be warm")
	if ambient.r <= ambient.b:
		return _fail("The ambient light must carry the sunset warmth")
	return true


func _stop_audio(node: Node) -> void:
	if node is AudioStreamPlayer:
		node.stop()
	for child in node.get_children():
		_stop_audio(child)


func _fail(message: String) -> bool:
	push_error("BACKGROUND LAYERS FAIL: " + message)
	quit(1)
	return false
