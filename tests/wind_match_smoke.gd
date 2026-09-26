extends SceneTree
## Verifies that team changes trigger one wind event at each round boundary.


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
	var failure := ""
	if started != [1] or not event.is_active:
		failure = "The initial 0 -> 0 team change must start wind round 1"
	else:
		event.get_node("Flights").get_child(0).free()
		event.advance(0.0)
		if event.is_active:
			failure = "The first wind round must finish before the next team change"
		else:
			manager.give_turn_to(1)
			if started != [1]:
				failure = "Changing to team 1 must not start another wind round"
			else:
				manager.give_turn_to(0)
				if started != [1, 2] or not event.is_active:
					failure = "Returning to team 0 must start wind round 2"
	_stop_audio(match_scene)
	match_scene.free()
	await create_timer(0.2).timeout
	if not failure.is_empty():
		push_error("WIND MATCH FAIL: " + failure)
		quit(1)
		return
	print("WIND MATCH PASS: team 0 starts each wind round")
	quit(0)


func _stop_audio(node: Node) -> void:
	if node is AudioStreamPlayer:
		node.stop()
	for child in node.get_children():
		_stop_audio(child)
