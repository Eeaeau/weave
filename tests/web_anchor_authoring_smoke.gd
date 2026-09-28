extends SceneTree
## Map anchors are visible in the editor and discovered without a hand-maintained list.

const MAP_SCENE := preload("res://src/features/world/maps/branch_canopy/branch_canopy.tscn")
const MATCH_SCENE := preload("res://src/game/web_match.tscn")
const BRANCH_WEB_PATH := "res://src/features/world/maps/branch_canopy/branch_web.tscn"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var branch_web_scene := load(BRANCH_WEB_PATH) as PackedScene
	if branch_web_scene == null:
		push_error("WEB ANCHOR AUTHORING FAIL: branch web scene is missing")
		quit(1)
		return
	var branch_web := branch_web_scene.instantiate() as Node3D
	var authored_visual := branch_web.get_node_or_null("BranchVisual") as Node3D
	var authored_anchors := branch_web.get_node_or_null("WebAnchors") as Node3D
	var authored_web := branch_web.get_node_or_null("StartingWeb") as Web3D
	var standalone_complete := (authored_visual != null and authored_anchors != null
		and authored_web != null and _all_visible_markers(authored_anchors, 12)
		and authored_web.edges.size() >= 3)
	var standalone_xy := absf(authored_anchors.get_child(0).position.y) > 0.01
	for anchor in authored_anchors.get_children():
		standalone_xy = standalone_xy and absf(anchor.position.z) < 0.001
	standalone_xy = standalone_xy and absf(authored_visual.basis.y.normalized().dot(
		Vector3.UP)) > 0.99
	standalone_xy = standalone_xy and absf(authored_web.basis.y.normalized().dot(
		Vector3.BACK)) > 0.99
	root.add_child(branch_web)
	await process_frame
	standalone_complete = (standalone_complete and authored_web.valid_nodes.size() == 12
		and not authored_web.find_faces().is_empty())
	branch_web.free()
	var map := MAP_SCENE.instantiate() as Node3D
	root.add_child(map)
	var left_branch := map.get_node_or_null("Branches/LeftBranch") as Node3D
	var right_branch := map.get_node_or_null("Branches/RightBranch") as Node3D
	var left_anchors := left_branch.get_node_or_null("WebAnchors") as Node3D
	var right_anchors := right_branch.get_node_or_null("WebAnchors") as Node3D
	var shared_anchor_scene := left_anchors != null and right_anchors != null
	if shared_anchor_scene:
		shared_anchor_scene = left_branch.scene_file_path == BRANCH_WEB_PATH
		shared_anchor_scene = (shared_anchor_scene
			and right_branch.scene_file_path == BRANCH_WEB_PATH)
		shared_anchor_scene = (shared_anchor_scene
			and left_branch.scale.x * right_branch.scale.x < 0.0)
		shared_anchor_scene = shared_anchor_scene and (left_anchors.get_child(0) as Marker3D
			).position.is_equal_approx((right_anchors.get_child(0) as Marker3D).position)
	var visible_markers := shared_anchor_scene and _all_visible_markers(left_anchors, 12)
	visible_markers = visible_markers and _all_visible_markers(right_anchors, 12)
	var previews := shared_anchor_scene and left_anchors.has_method("refresh_editor_previews")
	if previews:
		left_anchors.call("refresh_editor_previews")
		right_anchors.call("refresh_editor_previews")
		previews = _all_previews(left_anchors) and _all_previews(right_anchors)
	var shared_branch := left_branch != null and right_branch != null
	if shared_branch:
		shared_branch = left_branch.scene_file_path == right_branch.scene_file_path
		shared_branch = shared_branch and not left_branch.scene_file_path.is_empty()
		shared_branch = shared_branch and left_branch.scale.x * right_branch.scale.x < 0.0
	var map_xy := (absf((left_anchors.get_child(0) as Marker3D).global_position.z) < 0.001
		and absf((right_anchors.get_child(0) as Marker3D).global_position.z) < 0.001)
	_stop_audio(map)
	map.free()

	var match_scene := MATCH_SCENE.instantiate() as WebMatch3D
	var extra_anchor := Marker3D.new()
	extra_anchor.name = "ExtraLeftAnchor"
	(match_scene.get_node("BranchCanopy/Branches/LeftBranch/WebAnchors") as Node3D
		).add_child(extra_anchor)
	var extra_right_anchor := Marker3D.new()
	extra_right_anchor.name = "ExtraRightAnchor"
	(match_scene.get_node("BranchCanopy/Branches/RightBranch/WebAnchors") as Node3D
		).add_child(extra_right_anchor)
	root.add_child(match_scene)
	current_scene = match_scene
	await process_frame
	var web_a := match_scene.get_node("BranchCanopy/Branches/LeftBranch/StartingWeb") as Web3D
	var web_b := match_scene.get_node("BranchCanopy/Branches/RightBranch/StartingWeb") as Web3D
	var discovered := web_a.valid_nodes.size() == 26 and web_b.valid_nodes.size() == 26
	discovered = discovered and web_a.valid_nodes[0].name == "Anchor01"
	discovered = discovered and web_b.valid_nodes[0].name == "Anchor01"
	discovered = discovered and web_a.valid_nodes[0] != web_b.valid_nodes[0]
	discovered = discovered and web_a.valid_nodes[12] == extra_anchor
	discovered = discovered and web_a.valid_nodes[13] == web_b.valid_nodes[0]
	discovered = discovered and web_a.valid_nodes[25] == extra_right_anchor
	discovered = discovered and web_b.valid_nodes[12] == extra_right_anchor
	discovered = discovered and web_b.valid_nodes[13] == web_a.valid_nodes[0]
	discovered = discovered and web_b.valid_nodes[25] == extra_anchor
	discovered = discovered and web_a.edges == web_b.edges
	var starting_web_support := true
	for team_name in ["TeamA", "TeamB"]:
		var team := match_scene.get_node(team_name) as Team
		starting_web_support = starting_web_support and not team.spiders.is_empty()
		for spider in team.spiders:
			var position_2d := Vector2(spider.global_position.x, spider.global_position.y)
			if not spider.is_on_web(position_2d):
				print("UNSUPPORTED STARTING SPIDER: %s at %s" % [team_name, position_2d])
				starting_web_support = false
	await create_timer(0.15).timeout
	for team_name in ["TeamA", "TeamB"]:
		var team := match_scene.get_node(team_name) as Team
		for spider in team.spiders:
			starting_web_support = starting_web_support and spider.health > 0.0
	discovered = discovered and extra_anchor.get_node_or_null("EditorPreview") == null
	discovered = discovered and extra_right_anchor.get_node_or_null("EditorPreview") == null
	_stop_audio(match_scene)
	match_scene.free()
	current_scene = null
	if not (standalone_complete and standalone_xy and shared_anchor_scene
			and visible_markers and previews and map_xy
			and shared_branch
			and discovered and starting_web_support):
		push_error("WEB ANCHOR AUTHORING FAIL: %s"
			% [[standalone_complete, standalone_xy, shared_anchor_scene,
				visible_markers, previews, map_xy, shared_branch,
				discovered, starting_web_support]])
		quit(1)
		return
	await create_timer(0.5).timeout
	print("WEB ANCHOR AUTHORING PASS: visible map points and automatic discovery")
	quit(0)


func _all_visible_markers(container: Node3D, expected_count: int) -> bool:
	if container.get_child_count() != expected_count:
		return false
	for child in container.get_children():
		if not child is Marker3D or child.gizmo_extents < 0.5:
			return false
	return true


func _all_previews(container: Node3D) -> bool:
	for anchor in container.get_children():
		var preview := anchor.get_node_or_null("EditorPreview") as Sprite3D
		if preview == null or preview.texture == null:
			return false
		if not preview.no_depth_test or not preview.fixed_size or preview.owner != null:
			return false
	return true


func _stop_audio(node: Node) -> void:
	if node is AudioStreamPlayer:
		node.stop()
		node.stream = null
	for child in node.get_children():
		_stop_audio(child)
