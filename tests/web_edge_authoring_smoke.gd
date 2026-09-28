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
	foreign.free()
	branch.free()
	if not valid:
		push_error("WEB EDGE AUTHORING FAIL: selected pair did not toggle cleanly")
		quit(1)
		return
	print("WEB EDGE AUTHORING PASS: selected markers create and remove one edge")
	quit(0)
