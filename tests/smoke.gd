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
	if not camera.current or camera.projection != Camera3D.PROJECTION_PERSPECTIVE:
		return _fail("The arena needs an active perspective camera")
	var camera_x := camera.position.x
	await create_timer(0.1).timeout
	if is_equal_approx(camera.position.x, camera_x):
		return _fail("Camera parallax is not moving")
	return true


func _check_webs(match_scene: Node3D) -> bool:
	var strands := match_scene.get_node("StartingWebs").get_children()
	if strands.size() != 10:
		return _fail("Both starting webs should have five strands")
	for strand in strands:
		if not strand is WebStrand3D or strand.durability < 1:
			return _fail("Web strand placeholder is invalid")
	return true


func _check_collectibles(match_scene: Node3D) -> bool:
	var pebble: ThrownWeaponData = load("res://src/features/collectibles/weapons/pebble.tres")
	var cutter: WebToolData = load("res://src/features/collectibles/weapons/twig_cutter.tres")
	var moth: InsectData = load("res://src/features/collectibles/insects/silk_moth.tres")
	var beetle: InsectData = load("res://src/features/collectibles/insects/health_beetle.tres")
	var windborne_weapon: WindborneWeapon3D = match_scene.get_node("WindbornePebble")
	var windborne_insect: WindborneInsect3D = match_scene.get_node("WindborneMoth")
	if (not pebble is CollectibleData or not cutter is CollectibleData
			or not moth is CollectibleData or not beetle is CollectibleData):
		return _fail("Collectible data inheritance is broken")
	if (not windborne_weapon is Collectible3D or not windborne_insect is Collectible3D
			or windborne_weapon.collectible != pebble
			or windborne_insect.collectible != moth):
		return _fail("Collectible scene inheritance or data reference is broken")
	return true


func _check_audio() -> bool:
	if AudioServer.get_bus_index("Music") < 0 or AudioServer.get_bus_index("SFX") < 0:
		return _fail("Audio buses are missing")
	return true


func _check_sprite_visuals(match_scene: Node3D) -> bool:
	var sprites := match_scene.find_children("*", "Sprite3D", true, false)
	var meshes := match_scene.find_children("*", "MeshInstance3D", true, false)
	if sprites.size() < 20 or not meshes.is_empty():
		return _fail("World placeholders must be 2D sprites in the 3D scene")
	return true


func _fail(message: String) -> bool:
	push_error("SMOKE FAIL: " + message)
	quit(1)
	return false
