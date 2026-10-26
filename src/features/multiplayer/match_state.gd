class_name MatchState
extends RefCounted

const PRECISION := 100000.0
const INVENTORY_TYPES := [0, 1, 2, 3]
const ENTRY_PATHS := [
	"res://src/features/wind/entries/pebble.tres",
	"res://src/features/wind/entries/rocket_launcher.tres",
	"res://src/features/wind/entries/silk_moth.tres",
	"res://src/features/wind/entries/twig_cutter.tres",
	"res://src/features/wind/entries/health_beetle.tres",
]

var scenes: Array[PackedScene] = [
	preload("res://src/features/collectibles/weapons/weapon_no_action.tscn"),
	preload("res://src/features/collectibles/weapons/silk_build_action.tscn"),
]
var item_data: Array[CollectibleData] = [null, null]
var _next_item_id := 1


func _init() -> void:
	for path in ENTRY_PATHS:
		var entry := load(path) as WindSpawnEntry
		scenes.append(entry.scene)
		item_data.append(entry.data)


func capture(arena: WebMatch3D) -> Dictionary:
	var manager := arena.get_node("MatchManager") as MatchManager
	var state := {"actors": {}, "teams": {}, "webs": {}, "caught": {}, "turn": {
		"team": manager.active_team_idx, "wind": manager.waiting_for_wind,
		"round": manager._round_number}}
	for team_index in range(manager.teams.size()):
		var team := manager.teams[team_index]
		state.teams[str(team_index)] = team.active_spider_idx
		for spider_index in range(team.spiders.size()):
			var id := "%d:%d" % [team_index, spider_index]
			state.actors[id] = _capture_actor(team.spiders[spider_index])
	for index in range(arena.catch_webs.size()):
		var web := arena.catch_webs[index]
		var edge_values: Array = []
		var health_values: Array = []
		for edge in web.edges:
			edge_values.append([edge.x, edge.y])
		for edge_health in web.edges_health:
			health_values.append(quantize(edge_health))
		state.webs[str(index)] = { "edges": edge_values, "health": health_values }
		_capture_caught(web, index, state.caught)
	return state


func _capture_actor(spider: PlayerSpider3D) -> Dictionary:
	var inventory: Array = []
	for weapon in spider.weapons:
		inventory.append(item_type(weapon))
	return {"position": pack_vector(spider.global_position),
		"health": quantize(maxf(spider.health, 0)),
		"movement": quantize(spider.remaining_movement), "actions": spider.n_remaining_actions,
		"aim": quantize(spider.aim_angle), "silk": spider.silk_amount,
		"selected": spider.selected_weapon_idx, "active": spider.is_active, "inventory": inventory,
		"build": {"source": spider.silk_builder.silk_source_index,
			"targets": spider.silk_builder.silk_target_indices.duplicate(),
			"selected": spider.silk_builder.selected_silk_target_index}}


func _capture_caught(web: Web3D, web_index: int, result: Dictionary) -> void:
	for child in web.get_node("CaughtItems").get_children():
		var caught := child as CaughtCollectible3D
		if caught == null or caught._releasing or caught.is_queued_for_deletion() \
				or not is_instance_valid(caught.item) or caught.item.is_queued_for_deletion() \
				or not caught.item.visible or caught.item.get_parent() != caught:
			continue
		if not caught.has_meta("network_id"):
			caught.set_meta("network_id", str(_next_item_id))
			_next_item_id += 1
		result[caught.get_meta("network_id")] = {"web": web_index, "face": caught.face_key,
			"type": item_type(caught.item), "position": pack_vector(caught.global_position)}


func item_type(item: Collectible3D) -> int:
	for index in range(scenes.size()):
		if scenes[index].resource_path == item.scene_file_path \
				and (item.collectible == null or item_data[index] == item.collectible):
			return index
	return -1


func create_item(type_id: int) -> Collectible3D:
	if type_id < 0 or type_id >= scenes.size():
		return null
	var item := scenes[type_id].instantiate() as Collectible3D
	item.collectible = item_data[type_id]
	return item


func apply(arena: WebMatch3D, state: Dictionary) -> bool:
	if not _valid_state(arena, state):
		return false
	var manager := arena.get_node("MatchManager") as MatchManager
	for index in range(arena.catch_webs.size()):
		var web := arena.catch_webs[index]
		var values: Dictionary = state.webs[str(index)]
		var new_edges: Array[Vector2i] = []
		for edge in values.edges:
			new_edges.append(Vector2i(edge[0], edge[1]))
		if web.edges != new_edges:
			web.edges = new_edges
		web.edges_health.clear()
		for edge_health in values.health:
			web.edges_health.append(float(edge_health) / PRECISION)
	for team_index in range(manager.teams.size()):
		var team := manager.teams[team_index]
		team.active_spider_idx = state.teams[str(team_index)]
		for index in range(team.spiders.size()):
			_apply_actor(team.spiders[index], state.actors["%d:%d" % [team_index, index]])
	_apply_caught(arena, state.caught)
	manager.active_team_idx = state.turn.team
	manager.waiting_for_wind = state.turn.wind
	manager._round_number = state.turn.round
	manager.match_hud.update_team_label(manager.teams[manager.active_team_idx].name)
	manager.match_hud.set_wind_waiting(manager.waiting_for_wind)
	return true


func _apply_actor(spider: PlayerSpider3D, values: Dictionary) -> void:
	if _capture_actor(spider).inventory != values.inventory:
		for index in range(spider.weapons.size() - 1, 1, -1):
			spider.weapons[index].queue_free()
			spider.weapons.remove_at(index)
		for index in range(2, values.inventory.size()):
			var weapon := create_item(values.inventory[index]) as Weapon3D
			spider.add_child(weapon)
			spider.weapons.append(weapon)
			spider._attach_weapon(weapon)
	spider.global_position = unpack_vector(values.position)
	spider.health = float(values.health) / PRECISION
	spider.visible = spider.health > 0
	spider.hurtbox.set_deferred("monitorable", spider.health > 0)
	spider.hurtbox.set_deferred("monitoring", spider.health > 0)
	spider.remaining_movement = float(values.movement) / PRECISION
	spider.n_remaining_actions = values.actions
	spider.aim_angle = float(values.aim) / PRECISION
	spider.silk_amount = values.silk
	spider.is_active = values.active
	spider.select_weapon(values.selected)
	var builder := spider.silk_builder
	builder.silk_source_index = values.build.source
	builder.silk_source_web = builder.owned_web if values.build.source >= 0 else null
	builder.silk_target_indices.assign(values.build.targets)
	builder.selected_silk_target_index = values.build.selected
	spider._update_weapon_pose()


func _apply_caught(arena: WebMatch3D, values: Dictionary) -> void:
	var existing := {}
	for web in arena.catch_webs:
		for caught in web.get_node("CaughtItems").get_children():
			var id: String = caught.get_meta("network_id", "")
			if not id.is_empty() and values.has(id):
				existing[id] = caught
			else:
				caught.free()
	for id in values:
		var description: Dictionary = values[id]
		if existing.has(id):
			var caught := existing[id] as CaughtCollectible3D
			if not caught._releasing and caught.web == arena.catch_webs[description.web] \
					and caught.face_key == description.face \
					and item_type(caught.item) == description.type:
				caught.global_position = unpack_vector(description.position)
				continue
			caught.free()
		_create_caught(arena, id, description)


func _create_caught(arena: WebMatch3D, id: String, description: Dictionary) -> void:
	if id.is_valid_int():
		_next_item_id = maxi(_next_item_id, id.to_int() + 1)
	var web := arena.catch_webs[description.web]
	var caught := CaughtCollectible3D.new()
	caught.set_meta("network_id", id)
	web.get_node("CaughtItems").add_child(caught)
	caught.global_position = unpack_vector(description.position)
	var item := arena.wind_event.claim_named_item(id, caught)
	if item == null:
		item = create_item(description.type)
		caught.add_child(item)
	item.position = Vector3.ZERO
	caught.configure(web, description.face, item)
	if item.pickup_area:
		item.pickup_area.set_deferred("monitoring", false)


func _valid_state(arena: WebMatch3D, state: Dictionary) -> bool:
	for section in ["actors", "teams", "webs", "caught", "turn"]:
		if not state.get(section) is Dictionary:
			return false
	var manager := arena.get_node("MatchManager") as MatchManager
	if state.teams.size() != manager.teams.size() or state.webs.size() != arena.catch_webs.size() \
			or state.caught.size() > 256:
		return false
	return _valid_actors(manager, state) and _valid_webs(arena, state.webs) \
		and _valid_caught(arena, state.caught) and _valid_turn(manager, state.turn)


func _valid_actors(manager: MatchManager, state: Dictionary) -> bool:
	var count := 0
	for team_index in range(manager.teams.size()):
		var team := manager.teams[team_index]
		if not _bounded_int(state.teams.get(str(team_index)), 0, team.spiders.size()):
			return false
		for index in range(team.spiders.size()):
			count += 1
			var values: Variant = state.actors.get("%d:%d" % [team_index, index])
			if not values is Dictionary or not _valid_actor(values) \
					or not _valid_build(values.get("build"), team.home_web):
				return false
	return count == state.actors.size()


func _valid_build(value: Variant, web: Web3D) -> bool:
	if not value is Dictionary or web == null:
		return false
	var limit := web.valid_nodes.size() - 1
	if not _bounded_int(value.get("source"), -1, limit) \
			or not value.get("targets") is Array or value.targets.size() > limit + 1 \
			or not _bounded_int(value.get("selected"), 0, maxi(0, value.targets.size() - 1)):
		return false
	if (value.source == -1) != value.targets.is_empty():
		return false
	var seen: Dictionary = {}
	for target in value.targets:
		if not _bounded_int(target, 0, limit) or target == value.source or seen.has(target):
			return false
		seen[target] = true
	return true


func _valid_actor(values: Dictionary) -> bool:
	if not _valid_vector(values.get("position")) or not values.get("active") is bool \
			or not values.get("inventory") is Array:
		return false
	var inventory: Array = values.inventory
	if inventory.size() < 2 or inventory.size() > 64 or inventory[0] != 0 or inventory[1] != 1:
		return false
	for type_id in inventory:
		if not type_id is int or type_id not in INVENTORY_TYPES:
			return false
	for key in ["health", "movement", "actions", "silk", "selected"]:
		if not _bounded_int(values.get(key), 0, 100_000_000):
			return false
	return values.health <= int(PRECISION) and values.silk <= PlayerSpider3D.SILK_CAPACITY \
		and values.selected < inventory.size() and values.actions <= 10 \
		and _bounded_int(values.get("aim"), -1_000_000_000, 1_000_000_000)


func _valid_webs(arena: WebMatch3D, values: Dictionary) -> bool:
	for index in range(arena.catch_webs.size()):
		var value: Variant = values.get(str(index))
		if not value is Dictionary or not value.get("edges") is Array \
				or not value.get("health") is Array or value.edges.size() != value.health.size() \
				or value.edges.size() > 1024:
			return false
		for edge_index in range(value.edges.size()):
			var edge: Variant = value.edges[edge_index]
			var node_limit := arena.catch_webs[index].valid_nodes.size() - 1
			if not edge is Array or edge.size() != 2 \
					or not _bounded_int(
						edge[0],
						0,
						node_limit,
					) or not _bounded_int(edge[1], 0, node_limit) \
					or not _bounded_int(value.health[edge_index], 0, 10_000_000):
				return false
	return true


func _valid_caught(arena: WebMatch3D, values: Dictionary) -> bool:
	for id in values:
		var value: Variant = values[id]
		if not id is String or id.is_empty() or id.length() > 48 or not value is Dictionary:
			return false
		if not _valid_vector(value.get("position")) \
				or not _bounded_int(value.get("type"), 2, scenes.size() - 1) \
				or not _bounded_int(value.get("web"), 0, arena.catch_webs.size() - 1) \
				or not value.get("face") is String or value.face.length() > 128:
			return false
	return true


func _valid_turn(manager: MatchManager, values: Dictionary) -> bool:
	return _bounded_int(values.get("team"), 0, manager.teams.size() - 1) \
		and _bounded_int(values.get("round"), 0, 1_000_000) and values.get("wind") is bool


static func quantize(value: float) -> int:
	return roundi(value * PRECISION)


static func pack_vector(value: Vector3) -> Array:
	return [quantize(value.x), quantize(value.y), quantize(value.z)]


static func unpack_vector(value: Array) -> Vector3:
	return Vector3(value[0], value[1], value[2]) / PRECISION


static func _bounded_int(value: Variant, minimum: int, maximum: int) -> bool:
	return value is int and value >= minimum and value <= maximum


static func _valid_vector(value: Variant) -> bool:
	return value is Array and value.size() == 3 \
		and _bounded_int(value[0], -100_000_000, 100_000_000) \
		and _bounded_int(value[1], -100_000_000, 100_000_000) \
		and _bounded_int(value[2], -100_000_000, 100_000_000)


static func digest(state: Dictionary) -> String:
	return JSON.stringify(state, "", true).sha256_text()


static func diff(previous: Dictionary, current: Dictionary) -> Dictionary:
	var changes := {}
	for section in current:
		var entries := {}
		for key in current[section]:
			if previous[section].get(key) != current[section][key]:
				entries[key] = current[section][key]
		for key in previous[section]:
			if not current[section].has(key):
				entries[key] = null
		if not entries.is_empty():
			changes[section] = entries
	return changes


static func merge(previous: Dictionary, changes: Dictionary) -> Dictionary:
	var result := previous.duplicate(true)
	for section in changes:
		if not result.has(section) or not changes[section] is Dictionary:
			return {}
		for key in changes[section]:
			if changes[section][key] == null:
				result[section].erase(key)
			else:
				result[section][key] = changes[section][key]
	return result
