extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var arena: WebMatch3D = load("res://src/game/web_match.tscn").instantiate()
	root.add_child(arena)
	current_scene = arena
	await process_frame
	arena.process_mode = Node.PROCESS_MODE_DISABLED
	var manager: MatchManager = arena.get_node("MatchManager")
	arena.wind_event.skip_to_end()
	if not manager.has_method("check_match_result"):
		_fail("Eliminating a team has no match result")
		return
	var spider := manager.teams[0].spiders[0]
	for team in manager.teams:
		for actor in team.spiders:
			actor.webs.clear()
	var inactive_team := manager.teams[1]
	inactive_team.spiders[0].take_damage(1.0)
	inactive_team.advance(0.0)
	assert(not inactive_team.spiders[1].is_active,
		"A death on the inactive team must not activate its next spider")
	inactive_team.spiders[0].health = 1.0
	spider.call("ignite")
	spider.call("end_turn_effects")
	assert(is_equal_approx(spider.health, 1.0), "A fresh burn ticked before its next turn")
	for tick in range(3):
		spider.call("begin_turn_effects")
		spider.call("end_turn_effects")
	assert(is_equal_approx(spider.health, 0.7), "Burn must do three 10% ticks")
	spider.call("begin_turn_effects")
	spider.call("end_turn_effects")
	assert(is_equal_approx(spider.health, 0.7), "Burn must expire")
	spider.call("ignite")
	spider.call("ignite")
	assert(spider.get("burn_turns") == 3, "Repeated hits must refresh, not stack")
	var insect: Collectible3D = load(
		"res://src/features/collectibles/insects/windborne_insect.tscn").instantiate()
	insect.collectible = load("res://src/features/collectibles/insects/silk_moth.tres")
	arena.add_child(insect)
	spider.pick_up(insect)
	assert(spider.get("burn_turns") == 3, "Silk-only insect must not extinguish fire")
	insect.collectible = load("res://src/features/collectibles/insects/health_beetle.tres")
	spider.pick_up(insect)
	assert(spider.get("burn_turns") == 0, "Healing insect must extinguish fire")
	var web := arena.catch_webs[0]
	var edge := web.edges[0]
	web.call("ignite_node", edge.x)
	web.call("ignite_node", edge.x)
	assert(web.get("burning_nodes")[str(edge.x)] == 3)
	web.call("tick_burning_nodes")
	assert(web.has_edge(edge.x, edge.y), "Burn must not destroy a full-health strand immediately")
	web.call("tick_burning_nodes")
	web.call("tick_burning_nodes")
	assert(not web.has_edge(edge.x, edge.y), "Three node burn ticks must destroy attached strands")
	assert(web.get("burning_nodes").is_empty(), "Anchor burn must expire without spreading")
	var weapon: Weapon3D = load(
		"res://src/features/collectibles/weapons/weapon_flamethrower.tscn").instantiate()
	spider.add_child(weapon)
	spider.pick_up(weapon)
	var codec := MatchState.new()
	var baseline := codec.capture(arena)
	var changed := baseline.duplicate(true)
	changed.actors["0:0"].burn = 3
	changed.webs["0"].burns[str(edge.x)] = 3
	assert(codec.apply(arena, changed), "Burn and flamethrower inventory must survive recovery")
	assert(codec.digest(codec.capture(arena)) == codec.digest(changed))
	var invalid := changed.duplicate(true)
	invalid.webs["0"].burns["99999"] = 3
	assert(not codec.apply(arena, invalid), "Invalid burning node must reject the whole state")
	assert(codec.digest(codec.capture(arena)) == codec.digest(changed))
	invalid = changed.duplicate(true)
	invalid.actors["0:0"].burn = 4
	assert(not codec.apply(arena, invalid), "Invalid burn duration must reject the whole state")
	assert(codec.apply(arena, baseline))
	weapon.global_position = web.valid_nodes[edge.x].global_position - Vector3.RIGHT
	var decorative_web := Web3D.new()
	arena.add_child(decorative_web)
	decorative_web.valid_nodes = web.valid_nodes.duplicate()
	var ally := manager.teams[0].spiders[1]
	var enemy := manager.teams[1].spiders[0]
	ally.global_position = weapon.global_position + Vector3.RIGHT * 2
	enemy.global_position = weapon.global_position + Vector3.RIGHT * 3
	manager.teams[1].spiders[1].global_position = weapon.global_position + Vector3.RIGHT * 7
	manager.teams[1].spiders[2].global_position = weapon.global_position + Vector3.UP * 2
	weapon.fire(0.0, 1.0)
	assert(ally.get("burn_turns") == 3 and enemy.get("burn_turns") == 3,
		"Flames must ignite friends and enemies")
	assert(spider.get("burn_turns") == 0, "Flames must not hit their wielder")
	assert(manager.teams[1].spiders[1].get("burn_turns") == 0, "Flame range must be limited")
	assert(manager.teams[1].spiders[2].get("burn_turns") == 0, "Flame must be narrow")
	assert(web.get("burning_nodes").has(str(edge.x)), "Flames must ignite own web nodes")
	assert(decorative_web.burning_nodes.is_empty(), "Flames must not affect non-gameplay webs")
	for burst in get_nodes_in_group("camera_focus_projectiles"):
		burst.free()
	var pending := Node3D.new()
	pending.add_to_group("camera_focus_projectiles")
	arena.add_child(pending)
	for actor in manager.teams[1].spiders:
		actor.take_damage(1.0)
	manager.call("check_match_result")
	assert(not manager.get("finished"), "Victory must wait for pending attacks")
	pending.free()
	manager.call("check_match_result")
	assert(manager.get("finished") and manager.get("winner_team") == 0)
	var round_before := manager._round_number
	manager.advance(100.0)
	assert(manager._round_number == round_before, "Finished matches must stop advancing")
	assert(arena.get_node("GameOverMenu").visible, "Match result screen must open")
	for actor in manager.teams[0].spiders:
		assert(not actor.is_active)
		assert(not actor.selected_indicator.visible and not actor.aim_arrow.visible,
			"Result must clear selection and aim presentation")
	manager.set("finished", false)
	for actor in manager.teams[0].spiders:
		actor.health = 0
	spider.pick_up(insect)
	assert(spider.is_dead(), "Healing cannot resurrect an eliminated spider")
	manager.call("check_match_result")
	assert(manager.get("winner_team") == -1, "Mutual elimination must draw")
	manager.finished = false
	manager.teams[0].spiders[0].health = 1.0
	manager.waiting_for_wind = true
	arena.wind_event.is_active = true
	manager.advance(0.0)
	assert(manager.finished and manager.winner_team == 0,
		"A decided match must not wait for the wind to end")
	assert(not arena.wind_event.is_active, "Match result must cancel remaining wind drops")
	arena.queue_free()
	await process_frame
	await create_timer(0.2).timeout
	print("MATCH FIRE PASS: elimination, draw, attack barrier, three ticks, refresh and healing")
	quit(0)


func _fail(reason: String) -> void:
	push_error(reason)
	quit(1)
