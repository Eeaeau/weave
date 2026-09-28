extends SceneTree
## Map anchors are visible in the editor and discovered without a hand-maintained list.

const MAP_SCENE := preload("res://src/features/world/maps/branch_canopy/branch_canopy.tscn")
const MATCH_SCENE := preload("res://src/game/web_match.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var map := MAP_SCENE.instantiate() as Node3D
	var team_a := map.get_node("WebAnchors/TeamA") as Node3D
	var team_b := map.get_node("WebAnchors/TeamB") as Node3D
	var visible_markers := _all_visible_markers(team_a, 12)
	visible_markers = visible_markers and _all_visible_markers(team_b, 15)
	map.free()

	var match_scene := MATCH_SCENE.instantiate() as WebMatch3D
	var extra_anchor := Marker3D.new()
	extra_anchor.name = "ExtraAnchor"
	(match_scene.get_node("BranchCanopy/WebAnchors/TeamA") as Node3D).add_child(extra_anchor)
	root.add_child(match_scene)
	current_scene = match_scene
	await process_frame
	var web_a := match_scene.get_node("WebA") as Web3D
	var web_b := match_scene.get_node("WebB") as Web3D
	var discovered := web_a.valid_nodes.size() == 13 and web_b.valid_nodes.size() == 15
	discovered = discovered and web_a.valid_nodes[0].name == "1"
	discovered = discovered and web_a.valid_nodes[12] == extra_anchor
	_stop_audio(match_scene)
	match_scene.free()
	current_scene = null
	if not (visible_markers and discovered):
		push_error("WEB ANCHOR AUTHORING FAIL: markers=%s discovery=%s"
			% [visible_markers, discovered])
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


func _stop_audio(node: Node) -> void:
	if node is AudioStreamPlayer:
		node.stop()
		node.stream = null
	for child in node.get_children():
		_stop_audio(child)
