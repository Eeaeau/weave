@tool
extends EditorPlugin

const EdgeAuthoring := preload("res://addons/web_edge_authoring/edge_authoring.gd")


func _enter_tree() -> void:
	add_tool_menu_item("Connect Selected Web Anchors", _connect_selected)
	add_tool_menu_item("Remove Selected Web Edge", _remove_selected)


func _exit_tree() -> void:
	remove_tool_menu_item("Connect Selected Web Anchors")
	remove_tool_menu_item("Remove Selected Web Edge")


func _connect_selected() -> void:
	_change_selected_edge(true)


func _remove_selected() -> void:
	_change_selected_edge(false)


func _change_selected_edge(add: bool) -> void:
	var branch := EditorInterface.get_edited_scene_root() as Node3D
	if branch == null:
		return
	var anchors := branch.get_node_or_null("WebAnchors") as Node3D
	var web := branch.get_node_or_null("StartingWeb") as Web3D
	if anchors == null or web == null:
		push_warning("Open a branch scene with WebAnchors and StartingWeb")
		return
	var edge := EdgeAuthoring.edge_for_selection(
		anchors, EditorInterface.get_selection().get_selected_nodes())
	if edge.x < 0:
		push_warning("Select two WebAnchors markers in the viewport or Scene tree")
		return
	var previous := web.edges.duplicate()
	var updated: Array[Vector2i] = (EdgeAuthoring.with_edge_added(previous, edge)
		if add else EdgeAuthoring.with_edge_removed(previous, edge))
	if updated == previous:
		return
	var undo_redo := get_undo_redo()
	undo_redo.create_action("Connect web anchors" if add else "Remove web edge")
	undo_redo.add_do_property(web, "edges", updated)
	undo_redo.add_undo_property(web, "edges", previous)
	undo_redo.commit_action()
