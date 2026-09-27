class_name SilkBuildAction3D
extends Weapon3D
## Permanent action slot used to select and place a silk strand.

const MAX_SOURCE_ANCHOR_DISTANCE: float = 1.5
const MAX_WEB_PLANE_DISTANCE: float = 0.5
const EXISTING_VERTEX_DISTANCE: float = 0.01

var spider: Node
var owned_web: Web3D
var silk_source_web: Web3D
var silk_source_index: int = -1
var silk_target_indices: Array[int] = []
var selected_silk_target_index: int = 0
var _preview_root: Node3D
var _preview_line: Sprite3D
var _target_highlight: Sprite3D


func _ready() -> void:
	spider = get_parent()
	_create_preview()


func fire(_aim_direction: float, _aim_magnitude: float) -> void:
	try_build_selected_silk()


func is_used_up() -> bool:
	return false


func set_build_web(web: Web3D) -> void:
	owned_web = web
	refresh_silk_build_options()


## Finds a nearby web vertex that can support a strand from the spider's position.
func refresh_silk_build_options() -> void:
	var previous_target := -1
	if not silk_target_indices.is_empty():
		previous_target = silk_target_indices[selected_silk_target_index]
	silk_source_web = null
	silk_source_index = -1
	silk_target_indices.clear()
	selected_silk_target_index = 0
	if not is_inside_tree() or owned_web == null:
		return
	var web := owned_web
	var local_origin := web.to_local(spider.global_position)
	if absf(local_origin.y) > MAX_WEB_PLANE_DISTANCE:
		return
	local_origin.y = 0.0
	var origin := web.to_global(local_origin)

	var max_distance_squared := (
		MAX_SOURCE_ANCHOR_DISTANCE * MAX_SOURCE_ANCHOR_DISTANCE
	)
	var nearest_distance_squared := max_distance_squared
	for source_index in range(web.valid_nodes.size()):
		var source := web.valid_nodes[source_index]
		if source == null:
			continue
		var distance_squared: float = origin.distance_squared_to(
			source.global_position
		)
		if distance_squared > nearest_distance_squared:
			continue
		var eligible_targets := _find_targets(web, source_index, origin)
		if eligible_targets.is_empty():
			continue
		nearest_distance_squared = distance_squared
		silk_source_web = web
		silk_source_index = source_index
		silk_target_indices = eligible_targets
	var previous_index := silk_target_indices.find(previous_target)
	if previous_index >= 0:
		selected_silk_target_index = previous_index


func cycle_silk_target(direction: int) -> void:
	if silk_target_indices.is_empty() or direction == 0:
		return
	selected_silk_target_index = posmod(
		selected_silk_target_index + signi(direction), silk_target_indices.size()
	)


func cancel_selection() -> void:
	if spider != null:
		spider.set("selected_weapon_idx", 0)
	hide_preview()


func try_build_selected_silk() -> bool:
	if spider == null:
		return false
	refresh_silk_build_options()
	if silk_source_web == null or silk_target_indices.is_empty():
		return false
	var target_index := silk_target_indices[selected_silk_target_index]
	return build_silk_strand(silk_source_web, silk_source_index, target_index)


func build_silk_strand(web: Web3D, source_index: int, target_index: int) -> bool:
	if not _can_build_on_web(web, source_index, target_index):
		return false
	var local_origin := web.to_local(spider.global_position)
	if absf(local_origin.y) > MAX_WEB_PLANE_DISTANCE:
		return false
	local_origin.y = 0.0
	var origin := web.to_global(local_origin)
	var source_position := web.valid_nodes[source_index].global_position
	if origin.distance_to(source_position) > MAX_SOURCE_ANCHOR_DISTANCE:
		return false
	if not _find_targets(web, source_index, origin).has(target_index):
		return false
	if not _commit_strand(web, source_index, target_index, origin):
		return false
	spider.set("silk_amount", spider.get("silk_amount") - 1)
	spider.set("n_remaining_actions", spider.get("n_remaining_actions") - 1)
	refresh_silk_build_options()
	return true


func _can_build_on_web(web: Web3D, source_index: int, target_index: int) -> bool:
	if spider == null or not spider.get("is_active"):
		return false
	if (web == null or web != owned_web
			or spider.get("n_remaining_actions") <= 0
			or spider.get("silk_amount") <= 0):
		return false
	if (source_index < 0 or source_index >= web.valid_nodes.size()
			or target_index < 0 or target_index >= web.valid_nodes.size()):
		return false
	return web.valid_nodes[source_index] != null and web.valid_nodes[target_index] != null


func update_preview() -> void:
	refresh_silk_build_options()
	if (spider.get("silk_amount") <= 0 or spider.get("n_remaining_actions") <= 0
			or silk_source_web == null or silk_target_indices.is_empty()):
		hide_preview()
		return
	var local_origin := silk_source_web.to_local(spider.global_position)
	local_origin.y = 0.0
	var origin := silk_source_web.to_global(local_origin)
	var target := silk_source_web.valid_nodes[
		silk_target_indices[selected_silk_target_index]
	]
	var direction := target.global_position - origin
	_preview_root.global_position = (
		(origin + target.global_position) * 0.5 + Vector3.UP * 0.05
	)
	_preview_root.global_rotation = Vector3(0.0, atan2(-direction.z, direction.x), 0.0)
	_preview_line.scale.x = direction.length() / (256.0 * _preview_line.pixel_size)
	_preview_line.visible = true
	_target_highlight.global_position = target.global_position + Vector3.UP * 0.04
	_target_highlight.visible = true


func _find_targets(web: Web3D, source_index: int, origin: Vector3) -> Array[int]:
	var targets: Array[int] = []
	var source_position := web.valid_nodes[source_index].global_position
	if origin.distance_to(source_position) <= EXISTING_VERTEX_DISTANCE:
		for index in range(web.valid_nodes.size()):
			if web.valid_nodes[index] != null and web.can_add_edge(source_index, index):
				targets.append(index)
		return targets

	var probe := Node3D.new()
	web.add_child(probe)
	probe.global_position = origin
	var probe_index := web.valid_nodes.size()
	web.valid_nodes.append(probe)
	if web.can_add_edge(source_index, probe_index):
		web.edges.append(Vector2i(source_index, probe_index))
		for index in range(probe_index):
			if (index != source_index and web.valid_nodes[index] != null
					and web.can_add_edge(probe_index, index)):
				targets.append(index)
		web.edges.pop_back()
	web.valid_nodes.pop_back()
	probe.free()
	return targets


func _commit_strand(web: Web3D, source_index: int, target_index: int,
		origin: Vector3) -> bool:
	var source_position := web.valid_nodes[source_index].global_position
	if origin.distance_to(source_position) <= EXISTING_VERTEX_DISTANCE:
		return web.add_edge(source_index, target_index)
	var vertex := Node3D.new()
	vertex.name = "SilkVertex"
	var node_parent := web.get_node_or_null("Nodes") as Node3D
	if node_parent == null:
		node_parent = web
	node_parent.add_child(vertex)
	vertex.global_position = origin
	var vertex_index := web.valid_nodes.size()
	web.valid_nodes.append(vertex)
	if not web.can_add_edge(source_index, vertex_index):
		web.valid_nodes.pop_back()
		vertex.free()
		return false
	web.edges.append(Vector2i(source_index, vertex_index))
	if not web.can_add_edge(vertex_index, target_index):
		web.edges.pop_back()
		web.valid_nodes.pop_back()
		vertex.free()
		return false
	web.edges.append(Vector2i(vertex_index, target_index))
	web.rebuild()
	return true


func hide_preview() -> void:
	if _preview_line:
		_preview_line.visible = false
	if _target_highlight:
		_target_highlight.visible = false


func _create_preview() -> void:
	_preview_root = Node3D.new()
	_preview_root.name = "SilkPreview"
	add_child(_preview_root)
	_preview_line = Sprite3D.new()
	_preview_line.name = "SilkPreviewLine"
	_preview_line.texture = load("res://src/features/web/assets/strand.svg")
	_preview_line.pixel_size = 0.004
	_preview_line.modulate = Color(0.55, 1.0, 0.9, 0.65)
	_preview_line.rotation.x = -PI / 2.0
	_preview_line.visible = false
	_preview_root.add_child(_preview_line)
	_target_highlight = Sprite3D.new()
	_target_highlight.name = "SilkTargetHighlight"
	_target_highlight.texture = load("res://src/features/spiders/assets/silk_anchor.svg")
	_target_highlight.pixel_size = 0.012
	_target_highlight.modulate = Color(1.0, 0.82, 0.35, 0.95)
	_target_highlight.rotation.x = -PI / 2.0
	_target_highlight.visible = false
	add_child(_target_highlight)
