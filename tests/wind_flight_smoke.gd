extends SceneTree
## Exercises one sprite flight and its single web-plane contact handoff.

const WEAPON_SCENE: PackedScene = preload(
	"res://src/features/collectibles/weapons/windborne_weapon.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if not (_crosses_transformed_plane_once() and _finishes_when_item_is_removed()
			and _turbulence_is_visible_and_preserves_contact()):
		quit(1)
		return
	print("WIND FLIGHT PASS: curved flight and single plane contact")
	quit(0)


func _crosses_transformed_plane_once() -> bool:
	var plane := Node3D.new()
	plane.position = Vector3(2.0, 0.1, 1.0)
	plane.rotation.y = PI / 6.0
	root.add_child(plane)
	var local_contact := Vector3(-1.25, 0.0, 0.6)
	var world_contact := plane.to_global(local_contact)
	var start := world_contact + Vector3(-0.6, 3.0, -8.0)
	var exit_point := world_contact + Vector3(0.3, -2.0, 6.0)
	var flight := WindFlight3D.new()
	root.add_child(flight)
	var item: Collectible3D = WEAPON_SCENE.instantiate()
	var contacts: Array[Vector3] = []
	var finishes: Array[int] = []
	flight.plane_crossed.connect(func(_item: Collectible3D, point: Vector3) -> void:
		contacts.append(point))
	flight.finished.connect(func() -> void: finishes.append(1))
	flight.configure(item, PackedVector3Array([start, world_contact, exit_point]), 8.0, 0.4)
	var initial_x := flight.global_position.x
	for step in 80:
		flight.advance(0.1)
		if step == 19 and is_equal_approx(flight.global_position.x, initial_x):
			return _fail("A windblown item should drift laterally")
	if contacts.size() != 1 or finishes.size() != 1:
		return _fail("Each item must report one contact and one finish")
	if plane.to_local(contacts[0]).distance_to(local_contact) > 0.001:
		return _fail("Contact coordinates must honor the transformed map plane")
	if flight.global_position.z <= start.z:
		return _fail("The item must travel from background toward foreground")
	flight.advance(1.0)
	if contacts.size() != 1 or finishes.size() != 1:
		return _fail("Finished flights must not repeat signals")
	flight.queue_free()
	plane.queue_free()
	return true


func _finishes_when_item_is_removed() -> bool:
	var flight := WindFlight3D.new()
	root.add_child(flight)
	var item: Collectible3D = load(
		"res://src/features/collectibles/insects/windborne_insect.tscn").instantiate()
	var finishes: Array[int] = []
	flight.finished.connect(func() -> void: finishes.append(1))
	flight.configure(item, PackedVector3Array([
		Vector3(0, 3, -8), Vector3.ZERO, Vector3(0, -2, 6)]), 8.0, 0.3)
	item.free()
	flight.advance(0.1)
	flight.advance(8.0)
	if finishes.size() != 1:
		return _fail("Removing an item must finish its flight once")
	flight.queue_free()
	return true


func _turbulence_is_visible_and_preserves_contact() -> bool:
	var flight := WindFlight3D.new()
	root.add_child(flight)
	var item: Collectible3D = WEAPON_SCENE.instantiate()
	var start := Vector3(0, 3, -8)
	var contact := Vector3.ZERO
	var exit_point := Vector3(0, -2, 6)
	flight.configure(item, PackedVector3Array([start, contact, exit_point]), 8.0, 0.8)
	var largest_lateral_drift := 0.0
	for index in range(1, 50):
		var progress := WindFlight3D.CONTACT_FRACTION * float(index) / 50.0
		var position := flight._position_at(progress)
		largest_lateral_drift = maxf(largest_lateral_drift, absf(position.x))
		if not position.is_equal_approx(flight._position_at(progress)):
			return _fail("Turbulence must remain repeatable for a sampled flight")
	var contact_position := flight._position_at(WindFlight3D.CONTACT_FRACTION)
	flight.queue_free()
	if largest_lateral_drift < 0.75:
		return _fail("Wind turbulence should create visible lateral movement")
	if not contact_position.is_equal_approx(contact):
		return _fail("Turbulence must preserve the exact web-plane crossing")
	return true


func _fail(message: String) -> bool:
	push_error("WIND FLIGHT FAIL: " + message)
	return false
