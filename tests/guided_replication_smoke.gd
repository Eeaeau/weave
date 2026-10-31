extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var host_world := Node3D.new()
	var guest_world := Node3D.new()
	root.add_child(host_world)
	root.add_child(guest_world)
	current_scene = host_world
	var script := load("res://src/features/multiplayer/projectile_replication.gd")
	var host = script.new()
	var guest = script.new()
	host_world.add_child(host)
	guest_world.add_child(guest)
	var clock := [1.0]
	host.setup(host_world, true, func() -> float: return clock[0])
	guest.setup(guest_world, false, func() -> float: return clock[0])
	var messages: Array[Dictionary] = []
	host.event_ready.connect(func(value: Dictionary) -> void:
		messages.append(value.duplicate(true)))
	var rocket = load(
		"res://src/features/collectibles/weapons/guided_rocket_projectile.tscn").instantiate()
	host_world.add_child(rocket)
	rocket.global_position = Vector3(0, 50, 0)
	rocket.launch(0.0, 1.0)
	host.register(rocket)
	if messages.size() != 1:
		push_error("GUIDED REPLICATION FAIL: guided launch is not registered")
		quit(1)
		return
	guest.receive(messages[0])
	rocket.set_steering(1)
	assert(messages.size() == 2 and messages[1].action == "steer")
	var steering_event := messages[1].duplicate(true)
	rocket.set_steering(1)
	assert(messages.size() == 2, "Held steering must not stream packets each frame")
	guest.receive(steering_event)
	rocket._process(0.2)
	clock[0] += 0.2
	guest.present()
	var replica: Projectile3D = guest_world.get_node("GuidedRocket")
	assert(replica.global_position.distance_to(rocket.global_position) < 0.001)
	var saved: Array = host.capture()
	assert(guest.restore(saved), "Recovery must preserve an in-flight steering segment")
	replica = guest_world.get_node("GuidedRocket")
	assert(replica.global_position.distance_to(rocket.global_position) < 0.001)
	var bad := steering_event.duplicate(true)
	bad.steer = 2
	bad.steer_revision += 1
	guest.receive(bad)
	assert(guest.capture()[0].steer == 1)
	bad = steering_event.duplicate(true)
	bad.steer_revision = 0
	bad.steer = -1
	guest.receive(bad)
	assert(guest.capture()[0].steer == 1, "Old steering must not rewind flight")
	rocket.hit(null)
	guest.receive(messages.back())
	guest.receive(steering_event)
	assert(replica.freeze, "Steering after impact must not restart the rocket")
	host_world.queue_free()
	guest_world.queue_free()
	await process_frame
	await create_timer(0.6).timeout
	print("GUIDED REPLICATION PASS: changed-only steering, analytic flight and recovery")
	quit(0)
