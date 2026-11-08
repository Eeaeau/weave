class_name Flamethrower3D
extends Weapon3D

@export_range(0.5, 10.0, 0.1) var reach := 4.0
@export_range(0.05, 1.0, 0.05) var half_width := 0.35


func fire(direction: float, _power: float) -> void:
	var session := get_node("/root/OnlineSession")
	if session.is_match_active() and session.host_id != get_node("/root/GDSync").get_client_id():
		return
	var source := get_parent()
	while source != null and not source is PlayerSpider3D:
		source = source.get_parent()
	var origin := global_position
	var forward := Vector2(cos(direction), sin(direction))
	for spider in get_tree().get_nodes_in_group("burnable_spiders"):
		if spider != source and contains_point(origin, forward, spider.global_position, 0.3):
			spider.ignite()
	for web in get_tree().get_nodes_in_group("gameplay_webs"):
		for index in range(web.valid_nodes.size()):
			if contains_point(origin, forward, web.valid_nodes[index].global_position, 0.15):
				web.ignite_node(index)
	present_burst(get_tree().current_scene, origin, direction, reach)
	if session.is_match_active() and is_instance_valid(session.replication):
		session.replication.broadcast_flame(origin, direction, reach)


func contains_point(origin: Vector3, forward: Vector2, point: Vector3, radius: float) -> bool:
	var offset := Vector2(point.x - origin.x, point.y - origin.y)
	var along := offset.dot(forward)
	return along >= 0.2 and along <= reach + radius \
		and absf(offset.cross(forward)) <= half_width + radius


static func present_burst(arena: Node, point: Vector3, direction: float, distance: float) -> void:
	var burst := FlameBurst3D.new()
	arena.add_child(burst)
	burst.configure(point, direction, distance)
