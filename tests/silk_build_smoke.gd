extends SceneTree
## Exercise personal silk, insect feeding, strand actions, and anchor cycling.

const PLAYER_SCENE := preload("res://src/features/spiders/player_spider.tscn")
const INSECT_SCENE := preload("res://src/features/collectibles/insects/windborne_insect.tscn")
const WIND_BORNE_WEAPON_SCENE := preload(
	"res://src/features/collectibles/weapons/windborne_weapon.tscn"
)
const MAX_TEST_STRAND_LENGTH: float = 3.0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if not await _check_insect_proximity():
		quit(1)
		return
	if not _check_build_and_selection():
		quit(1)
		return
	if not await _check_space_controls():
		quit(1)
		return
	if not _check_target_range_and_crossing():
		quit(1)
		return
	if not _check_triangle_fill_lifecycle() or not _check_builder_survives_triangle_completion():
		quit(1)
		return
	if not await _check_match_spawns():
		quit(1)
		return
	print("SILK BUILD PASS: personal silk, feeding, strand actions, and anchor cycling")
	quit(0)


func _check_space_controls() -> bool:
	if not await _check_tab_and_space_controls():
		return false
	return await _check_build_release_keeps_next_spider_action()


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
	beetle.call("_area_entered", spider_a.get("hurtbox"))
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
	spider.position = Vector3(0.9, 0.0, 0.9)
	spider_b.position = Vector3(20, 0, 0)
	spider_b.activate()
	spider_b.set("silk_amount", 4)
	spider.set("silk_amount", 2)
	spider.set("n_remaining_actions", 1)
	var check_ok := _check_visible_vertex_proximity()
	if check_ok:
		check_ok = _check_anchor_selection(spider, web)
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


func _check_visible_vertex_proximity() -> bool:
	var spider := PLAYER_SCENE.instantiate() as PlayerSpider3D
	var web := _make_web()
	root.add_child(web)
	root.add_child(spider)
	spider.global_position = web.valid_nodes[0].global_position + Vector3(0.55, 0.25, 0.0)
	spider.set_build_web(web)
	spider.activate()
	spider.silk_amount = 1
	spider.n_remaining_actions = 1
	spider.silk_builder.refresh_silk_build_options()
	var source_index := spider.silk_builder.silk_source_index
	var has_targets := not spider.silk_builder.silk_target_indices.is_empty()
	var built := spider.try_build_selected_silk()
	_free_nodes([web, spider])
	if source_index != 0 or not has_targets or not built:
		return _fail("A spider near a vertex must see targets and build despite depth offset")
	return true


func _check_target_range_and_crossing() -> bool:
	var spider := PLAYER_SCENE.instantiate() as PlayerSpider3D
	var web := _make_web()
	root.add_child(web)
	web.add_edge(1, 2)
	var far_node := Node3D.new()
	far_node.position = Vector3(4, 0, -1)
	web.add_child(far_node)
	web.valid_nodes.append(far_node)
	root.add_child(spider)
	spider.global_position = web.valid_nodes[0].global_position
	spider.set_build_web(web)
	spider.activate()
	spider.silk_builder.refresh_silk_build_options()
	var targets := spider.silk_builder.silk_target_indices
	var source := spider.silk_builder.silk_source_index
	var target_range_ok := source == 0 and targets.has(1) and targets.has(2)
	var crossing_rejected := not targets.has(3)
	var distant_rejected := web.can_add_edge(0, 4) and not targets.has(4)
	var invalid_api_index_rejected := not web.can_add_edge(0, web.valid_nodes.size())
	for target in targets:
		var distance := web.valid_nodes[source].global_position.distance_to(
			web.valid_nodes[target].global_position
		)
		if distance > MAX_TEST_STRAND_LENGTH:
			target_range_ok = false
		if not web.can_add_edge(source, target):
			target_range_ok = false
	_free_nodes([web, spider])
	if not target_range_ok:
		return _fail("Only nearby targets that pass the web graph rules may be selected")
	if not crossing_rejected:
		return _fail("A target whose strand crosses an existing edge must be excluded")
	if not distant_rejected:
		return _fail("Targets beyond strand range must be excluded")
	if not invalid_api_index_rejected:
		return _fail("Web3D must reject node indices equal to the graph size")
	return true


func _check_triangle_fill_lifecycle() -> bool:
	var spider := PLAYER_SCENE.instantiate() as PlayerSpider3D
	var web := _make_web()
	root.add_child(web)
	root.add_child(spider)
	web.add_edge(0, 1)
	web.add_edge(1, 2)
	spider.global_position = web.valid_nodes[0].global_position
	spider.set_build_web(web)
	spider.activate()
	spider.silk_amount = 1
	spider.n_remaining_actions = 1
	spider.silk_builder.refresh_silk_build_options()
	var closes_triangle := spider.silk_builder.silk_target_indices.has(2)
	var built := spider.build_silk_strand(web, 0, 2)
	var fill_created := (web.find_faces().size() == 1
			and _count_web_polygons(web) == 1
			and not web.find_catch_face(Vector3(0.5, 0, 0.5)).is_empty())
	var removed := web.remove_edge(0, 1)
	var fill_removed := (web.find_faces().is_empty()
			and _count_web_polygons(web) == 2
			and web.find_catch_face(Vector3(0.5, 0, 0.5)).is_empty())
	_free_nodes([web, spider])
	if not closes_triangle or not built or not fill_created:
		return _fail("Closing a triangle with silk must create the filled face automatically")
	if not removed or not fill_removed:
		return _fail("Removing a triangle edge must remove its fill and catch contact")
	return true


func _check_builder_survives_triangle_completion() -> bool:
	var web := Web3D.new()
	web.rotation.x = -PI / 2.0
	var anchors: Array[Node3D] = [Node3D.new(), Node3D.new(), Node3D.new()]
	var positions := [Vector3.ZERO, Vector3(2, 0, 0), Vector3(0, 0, 2)]
	for index in anchors.size():
		anchors[index].position = positions[index]
		web.add_child(anchors[index])
	root.add_child(web)
	web.valid_nodes = anchors
	web.add_edge(0, 1)
	web.add_edge(1, 2)
	var spider := PLAYER_SCENE.instantiate() as PlayerSpider3D
	spider.webs = [web]
	root.add_child(spider)
	spider.global_position = anchors[0].global_position + Vector3(0.5, -0.05, 0.0)
	spider.set_build_web(web)
	spider.activate()
	spider.n_remaining_actions = 1
	var position := Vector2(spider.global_position.x, spider.global_position.y)
	var supported_before := spider.is_on_web(position)
	var built := spider.build_silk_strand(web, 0, 2)
	var supported_after := spider.is_on_web(position)
	spider._process(0.0)
	var survived := not spider.is_dead()
	_free_nodes([spider, web])
	if not supported_before or not built or not supported_after or not survived:
		return _fail("Closing a triangle must keep its former standalone edge walkable")
	return true


func _count_web_polygons(web: Web3D) -> int:
	var count := 0
	for child in web.polygon_container.get_children():
		if child is WebPolygon3D:
			count += 1
	return count


func _check_tab_and_space_controls() -> bool:
	var spider := PLAYER_SCENE.instantiate() as PlayerSpider3D
	var web := _make_web()
	root.add_child(web)
	root.add_child(spider)
	spider.global_position = web.valid_nodes[0].global_position
	spider.set_build_web(web)
	spider.activate()
	spider.silk_amount = 1
	spider.n_remaining_actions = 1
	spider.selected_weapon_idx = 1
	await process_frame
	spider.silk_builder.refresh_silk_build_options()
	var first_target: int = spider.silk_builder.silk_target_indices[
		spider.silk_builder.selected_silk_target_index
	]
	Input.action_press("cycle_silk_target_next")
	await process_frame
	Input.action_release("cycle_silk_target_next")
	await process_frame
	var selected_target: int = spider.silk_builder.silk_target_indices[
		spider.silk_builder.selected_silk_target_index
	]
	if selected_target == first_target:
		_free_nodes([web, spider])
		return _fail("The target-cycle input must highlight the next valid node")
	Input.action_press("action")
	await process_frame
	Input.action_release("action")
	await process_frame
	var built := web.has_edge(0, selected_target)
	var resources_spent := spider.silk_amount == 0 and spider.n_remaining_actions == 0
	_free_nodes([web, spider])
	if not built or not resources_spent:
		return _fail("Space must build to the highlighted node and spend one turn action")
	return true


func _check_build_release_keeps_next_spider_action() -> bool:
	var web := _make_web()
	root.add_child(web)
	var team := Team.new()
	team.spider_scene = PLAYER_SCENE
	team.home_web = web
	root.add_child(team)
	team.spawn_spiders(2)
	await process_frame
	team.start_turn(10.0)
	var builder := team.spiders[0]
	var next_spider := team.spiders[1]
	builder.selected_weapon_idx = 1
	Input.action_press("action")
	await process_frame
	var kept_first_turn := (team.get_active_spider() == builder
			and builder.n_remaining_actions == 1)
	Input.action_release("action")
	await process_frame
	await process_frame
	var next_turn_intact := (team.get_active_spider() == next_spider
			and next_spider.n_remaining_actions == 1
			and web.edges.size() == 1)
	_free_nodes([team, web])
	if not kept_first_turn or not next_turn_intact:
		return _fail("Building silk must not spend the next spider's action")
	return true


func _check_anchor_selection(spider: PlayerSpider3D, owned_web: Web3D) -> bool:
	var builder := spider.silk_builder
	builder.refresh_silk_build_options()
	if builder.silk_source_web != null or not builder.silk_target_indices.is_empty():
		return _fail("Silk targets must stay hidden until the spider reaches a web vertex")
	spider.global_position = owned_web.valid_nodes[0].global_position
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
	if not preview.visible:
		return _fail("Selecting silk at a web vertex must show the planned strand")
	if builder.target_markers.size() != builder.silk_target_indices.size():
		return _fail("Every valid nearby target must have a visible marker")
	var markers_ok := true
	for marker in builder.target_markers:
		if not marker.visible:
			markers_ok = false
	var selected_marker := builder.target_markers[builder.selected_silk_target_index]
	for index in range(builder.target_markers.size()):
		if (index != builder.selected_silk_target_index
				and selected_marker.pixel_size <= builder.target_markers[index].pixel_size):
			markers_ok = false
	if not markers_ok:
		return _fail("All targets must show, with the selected node visually distinct")
	var target_index: int = builder.silk_target_indices[
		builder.selected_silk_target_index
	]
	var target_position := owned_web.valid_nodes[target_index].global_position
	var source_position := owned_web.valid_nodes[builder.silk_source_index].global_position
	var preview_center := preview.get_parent_node_3d().global_position
	var expected_center := (source_position + target_position) * 0.5
	if preview_center.distance_to(expected_center) > 0.06:
		return _fail("The strand preview must connect the selected existing vertices")
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
		return _fail("A spider standing on a web vertex must build to its selected target")
	if (web.valid_nodes.size() != previous_node_count
			or not web.has_edge(source, target)):
		return _fail("Building must connect existing vertices without adding a new vertex")
	if spider.silk_amount != 1 or spider.n_remaining_actions != 0:
		return _fail("A valid strand must spend one silk and one action from its spider")
	return _check_rejected_builds(spider, spider_b, web, source, target, origin)


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
			if spider.silk_amount < 1:
				_stop_audio(match_scene)
				match_scene.free()
				return _fail("Every spawned spider needs starter silk")
			if not _can_reach_starting_build(team.home_web, spider):
				_stop_audio(match_scene)
				match_scene.free()
				return _fail(
					"Every spawned spider must be able to reach a legal starting web vertex"
				)
			if not _has_visible_starting_hint(team.home_web, spider):
				_stop_audio(match_scene)
				match_scene.free()
				return _fail(
					"A spider at a starting web vertex must see silk attachment hints"
				)
	_stop_audio(match_scene)
	match_scene.free()
	await create_timer(0.5).timeout
	return true


func _has_visible_starting_hint(web: Web3D, spider: PlayerSpider3D) -> bool:
	var builder := spider.silk_builder
	var nearest_source := -1
	var nearest_distance := INF
	for source_index in range(web.valid_nodes.size()):
		if builder._find_targets(web, source_index).is_empty():
			continue
		var distance := spider.global_position.distance_to(
			web.valid_nodes[source_index].global_position)
		if distance < nearest_distance:
			nearest_source = source_index
			nearest_distance = distance
	if nearest_source < 0 or nearest_distance > 5.0:
		return false
	spider.global_position = web.valid_nodes[nearest_source].global_position
	spider.activate()
	spider.n_remaining_actions = 1
	spider.selected_weapon_idx = 1
	builder.update_preview()
	if builder.silk_source_index != nearest_source or not builder._preview_line.visible:
		return false
	for marker in builder.target_markers:
		if marker.visible:
			return true
	return false


func _can_reach_starting_build(web: Web3D, spider: PlayerSpider3D) -> bool:
	for source_index in range(web.valid_nodes.size()):
		var source := web.valid_nodes[source_index]
		if spider.global_position.distance_to(source.global_position) > 10.0:
			continue
		for target_index in range(web.valid_nodes.size()):
			if source_index == target_index or not is_instance_valid(web.valid_nodes[target_index]):
				continue
			var target := web.valid_nodes[target_index]
			if source.global_position.distance_to(target.global_position) > web.max_strand_length:
				continue
			if web.can_add_edge(source_index, target_index):
				return true
	return false


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
