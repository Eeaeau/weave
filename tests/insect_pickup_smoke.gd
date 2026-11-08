extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	current_scene = stage
	var scene := load("res://src/features/spiders/player_spider.tscn") as PackedScene
	var inactive := scene.instantiate() as PlayerSpider3D
	stage.add_child(inactive)
	inactive.set_process(false)
	inactive.silk_amount = 0
	var active := scene.instantiate() as PlayerSpider3D
	stage.add_child(active)
	active.set_process(false)
	active.is_active = true
	active.silk_amount = 0
	active.position = Vector3(10, 0, 0)
	var moth_scene := load("res://src/features/wind/entries/silk_moth.tres") as WindSpawnEntry
	var moth := moth_scene.scene.instantiate() as Collectible3D
	moth.collectible = moth_scene.data
	stage.add_child(moth)
	await physics_frame
	await physics_frame
	await physics_frame
	if inactive.silk_amount != 0 or not is_instance_valid(moth):
		_fail("An inactive spider consumed the moth before the active spider could reach it")
		return
	inactive.is_active = true
	active.is_active = false
	await physics_frame
	await physics_frame
	await physics_frame
	if inactive.silk_amount != 1 or is_instance_valid(moth):
		_fail("A spider starting its turn beside a moth did not receive exactly one silk")
		return
	inactive.is_active = false
	active.is_active = true
	var second_moth := moth_scene.scene.instantiate() as Collectible3D
	second_moth.collectible = moth_scene.data
	second_moth.position = active.position
	stage.add_child(second_moth)
	await physics_frame
	await physics_frame
	await physics_frame
	if active.silk_amount != 1 or is_instance_valid(second_moth):
		_fail("Eating a silk moth did not give exactly one silk to the active spider")
		return
	var health_entry := load("res://src/features/wind/entries/health_beetle.tres") as WindSpawnEntry
	var health_item := health_entry.scene.instantiate() as Collectible3D
	health_item.collectible = health_entry.data
	health_item.position = Vector3(20, 0, 0)
	stage.add_child(health_item)
	if not health_item.has_node("BenefitLabel"):
		_fail("Healing insects are visually indistinguishable from silk moths")
		return
	var label := health_item.get_node("BenefitLabel") as Label3D
	if not label.text.to_lower().contains("healing"):
		_fail("Healing insect label does not explain its benefit")
		return
	stage.queue_free()
	await process_frame
	await create_timer(0.2).timeout
	print("INSECT PICKUP PASS: active-spider pickup, silk reward and visible insect benefit")
	quit(0)


func _fail(reason: String) -> void:
	push_error("INSECT PICKUP FAIL: " + reason)
	quit(1)
