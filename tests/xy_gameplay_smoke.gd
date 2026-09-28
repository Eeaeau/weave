extends SceneTree
## The match is played in world X/Y, with Z reserved for depth and camera framing.

const MATCH_SCENE := preload("res://src/game/web_match.tscn")
const PEBBLE_SCENE := preload("res://src/features/collectibles/weapons/pebble_projectile.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var match_scene := MATCH_SCENE.instantiate() as WebMatch3D
	root.add_child(match_scene)
	current_scene = match_scene
	await process_frame
	var camera := match_scene.get_node("BranchCanopy/ParallaxCamera") as ActionCamera3D
	var spider := (match_scene.get_node("TeamA") as Team).get_active_spider()
	var web := match_scene.get_node("WebA") as Web3D
	var face: Array = web.find_faces()[0]
	var center := Vector3.ZERO
	for node_index in face:
		center += web.valid_nodes[node_index].global_position
	spider.global_position = center / 3.0
	spider.remaining_movement = 1.0
	spider.activate()
	var plane_normal := match_scene.global_basis.y.normalized()
	var upright := plane_normal.dot(Vector3.BACK) > 0.99
	var start_position := spider.global_position
	Input.action_press("move_up")
	spider._process(0.02)
	var moves_up := spider.global_position.y > start_position.y
	moves_up = moves_up and absf(spider.global_position.z - start_position.z) < 0.001
	Input.action_release("move_up")
	var projectile := PEBBLE_SCENE.instantiate() as Projectile3D
	match_scene.add_child(projectile)
	projectile.global_position = spider.global_position + Vector3.BACK
	projectile.launch(PI / 2.0, 1.0)
	var aims_up := projectile.velocity.y > 0.0 and absf(projectile.velocity.z) < 0.001
	var initial_velocity_y := projectile.velocity.y
	projectile._process(0.1)
	var falls := projectile.velocity.y < initial_velocity_y
	var zooms := camera.projection == Camera3D.PROJECTION_ORTHOGONAL
	var depth_before := camera.global_position.z
	camera.set_process(false)
	camera._process(1.0)
	zooms = zooms and absf(camera.global_position.z - depth_before) < 0.01
	var layers := match_scene.get_node("BranchCanopy/BackgroundLayers") as Node3D
	var sky := layers.get_node("SunsetSky") as Sprite3D
	if layers.has_method("_process"):
		layers._process(0.0)
	var sky_before := sky.global_position
	camera.global_position.x += 2.0
	if layers.has_method("_process"):
		layers._process(0.0)
	var parallax := sky.global_position.x > sky_before.x + 0.01
	_stop_audio(match_scene)
	match_scene.free()
	current_scene = null
	if not (upright and moves_up and aims_up and falls and zooms and parallax):
		push_error("XY GAMEPLAY FAIL: upright=%s move=%s aim=%s gravity=%s zoom=%s parallax=%s"
			% [upright, moves_up, aims_up, falls, zooms, parallax])
		quit(1)
		return
	await create_timer(0.5).timeout
	print("XY GAMEPLAY PASS: vertical web, controls, projectile gravity, and camera zoom")
	quit(0)


func _stop_audio(node: Node) -> void:
	if node is AudioStreamPlayer:
		node.stop()
		node.stream = null
	for child in node.get_children():
		_stop_audio(child)
