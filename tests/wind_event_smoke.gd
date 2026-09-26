extends SceneTree
## Verifies a round's wind group without a turn controller or web collision.

const WIND_EVENT_SCENE: PackedScene = preload("res://src/features/wind/wind_event.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if not (_staggered_group_and_contact() and _empty_group_finishes()
			and _removed_item_does_not_stall() and _preview_includes_starting_webs()
			and _audio_layers_work() and _removed_flight_does_not_stall()
			and _invalid_scene_is_skipped()):
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
	event.free()
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
	event.free()
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
	event.free()
	return true


func _removed_flight_does_not_stall() -> bool:
	var event: WindEvent3D = WIND_EVENT_SCENE.instantiate()
	root.add_child(event)
	event.start_round(1)
	event.get_node("Flights").get_child(0).free()
	for step in 120:
		event.advance(0.1)
	var completed := not event.is_active
	event.free()
	if not completed:
		return _fail("Removing a flight must release the wind phase")
	return true


func _invalid_scene_is_skipped() -> bool:
	var bad_root := Node3D.new()
	var bad_scene := PackedScene.new()
	bad_scene.pack(bad_root)
	bad_root.free()
	var bad_entry := WindSpawnEntry.new()
	bad_entry.scene = bad_scene
	bad_entry.data = preload("res://src/features/collectibles/weapons/pebble.tres")
	bad_entry.base_weight = 100.0
	var event: WindEvent3D = WIND_EVENT_SCENE.instantiate()
	root.add_child(event)
	event.random_seed = 42
	event.spawn_entries.assign([bad_entry, event.spawn_entries[0]])
	event.start_round(1)
	event.advance(2.0)
	var spawned := event.get_node("Flights").get_child_count()
	event.free()
	if spawned != 3:
		return _fail("Invalid entries must not consume a group spawn")
	return true


func _preview_includes_starting_webs() -> bool:
	var preview: Node3D = load("res://src/features/wind/wind_preview.tscn").instantiate()
	root.add_child(preview)
	var webs := preview.get_node_or_null("WebMatch/StartingWebs")
	if webs == null or webs.get_child_count() != 10:
		return _fail("The wind preview must show the starting webs")
	preview.free()
	return true


func _audio_layers_work() -> bool:
	var map_scene: PackedScene = load(
			"res://src/features/world/maps/branch_canopy/branch_canopy.tscn")
	var map: Node3D = map_scene.instantiate()
	root.add_child(map)
	var ambience: Node = map.get_node_or_null("CanopyAmbience")
	var event: WindEvent3D = map.get_node("WindEvent")
	if ambience == null or event.get_node_or_null("Gust") == null:
		return _fail("Map ambience and event gust players must exist")
	var ambience_ok := _check_ambience(ambience)
	var gust_ok := _check_gust(event)
	map.free()
	return ambience_ok and gust_ok and _check_missing_gust()


func _check_ambience(ambience: Node) -> bool:
	if not ambience.has_method("advance"):
		return _fail("Ambience must support deterministic stepping")
	for name in ["ForestA", "ForestB", "SoftWind"]:
		if ambience.get_node(name).bus != &"SFX":
			return _fail("Ambience players must use the SFX bus")
	if not ambience.get_node("ForestA").playing:
		return _fail("Forest ambience must begin with the map")
	if not _check_soft_wind(ambience.get_node("SoftWind")):
		return false
	var loop_length: float = ambience.get_node("ForestA").stream.get_length()
	ambience.advance(loop_length - ambience.crossfade_seconds + 0.1)
	if not ambience.get_node("ForestB").playing:
		return _fail("Forest tracks must alternate at loop boundary")
	return true


func _check_soft_wind(soft_wind: SoftWindLayer) -> bool:
	var first_interval: float = soft_wind.sample_interval()
	var second_interval: float = soft_wind.sample_interval()
	if is_equal_approx(first_interval, second_interval):
		return _fail("Soft wind intervals must vary")
	soft_wind.trigger()
	var starting_level: float = soft_wind.volume_db
	soft_wind.advance(soft_wind.fade_seconds)
	if not soft_wind.playing or soft_wind.volume_db <= starting_level:
		return _fail("Soft wind must fade in")
	soft_wind.advance(soft_wind.stream.get_length())
	if soft_wind.playing:
		return _fail("Soft wind must fade out and stop")
	return true


func _check_gust(event: WindEvent3D) -> bool:
	if event.get_node("Gust").bus != &"SFX":
		return _fail("Wind gust must use the SFX bus")
	event.start_round(1)
	if not event.get_node("Gust").playing:
		return _fail("One gust must start with the group")
	for step in 120:
		event.advance(0.1)
	event.advance(2.0)
	if event.get_node("Gust").playing:
		return _fail("Gust must fade when the event ends")
	return true


func _check_missing_gust() -> bool:
	var silent_event: WindEvent3D = WIND_EVENT_SCENE.instantiate()
	root.add_child(silent_event)
	silent_event.get_node("Gust").stream = null
	silent_event.start_round(2)
	for step in 120:
		silent_event.advance(0.1)
	if silent_event.is_active:
		return _fail("A missing gust stream must not stall the event")
	silent_event.free()
	return true


func _fail(message: String) -> bool:
	push_error("WIND EVENT FAIL: " + message)
	return false
