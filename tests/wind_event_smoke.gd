extends SceneTree
## Verifies a round's wind group without a turn controller or web collision.

const WIND_EVENT_SCENE: PackedScene = preload("res://src/features/wind/wind_event.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if not (_staggered_group_and_contact() and _empty_group_finishes()
			and _removed_item_does_not_stall() and _preview_includes_starting_webs()):
		quit(1)
		return
	print("WIND EVENT PASS: staggered group, contact handoff, and lifecycle")
	quit(0)


func _staggered_group_and_contact() -> bool:
	var event: WindEvent3D = WIND_EVENT_SCENE.instantiate()
	root.add_child(event)
	event.random_seed = 42
	var started: Array[int] = []
	var finished: Array[int] = []
	var contacts: Array[Vector3] = []
	var contact_errors: Array[String] = []
	event.event_started.connect(func(round_number: int) -> void: started.append(round_number))
	event.event_finished.connect(func(round_number: int) -> void: finished.append(round_number))
	event.item_contact.connect(func(_item: Collectible3D, side: int,
			local_point: Vector2, world_point: Vector3) -> void:
		if side < 0 or side > 1:
			contact_errors.append("Contact side must belong to a player")
		var plane: Node3D = event.get_node("WebPlane")
		var local := plane.to_local(world_point)
		if Vector2(local.x, local.z).distance_to(local_point) > 0.001:
			contact_errors.append("Contact coordinates are inconsistent")
		contacts.append(world_point))
	event.start_round(1)
	event.start_round(1)
	if not event.is_active or started != [1] or event.get_node("Flights").get_child_count() != 1:
		return _fail("One event must start with one item and ignore duplicate starts")
	var first_flight: WindFlight3D = event.get_node("Flights").get_child(0)
	if first_flight.is_processing():
		return _fail("The event must be the only driver of its flights")
	event.advance(0.79)
	if event.get_node("Flights").get_child_count() != 1:
		return _fail("The second item must wait for the stagger interval")
	event.advance(0.02)
	if event.get_node("Flights").get_child_count() != 2:
		return _fail("The second item must arrive after the interval")
	for step in 120:
		event.advance(0.1)
	if contacts.size() != 3 or finished != [1] or event.is_active:
		contact_errors.append("Three items must cross once before the event finishes")
	event.queue_free()
	if not contact_errors.is_empty():
		return _fail(contact_errors[0])
	return true


func _empty_group_finishes() -> bool:
	var event: WindEvent3D = WIND_EVENT_SCENE.instantiate()
	root.add_child(event)
	event.spawn_entries.clear()
	var finished: Array[int] = []
	event.event_finished.connect(func(round_number: int) -> void: finished.append(round_number))
	event.start_round(2)
	if event.is_active or finished != [2]:
		return _fail("An empty catalog must end its wind event immediately")
	event.queue_free()
	return true


func _removed_item_does_not_stall() -> bool:
	var event: WindEvent3D = WIND_EVENT_SCENE.instantiate()
	root.add_child(event)
	event.start_round(3)
	var first_flight: WindFlight3D = event.get_node("Flights").get_child(0)
	first_flight.item.free()
	for step in 120:
		event.advance(0.1)
	if event.is_active:
		return _fail("Removing an item must not stall the wind phase")
	event.queue_free()
	return true


func _preview_includes_starting_webs() -> bool:
	var preview: Node3D = load("res://src/features/wind/wind_preview.tscn").instantiate()
	root.add_child(preview)
	var webs := preview.get_node_or_null("WebMatch/StartingWebs")
	if webs == null or webs.get_child_count() != 10:
		return _fail("The wind preview must show the starting webs")
	preview.queue_free()
	return true


func _fail(message: String) -> bool:
	push_error("WIND EVENT FAIL: " + message)
	return false
