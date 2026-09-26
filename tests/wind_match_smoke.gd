extends SceneTree
## Verifies that players cannot act until each round's wind drop ends.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var match_scene: WebMatch3D = load("res://src/game/web_match.tscn").instantiate()
	var event: WindEvent3D = match_scene.get_node("BranchCanopy/WindEvent")
	var manager: MatchManager = match_scene.get_node("MatchManager")
	var started: Array[int] = []
	event.event_started.connect(func(round_number: int) -> void: started.append(round_number))
	event.group_size = 1
	root.add_child(match_scene)
	await process_frame
	await process_frame
	var failure := _check_initial_round(event, manager, started)
	if failure.is_empty():
		failure = _check_next_round(event, manager, started)
	_stop_audio(match_scene)
	match_scene.free()
	await create_timer(0.5).timeout
	if not failure.is_empty():
		push_error("WIND MATCH FAIL: " + failure)
		quit(1)
		return
	print("WIND MATCH PASS: players wait for each wind drop")
	quit(0)


func _check_initial_round(event: WindEvent3D, manager: MatchManager,
		started: Array[int]) -> String:
	if started != [1] or not event.is_active:
		return "The initial team change must start wind round 1"
	if manager.teams[0].get_active_spider().is_active:
		return "Team A must wait for the initial wind drop"
	_finish_wind(event)
	if event.is_active:
		return "The first wind round must finish before the next team change"
	if not manager.teams[0].get_active_spider().is_active:
		return "Team A must start only after the initial wind drop"
	return ""


func _check_next_round(event: WindEvent3D, manager: MatchManager,
		started: Array[int]) -> String:
	manager.teams[0].active_spider_idx = manager.teams[0].spiders.size()
	manager._process(0.0)
	if started != [1] or not manager.teams[1].get_active_spider().is_active:
		return "Team B must start without another wind drop"
	manager.teams[1].active_spider_idx = manager.teams[1].spiders.size()
	manager._process(0.0)
	if started != [1, 2] or not event.is_active:
		return "Returning to team A must start wind round 2"
	if manager.teams[0].spiders[0].is_active:
		return "Team A must wait for the second wind drop"
	manager._process(0.0)
	if manager.active_team_idx != 0 or manager.teams[1].spiders[0].is_active:
		return "The waiting round must not advance to team B"
	_finish_wind(event)
	if not manager.teams[0].get_active_spider().is_active:
		return "Team A must resume when the second wind drop finishes"
	return ""


func _finish_wind(event: WindEvent3D) -> void:
	event.get_node("Flights").get_child(0).free()
	event.advance(0.0)


func _stop_audio(node: Node) -> void:
	if node is AudioStreamPlayer:
		node.stop()
	for child in node.get_children():
		_stop_audio(child)
