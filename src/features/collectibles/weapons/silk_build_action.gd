class_name SilkBuildAction3D
extends Weapon3D
## Permanent action slot used to select and place a silk strand.

const VERTEX_INTERACTION_DISTANCE: float = 0.75
const MAX_WEB_PLANE_DISTANCE: float = 0.5

var spider: Node
var owned_web: Web3D
var silk_source_web: Web3D
var silk_source_index: int = -1
var silk_target_indices: Array[int] = []
var selected_silk_target_index: int = 0
var target_markers: Array[Sprite3D] = []
var _preview_root: Node3D
var _preview_line: Sprite3D
var _target_marker_template: Sprite3D


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


## Exposes targets only when the spider is standing at an owned web vertex.
func refresh_silk_build_options() -> void:
	var previous_target := -1
	if not silk_target_indices.is_empty():
		previous_target = silk_target_indices[selected_silk_target_index]
	silk_source_web = null
	silk_source_index = -1
	silk_target_indices.clear()
	selected_silk_target_index = 0
	if (not is_inside_tree() or not is_instance_valid(spider)
			or not is_instance_valid(owned_web)):
		return
	var web := owned_web
	var local_spider_position := web.to_local(spider.global_position)
	if absf(local_spider_position.y) > MAX_WEB_PLANE_DISTANCE:
		return
	var nearest_distance := VERTEX_INTERACTION_DISTANCE
	for source_index in range(web.valid_nodes.size()):
		var source := web.valid_nodes[source_index]
		if not is_instance_valid(source):
			continue
		var distance := _planar_vertex_distance(web, local_spider_position, source)
		if distance > nearest_distance:
			continue
		var eligible_targets := _find_targets(web, source_index)
		if eligible_targets.is_empty():
			continue
		nearest_distance = distance
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
		if spider.has_method("select_weapon"):
			spider.call("select_weapon", 0)
		else:
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
	var local_spider_position := web.to_local(spider.global_position)
	if absf(local_spider_position.y) > MAX_WEB_PLANE_DISTANCE:
		return false
	var source := web.valid_nodes[source_index]
	if (_planar_vertex_distance(web, local_spider_position, source)
			> VERTEX_INTERACTION_DISTANCE):
		return false
	if not _find_targets(web, source_index).has(target_index):
		return false
	if not web.add_edge(source_index, target_index):
		return false
	spider.set("silk_amount", spider.get("silk_amount") - 1)
	spider.set("n_remaining_actions", spider.get("n_remaining_actions") - 1)
	refresh_silk_build_options()
	return true


func _planar_vertex_distance(web: Web3D, local_spider_position: Vector3,
		source: Node3D) -> float:
	var local_source := web.to_local(source.global_position)
	return Vector2(local_spider_position.x, local_spider_position.z).distance_to(
		Vector2(local_source.x, local_source.z)
	)


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
	return (is_instance_valid(web.valid_nodes[source_index])
		and is_instance_valid(web.valid_nodes[target_index]))


func update_preview() -> void:
	refresh_silk_build_options()
	if (spider.get("silk_amount") <= 0 or spider.get("n_remaining_actions") <= 0
			or silk_source_web == null or silk_target_indices.is_empty()):
		hide_preview()
		return
	var source := silk_source_web.valid_nodes[silk_source_index]
	var target_count := silk_target_indices.size()
	_ensure_target_markers(target_count)
	for index in range(target_count):
		var target := silk_source_web.valid_nodes[silk_target_indices[index]]
		var marker := target_markers[index]
		marker.visible = true
		marker.global_position = target.global_position + Vector3.UP * 0.04
		if index == selected_silk_target_index:
			marker.pixel_size = 0.016
			marker.modulate = Color(1.0, 0.82, 0.35, 0.95)
		else:
			marker.pixel_size = 0.011
			marker.modulate = Color(0.55, 1.0, 0.9, 0.8)
	var selected_target := silk_source_web.valid_nodes[
		silk_target_indices[selected_silk_target_index]
	]
	var direction := selected_target.global_position - source.global_position
	_preview_root.global_position = (
		(source.global_position + selected_target.global_position) * 0.5
		+ Vector3.UP * 0.05
	)
	_preview_root.global_rotation = Vector3(0.0, atan2(-direction.z, direction.x), 0.0)
	_preview_line.scale.x = direction.length() / (256.0 * _preview_line.pixel_size)
	_preview_line.visible = true


func _find_targets(web: Web3D, source_index: int) -> Array[int]:
	var targets: Array[int] = []
	var source := web.valid_nodes[source_index]
	for target_index in range(web.valid_nodes.size()):
		var target := web.valid_nodes[target_index]
		if not is_instance_valid(target):
			continue
		if source.global_position.distance_to(target.global_position) > web.max_strand_length:
			continue
		if web.can_add_edge(source_index, target_index):
			targets.append(target_index)
	return targets


func _ensure_target_markers(target_count: int) -> void:
	while target_markers.size() < target_count:
		var marker := _target_marker_template.duplicate() as Sprite3D
		marker.name = "SilkTargetMarker%d" % target_markers.size()
		add_child(marker)
		target_markers.append(marker)
	for index in range(target_markers.size()):
		target_markers[index].visible = index < target_count


func hide_preview() -> void:
	if _preview_line:
		_preview_line.visible = false
	for marker in target_markers:
		marker.visible = false


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
	_target_marker_template = Sprite3D.new()
	_target_marker_template.name = "SilkTargetMarkerTemplate"
	_target_marker_template.texture = load("res://src/features/spiders/assets/silk_anchor.svg")
	_target_marker_template.rotation.x = -PI / 2.0
	_target_marker_template.visible = false
	add_child(_target_marker_template)
