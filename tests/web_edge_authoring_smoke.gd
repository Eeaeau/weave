extends SceneTree
## Selecting two branch anchors creates one editable starting edge.

const BRANCH_WEB_SCENE := preload(
	"res://src/features/world/maps/branch_canopy/branch_web.tscn")
const EDGE_TOOL_PATH := "res://addons/web_edge_authoring/edge_authoring.gd"
const PLUGIN_PATH := "res://addons/web_edge_authoring/plugin.gd"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var helper := load(EDGE_TOOL_PATH) as Script
	var plugin_script := load(PLUGIN_PATH) as Script
	if helper == null or plugin_script == null or not plugin_script.can_instantiate():
		push_error("WEB EDGE AUTHORING FAIL: editor tool missing or invalid")
		quit(1)
		return
	var branch := BRANCH_WEB_SCENE.instantiate() as Node3D
	root.add_child(branch)
	var anchors := branch.get_node("WebAnchors") as Node3D
	var web := branch.get_node("StartingWeb") as Web3D
	var selection: Array[Node] = [anchors.get_child(1), anchors.get_child(2)]
	var edge := helper.call("edge_for_selection", anchors, selection) as Vector2i
	var new_edges := helper.call("with_edge_added", web.edges, edge) as Array[Vector2i]
	var duplicate_edges := helper.call("with_edge_added", new_edges, Vector2i(2, 1)) \
		as Array[Vector2i]
	var removed_edges := helper.call("with_edge_removed", new_edges, edge) \
		as Array[Vector2i]
	var valid := edge == Vector2i(1, 2)
	valid = valid and (ProjectSettings.get_setting("editor_plugins/enabled")
		as PackedStringArray).has("res://addons/web_edge_authoring/plugin.cfg")
	valid = valid and new_edges.size() == web.edges.size() + 1
	valid = valid and duplicate_edges == new_edges
	valid = valid and removed_edges == web.edges
	var foreign := Node3D.new()
	var invalid_selection: Array[Node] = [anchors.get_child(0), foreign]
	valid = valid and helper.call("edge_for_selection", anchors,
		invalid_selection) == Vector2i(-1, -1)
	valid = _check_reordered_anchors(helper, anchors, web) and valid
	foreign.free()
	branch.free()
	if not valid:
		push_error("WEB EDGE AUTHORING FAIL: selected pair did not toggle cleanly")
		quit(1)
		return
	print("WEB EDGE AUTHORING PASS: selected markers create and remove one edge")
	quit(0)


func _check_reordered_anchors(helper: Script, anchors: Node3D, web: Web3D) -> bool:
	var first_edge := web.edges[0]
	var first_name := String(web.valid_nodes[first_edge.x].name)
	var second_name := String(web.valid_nodes[first_edge.y].name)
	anchors.move_child(anchors.get_node("Anchor01"), anchors.get_child_count() - 1)
	web._discover_anchor_nodes()
	var selected: Array[Node] = [anchors.get_node("Anchor01"), anchors.get_node("Anchor02")]
	var selected_edge := helper.call("edge_for_selection", anchors, selected,
		web.ordered_anchors(anchors)) as Vector2i
	var new_anchor := Marker3D.new()
	new_anchor.name = "UnlistedAnchor"
	anchors.add_child(new_anchor)
	var warns_on_new_anchor := not web.get_anchor_order_warnings().is_empty()
	new_anchor.free()
	var stable_after_reorder := warns_on_new_anchor \
		and String(web.valid_nodes[first_edge.x].name) == first_name \
		and String(web.valid_nodes[first_edge.y].name) == second_name \
		and selected_edge == first_edge
	var removed_anchor := anchors.get_node("Anchor01")
	anchors.remove_child(removed_anchor)
	removed_anchor.free()
	web._discover_anchor_nodes()
	return stable_after_reorder and web.valid_nodes[first_edge.x] == null \
		and not web.get_anchor_order_warnings().is_empty()
