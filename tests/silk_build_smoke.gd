extends SceneTree
## Exercise personal silk, insect feeding, strand actions, and anchor cycling.

const PLAYER_SCENE := preload("res://src/features/spiders/player_spider.tscn")
const INSECT_SCENE := preload("res://src/features/collectibles/insects/windborne_insect.tscn")
const WIND_BORNE_WEAPON_SCENE := preload(
	"res://src/features/collectibles/weapons/windborne_weapon.tscn"
)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if not await _check_insect_proximity():
		quit(1)
		return
	if not _check_build_and_selection():
		quit(1)
		return
	if not _check_origin_on_existing_strand():
		quit(1)
		return
	if not await _check_match_spawns():
		quit(1)
		return
	print("SILK BUILD PASS: personal silk, feeding, strand actions, and anchor cycling")
	quit(0)


func _check_insect_proximity() -> bool:
	var spider_a := PLAYER_SCENE.instantiate() as PlayerSpider3D
	var spider_b := PLAYER_SCENE.instantiate() as PlayerSpider3D
	spider_a.position = Vector3.ZERO
	spider_b.position = Vector3(10, 0, 0)
	spider_a.set("silk_amount", 1)
	spider_b.set("silk_amount", 3)
	root.add_child(spider_a)
	root.add_child(spider_b)
	var insect := INSECT_SCENE.instantiate() as WindborneInsect3D
	var data := InsectData.new()
	data.silk_amount = 2
	insect.collectible = data
	root.add_child(insect)
	insect.global_position = spider_a.global_position
	await physics_frame
	await physics_frame
	await physics_frame
	await physics_frame
	if spider_a.get("silk_amount") != 3 or spider_b.get("silk_amount") != 3:
		_free_nodes([insect, spider_a, spider_b])
		return _fail("A nearby insect must refill only its spider's personal silk")
	if is_instance_valid(insect):
		_free_nodes([insect, spider_a, spider_b])
		return _fail("An eaten insect must be removed after proximity pickup")
	var beetle := INSECT_SCENE.instantiate() as WindborneInsect3D
	var beetle_data := InsectData.new()
	beetle_data.health_amount = 1
	beetle.collectible = beetle_data
	root.add_child(beetle)
	spider_a.set("health", 0.5)
	beetle.call("_area_entered", spider_a.get("hitbox"))
	if not is_equal_approx(spider_a.get("health"), 1.0):
		_free_nodes([beetle, spider_a, spider_b])
		return _fail("Health beetles must heal the spider that eats them")
	await process_frame
	if is_instance_valid(beetle):
		_free_nodes([beetle, spider_a, spider_b])
		return _fail("An eaten health beetle must also be removed")
	var unfinished_weapon := WIND_BORNE_WEAPON_SCENE.instantiate() as WindborneWeapon3D
	root.add_child(unfinished_weapon)
	if spider_a.pick_up(unfinished_weapon) or not unfinished_weapon.visible:
		_free_nodes([unfinished_weapon, spider_a, spider_b])
		return _fail("Unsupported windborne weapons must stay available instead of disappearing")
	_free_nodes([spider_a, spider_b])
	_free_nodes([unfinished_weapon])
	return true


func _check_build_and_selection() -> bool:
	var spider := PLAYER_SCENE.instantiate() as PlayerSpider3D
	var spider_b := PLAYER_SCENE.instantiate() as PlayerSpider3D
	root.add_child(spider)
	root.add_child(spider_b)
	var web := _make_web()
	web.position = Vector3.ZERO
	root.add_child(web)
	web.add_to_group("buildable_webs")
	var opponent_web := _make_web()
	root.add_child(opponent_web)
	opponent_web.add_to_group("buildable_webs")
	spider.silk_builder.set_build_web(web)
	spider.activate()
	spider.position = Vector3(0.35, 0.0, 0.25)
	spider_b.position = Vector3(20, 0, 0)
	spider_b.activate()
	spider_b.set("silk_amount", 4)
	spider.set("silk_amount", 2)
	spider.set("n_remaining_actions", 1)
	var check_ok := _check_anchor_selection(spider, web)
	if check_ok:
		check_ok = _check_strand_build(spider, spider_b, web)
	if check_ok:
		check_ok = _check_opponent_web_build(spider, opponent_web)
	if check_ok:
		check_ok = _check_permanent_action_slot(spider)
	_free_nodes([web, spider])
	_free_nodes([opponent_web])
	_free_nodes([spider_b])
	return check_ok


func _check_origin_on_existing_strand() -> bool:
	var spider := PLAYER_SCENE.instantiate() as PlayerSpider3D
	root.add_child(spider)
	var web := _make_web()
	root.add_child(web)
	web.add_edge(0, 1)
	spider.position = Vector3(0.35, 0.0, 0.0)
	spider.set_build_web(web)
	spider.activate()
	spider.silk_amount = 1
	spider.n_remaining_actions = 1
	var built := spider.try_build_selected_silk()
	var vertex_index := web.valid_nodes.size() - 1
	var origin_ok := web.valid_nodes.size() == 5 and (
		web.valid_nodes[vertex_index].global_position.is_equal_approx(spider.global_position)
	)
	var connected := web.has_edge(0, vertex_index)
	_free_nodes([web, spider])
	if not built or not origin_ok or not connected:
		return _fail("A spider on an existing strand near a vertex must be able to build")
	return true


func _check_anchor_selection(spider: PlayerSpider3D, owned_web: Web3D) -> bool:
	var builder := spider.silk_builder
	builder.refresh_silk_build_options()
	if builder.silk_source_web != owned_web:
		return _fail("A spider must build only on its team's assigned web")
	if builder.silk_target_indices.size() < 3:
		return _fail("Anchor cycling must expose every eligible target")
	var first_target: int = builder.silk_target_indices[builder.selected_silk_target_index]
	builder.cycle_silk_target(1)
	var next_target: int = builder.silk_target_indices[builder.selected_silk_target_index]
	if first_target == next_target:
		return _fail("Cycling must change the selected target anchor")
	spider.cancel_silk_build()
	if (spider.selected_weapon_idx != 0 or spider.silk_amount != 2
			or spider.n_remaining_actions != 1):
		return _fail("Cancelling a strand preview must spend neither silk nor an action")
	spider.selected_weapon_idx = 1
	builder.update_preview()
	return _check_preview(spider, owned_web)


func _check_preview(spider: PlayerSpider3D, owned_web: Web3D) -> bool:
	var builder := spider.silk_builder
	var preview := spider.get_node("SilkBuildAction/SilkPreview/SilkPreviewLine") as Sprite3D
	var highlight := spider.get_node("SilkBuildAction/SilkTargetHighlight") as Sprite3D
	if not preview.visible or not highlight.visible:
		return _fail("Selecting silk must show a ghost strand and target highlight")
	var target_index: int = builder.silk_target_indices[
		builder.selected_silk_target_index
	]
	var target_position := owned_web.valid_nodes[target_index].global_position
	var preview_center := preview.get_parent_node_3d().global_position
	var expected_center := (spider.global_position + target_position) * 0.5
	if preview_center.distance_to(expected_center) > 0.06:
		return _fail("The strand preview must begin at the spider's current position")
	if owned_web.valid_nodes.size() != 4 or not owned_web.edges.is_empty():
		return _fail("A strand preview must not change the web graph")
	return true


func _check_strand_build(spider: PlayerSpider3D, spider_b: PlayerSpider3D,
		web: Web3D) -> bool:
	var builder := spider.silk_builder
	builder.refresh_silk_build_options()
	var source := builder.silk_source_index
	var target := builder.silk_target_indices[builder.selected_silk_target_index]
	var previous_node_count := web.valid_nodes.size()
	var origin := spider.global_position
	if not spider.try_build_selected_silk():
		return _fail("A nearby spider must build a strand from its current position")
	if not _check_new_vertex(web, previous_node_count, origin, source, target):
		return false
	if spider.silk_amount != 1 or spider.n_remaining_actions != 0:
		return _fail("A valid strand must spend one silk and one action from its spider")
	return _check_rejected_builds(spider, spider_b, web, source, target, origin)


func _check_new_vertex(web: Web3D, previous_node_count: int, origin: Vector3,
		source: int, target: int) -> bool:
	if web.valid_nodes.size() != previous_node_count + 1:
		return _fail("Building must create a web vertex at the spider's position")
	var new_index := previous_node_count
	if not web.valid_nodes[new_index].global_position.is_equal_approx(origin):
		return _fail("The new strand must begin at the spider's position")
	if not web.has_edge(source, new_index) or not web.has_edge(new_index, target):
		return _fail("The new vertex must connect to the nearby web and target")
	return true


func _check_rejected_builds(spider: PlayerSpider3D, spider_b: PlayerSpider3D,
		web: Web3D, source: int, target: int, origin: Vector3) -> bool:
	spider.n_remaining_actions = 1
	if spider.build_silk_strand(web, source, target):
		return _fail("An invalid duplicate strand must not be built")
	if (spider.silk_amount != 1 or spider.n_remaining_actions != 1
			or spider_b.silk_amount != 4):
		return _fail("An invalid strand must not spend silk or an action")
	spider.position = Vector3(8.0, 0.0, 0.0)
	var node_count_before_far_build := web.valid_nodes.size()
	if spider.build_silk_strand(web, source, target):
		return _fail("A spider too far from a web vertex must not build")
	if web.valid_nodes.size() != node_count_before_far_build:
		return _fail("A rejected far build must not create a web vertex")
	spider.position = origin
	return true


func _check_opponent_web_build(spider: PlayerSpider3D, opponent_web: Web3D) -> bool:
	if spider.build_silk_strand(opponent_web, 0, 1):
		return _fail("A direct build call must not modify the opposing team's web")
	if spider.silk_amount != 1 or spider.n_remaining_actions != 1:
		return _fail("A rejected opposing-web build must not spend silk or an action")
	return true


func _check_permanent_action_slot(spider: PlayerSpider3D) -> bool:
	var actions: Array = spider.weapons
	if (actions.size() < 2
			or actions[1].get_script().resource_path
		!= "res://src/features/collectibles/weapons/silk_build_action.gd"):
		return _fail("Silk building must remain selectable beside the pass action")
	return true


func _check_match_spawns() -> bool:
	var match_scene := load("res://src/game/web_match.tscn").instantiate() as WebMatch3D
	(match_scene.get_node("BranchCanopy/WindEvent") as WindEvent3D).group_size = 1
	root.add_child(match_scene)
	await process_frame
	for team_name in ["TeamA", "TeamB"]:
		var team := match_scene.get_node(team_name) as Team
		for spider in team.spiders:
			spider.call("refresh_silk_build_options")
			if spider.silk_builder.owned_web != team.home_web:
				_stop_audio(match_scene)
				match_scene.free()
				return _fail("Each team must bind its spiders to its own starting web")
			if spider.silk_amount < 1 or spider.silk_builder.silk_source_web == null:
				_stop_audio(match_scene)
				match_scene.free()
				return _fail("Every spawned spider needs starter silk and a nearby web anchor")
			if spider.silk_builder.silk_target_indices.is_empty():
				_stop_audio(match_scene)
				match_scene.free()
				return _fail("Every spawned spider must begin with a legal strand target")
	_stop_audio(match_scene)
	match_scene.free()
	await create_timer(0.5).timeout
	return true


func _make_web() -> Web3D:
	var web := Web3D.new()
	var nodes: Array[Node3D] = [Node3D.new(), Node3D.new(), Node3D.new(), Node3D.new()]
	var positions: Array[Vector3] = [
		Vector3.ZERO, Vector3(2, 0, 0), Vector3(0, 0, 2), Vector3(2, 0, 2),
	]
	for index in range(nodes.size()):
		nodes[index].position = positions[index]
		web.add_child(nodes[index])
	web.valid_nodes = nodes
	return web


func _free_nodes(nodes: Array[Node]) -> void:
	for node in nodes:
		if is_instance_valid(node):
			node.free()


func _stop_audio(node: Node) -> void:
	if node is AudioStreamPlayer:
		node.stop()
		node.stream = null
	for child in node.get_children():
		_stop_audio(child)


func _fail(message: String) -> bool:
	push_error("SILK BUILD FAIL: " + message)
	return false
