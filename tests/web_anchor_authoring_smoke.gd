extends SceneTree
## Map anchors are visible in the editor and discovered without a hand-maintained list.

const MAP_SCENE := preload("res://src/features/world/maps/branch_canopy/branch_canopy.tscn")
const MATCH_SCENE := preload("res://src/game/web_match.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var map := MAP_SCENE.instantiate() as Node3D
	var anchors := map.get_node_or_null("WebAnchors") as Node3D
	var left_anchors := map.get_node_or_null("WebAnchors/LeftAnchors") as Node3D
	var right_anchors := map.get_node_or_null("WebAnchors/RightAnchors") as Node3D
	var shared_anchor_scene := left_anchors != null and right_anchors != null
	if shared_anchor_scene:
		shared_anchor_scene = left_anchors.scene_file_path == right_anchors.scene_file_path
		shared_anchor_scene = shared_anchor_scene and not left_anchors.scene_file_path.is_empty()
		var anchor_template := load(left_anchors.scene_file_path) as PackedScene
		var authored_set := anchor_template.instantiate() as Node3D
		shared_anchor_scene = (shared_anchor_scene
			and authored_set.transform.basis.is_equal_approx(Basis.IDENTITY))
		authored_set.free()
		shared_anchor_scene = (shared_anchor_scene
			and left_anchors.scale.x * right_anchors.scale.x < 0.0)
		shared_anchor_scene = shared_anchor_scene and (left_anchors.get_child(0) as Marker3D
			).position.is_equal_approx((right_anchors.get_child(0) as Marker3D).position)
	var visible_markers := shared_anchor_scene and _all_visible_markers(left_anchors, 12)
	visible_markers = visible_markers and _all_visible_markers(right_anchors, 12)
	var previews := shared_anchor_scene and left_anchors.has_method("refresh_editor_previews")
	if previews:
		left_anchors.call("refresh_editor_previews")
		right_anchors.call("refresh_editor_previews")
		previews = _all_previews(left_anchors) and _all_previews(right_anchors)
	var left_branch := map.get_node_or_null("Branches/LeftBranch") as Node3D
	var right_branch := map.get_node_or_null("Branches/RightBranch") as Node3D
	var shared_branch := left_branch != null and right_branch != null
	if shared_branch:
		shared_branch = left_branch.scene_file_path == right_branch.scene_file_path
		shared_branch = shared_branch and not left_branch.scene_file_path.is_empty()
		shared_branch = shared_branch and left_branch.scale.x * right_branch.scale.x < 0.0
	map.free()

	var match_scene := MATCH_SCENE.instantiate() as WebMatch3D
	var extra_anchor := Marker3D.new()
	extra_anchor.name = "ExtraLeftAnchor"
	(match_scene.get_node("BranchCanopy/WebAnchors/LeftAnchors") as Node3D
		).add_child(extra_anchor)
	var extra_right_anchor := Marker3D.new()
	extra_right_anchor.name = "ExtraRightAnchor"
	(match_scene.get_node("BranchCanopy/WebAnchors/RightAnchors") as Node3D
		).add_child(extra_right_anchor)
	root.add_child(match_scene)
	current_scene = match_scene
	await process_frame
	var web_a := match_scene.get_node("WebA") as Web3D
	var web_b := match_scene.get_node("WebB") as Web3D
	var discovered := web_a.valid_nodes.size() == 26 and web_b.valid_nodes.size() == 26
	discovered = discovered and web_a.valid_nodes[0].name == "Anchor01"
	discovered = discovered and web_a.valid_nodes[1].name == "Anchor01"
	discovered = discovered and web_a.valid_nodes[1] != web_a.valid_nodes[0]
	discovered = discovered and web_a.valid_nodes[1] == web_b.valid_nodes[1]
	discovered = discovered and web_a.valid_nodes[24] == extra_anchor
	discovered = discovered and web_b.valid_nodes[24] == extra_anchor
	discovered = discovered and web_a.valid_nodes[25] == extra_right_anchor
	discovered = discovered and web_b.valid_nodes[25] == extra_right_anchor
	for edge in web_a.edges:
		discovered = discovered and edge.x % 2 == 0 and edge.y % 2 == 0
	for edge in web_b.edges:
		discovered = discovered and edge.x % 2 == 1 and edge.y % 2 == 1
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
	if not (shared_anchor_scene and visible_markers and previews and shared_branch
			and discovered and starting_web_support):
		push_error("WEB ANCHOR AUTHORING FAIL: %s"
			% [[shared_anchor_scene, visible_markers, previews, shared_branch,
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
