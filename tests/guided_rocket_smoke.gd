extends SceneTree

const ROCKET := preload("res://src/features/collectibles/weapons/guided_rocket_projectile.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var path := "res://src/features/collectibles/weapons/guided_rocket.gd"
	if not ResourceLoader.exists(path):
		push_error("GUIDED ROCKET FAIL: no steerable rocket exists")
		quit(1)
		return
	var script := load(path)
	var point := Vector3(0, 50, 0)
	var velocity := Vector3(12, 8, 0)
	var ballistic: Dictionary = script.sample_flight(point, velocity, 0.0, 1.0)
	assert(ballistic.position.distance_to(Vector3(12, 53.095, 0)) < 0.0001)
	for turn in [-2.5, 2.5]:
		var whole: Dictionary = script.sample_flight(point, velocity, turn, 1.0)
		var stepped := { "position": point, "velocity": velocity }
		for tick in range(144):
			stepped = script.sample_flight(stepped.position, stepped.velocity, turn, 1.0 / 144.0)
		assert(whole.position.distance_to(stepped.position) < 0.001,
			"Steering flight must not depend on frame rate")
		assert(whole.velocity.distance_to(stepped.velocity) < 0.001)
		assert(is_zero_approx(whole.position.z))
	var stage := Node3D.new()
	root.add_child(stage)
	current_scene = stage
	var rocket = ROCKET.instantiate()
	stage.add_child(rocket)
	rocket.set_process(false)
	rocket.global_position = point
	rocket.launch(0.0, 1.0)
	assert(rocket.get_node("Sprite3D").global_basis.y.normalized().dot(
		rocket.velocity.normalized()) > 0.999, "Rocket nose must point along its velocity")
	var player: PlayerSpider3D = load(
		"res://src/features/spiders/player_spider.tscn").instantiate()
	stage.add_child(player)
	player.set_process(false)
	player.is_active = true
	player.remaining_movement = 10.0
	player.n_remaining_actions = 0
	rocket.source_hurtbox = player.hurtbox
	var pilot := PlayerCommand.new()
	pilot.held = 17
	var body_rotation := player.spider_rig.rotation
	player.simulate(0.2, pilot)
	assert(player.spider_rig.rotation == body_rotation, "Piloting must not turn the spider")
	assert(player.position == Vector3.ZERO, "The spider must stay still while piloting")
	assert(rocket.steering == 1, "Spent action must not prevent rocket steering")
	rocket.set_steering(1)
	rocket._process(0.2)
	assert(rocket.velocity.y > 2.0, "Aim-left must turn the rocket counterclockwise")
	rocket._process(8.0)
	assert(rocket.freeze, "Maximum flight duration must detonate the rocket")
	var impacts: Array = []
	rocket.impacted.connect(func(value: Vector3) -> void: impacts.append(value))
	rocket.hit(null)
	assert(impacts.is_empty(), "Timeout must not allow a second explosion")
	var grace_ok := _check_return_collision(stage, player)
	stage.queue_free()
	await process_frame
	await create_timer(0.6).timeout
	if not grace_ok:
		push_error("A returning guided rocket regained launch protection")
		quit(1)
		return
	print("GUIDED ROCKET PASS: gravity, steering, XY, frame-rate independence and timeout")
	quit(0)


func _check_return_collision(stage: Node3D, player: PlayerSpider3D) -> bool:
	var rocket: Projectile3D = ROCKET.instantiate()
	stage.add_child(rocket)
	rocket.set_process(false)
	rocket.source_hurtbox = player.hurtbox
	rocket.global_position = Vector3(0, 100, 0)
	rocket.launch(0.0, 1.0)
	rocket._process(1.0)
	rocket.global_position = Vector3(0.1, 100, 0)
	var anchor := Area3D.new()
	stage.add_child(anchor)
	anchor.add_to_group("web_anchor_hitboxes")
	rocket._hitbox_entered(anchor)
	return rocket.freeze
