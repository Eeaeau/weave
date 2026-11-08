extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var arena: WebMatch3D = load("res://src/game/web_match.tscn").instantiate()
	root.add_child(arena)
	current_scene = arena
	await process_frame
	arena.process_mode = Node.PROCESS_MODE_DISABLED
	var player: PlayerSpider3D = arena.get_node("TeamA").spiders[0]
	var weapon: Weapon3D = load(
		"res://src/features/collectibles/weapons/weapon_rocket_launcher.tscn").instantiate()
	player.add_child(weapon)
	player.pick_up(weapon)
	await process_frame
	player.select_weapon(2)
	player.is_active = true
	player.update_presentation()
	var carry := player.get_node("SpiderRig/WeaponCarry")
	var gait: SpiderLegController3D = player.get_node("SpiderRig/LegController")
	_advance(player, gait, 40)
	var passed := _check_initial(carry, gait, weapon)
	if passed:
		passed = _check_handoffs(player, gait, carry, weapon)
	if passed:
		passed = _check_rotation(player, gait, carry, weapon)
	if passed:
		passed = await _check_other_weapons(player, gait, carry)
	player.select_weapon(0)
	_advance(player, gait, 40)
	for index in range(8):
		if gait.is_carried(index):
			passed = _fail("Unequipping a weapon left a leg reserved")
	arena.queue_free()
	await process_frame
	await create_timer(0.2).timeout
	if not passed:
		quit(1)
		return
	print("WEAPON CARRY PASS: grips, quarter-turn handoffs, body turning and released walking feet")
	quit(0)


func _check_initial(carry: Node, gait: SpiderLegController3D, weapon: Weapon3D) -> bool:
	var hands: Array = carry.get_holding_feet()
	if hands.size() != 2 or not _middle_only(hands):
		return _fail("A launcher must be held by two middle limbs")
	return _check_grips(carry, gait, weapon)


func _check_handoffs(player: PlayerSpider3D, gait: SpiderLegController3D,
		carry: Node, weapon: Weapon3D) -> bool:
	var original: Array = carry.get_holding_feet().duplicate()
	player.aim_angle = 1.3
	_advance(player, gait, 20)
	if carry.get_holding_feet() != original:
		return _fail("Carrier limbs switched before90degrees")
	player.aim_angle = 1.7
	_advance(player, gait, 1)
	var retained := false
	for hand in carry.get_holding_feet():
		retained = retained or original.has(hand)
	if not retained:
		return _fail("A handoff must keep a hand attached")
	_advance(player, gait, 40)
	if carry.get_holding_feet() == original or not _check_grips(carry, gait, weapon):
		return _fail("Passing90degrees did not complete a new grip")
	var switched: Array = carry.get_holding_feet().duplicate()
	player.aim_angle = 1.55
	_advance(player, gait, 20)
	if carry.get_holding_feet() != switched:
		return _fail("A small reversal around90degrees caused handoff chatter")
	return _check_reverse(player, gait, carry, original)


func _check_reverse(player: PlayerSpider3D, gait: SpiderLegController3D,
		carry: Node, original: Array) -> bool:
	player.aim_angle = -0.2
	_advance(player, gait, 40)
	if carry.get_holding_feet() != original:
		return _fail("Reversing the aim did not hand the launcher back")
	player.aim_angle = TAU - 0.1
	_advance(player, gait, 20)
	if carry.get_holding_feet() != original:
		return _fail("Crossing the angle wrap triggered an unnecessary handoff")
	return true


func _check_rotation(player: PlayerSpider3D, gait: SpiderLegController3D,
		carry: Node, weapon: Weapon3D) -> bool:
	var pairs: Dictionary = {}
	for frame in range(180):
		player.aim_angle += 0.05
		_advance(player, gait, 1)
		var hands: Array = carry.get_holding_feet()
		if hands.is_empty() or not _middle_only(hands):
			return _fail("Continuous aim lost its holding hand or reserved a walking limb")
		if hands.size() == 2:
			if not _check_grips(carry, gait, weapon) or not _uncrossed(carry, gait, weapon):
				return _fail("Continuous aim crossed or detached settled carrying limbs")
			pairs[str(hands)] = true
	if pairs.size() < 4:
		return _fail("A full rotation did not rotate through all middle-limb pairs")
	player.select_weapon(0)
	_advance(player, gait, 1)
	player.select_weapon(2)
	_advance(player, gait, 40)
	var original: Array = carry.get_holding_feet().duplicate()
	var aim := player.aim_angle
	player.spider_rig.rotation.y += 1.7
	_advance(player, gait, 40)
	if carry.get_holding_feet() == original or not is_equal_approx(player.aim_angle, aim):
		return _fail("Body turning must hand off without changing world aim")
	return _check_grips(carry, gait, weapon)


func _check_other_weapons(player: PlayerSpider3D, gait: SpiderLegController3D,
		carry: Node) -> bool:
	var guided: Weapon3D = load(
		"res://src/features/collectibles/weapons/weapon_guided_launcher.tscn").instantiate()
	player.add_child(guided)
	player.pick_up(guided)
	await process_frame
	player.select_weapon(player.weapons.size() - 1)
	_advance(player, gait, 40)
	if not _check_initial(carry, gait, guided):
		return false
	var pebble: Weapon3D = load(
		"res://src/features/collectibles/weapons/weapon_throw_pebble.tscn").instantiate()
	player.add_child(pebble)
	player.pick_up(pebble)
	await process_frame
	player.select_weapon(player.weapons.size() - 1)
	_advance(player, gait, 40)
	var hands: Array = carry.get_holding_feet()
	if hands.size() != 1 or hands[0] not in [0, 1]:
		return _fail("A one-grip item must use a front limb")
	var start_angle := player.aim_angle
	for direction in [-1.0, 1.0]:
		player.select_weapon(0)
		_advance(player, gait, 1)
		player.aim_angle = start_angle
		player.select_weapon(player.weapons.size() - 1)
		_advance(player, gait, 40)
		player.aim_angle += direction * 1.7
		_advance(player, gait, 40)
		var holder: int = carry.get_holding_feet()[0]
		var grip := pebble.rear_grip.global_position
		if (gait.get_leg_origin(holder).distance_squared_to(grip)
				> gait.get_leg_origin(1 - holder).distance_squared_to(grip) + 0.001):
			return _fail("A one-grip item switched to the farther front limb")
	return _check_grips(carry, gait, pebble)


func _advance(player: PlayerSpider3D, gait: SpiderLegController3D, frames: int) -> void:
	for frame in range(frames):
		player.update_presentation()
		gait.advance(1.0 / 60.0)


func _middle_only(hands: Array) -> bool:
	for hand in hands:
		if hand not in [2, 3, 4, 5]:
			return false
	return true


func _check_grips(carry: Node, gait: SpiderLegController3D, weapon: Weapon3D) -> bool:
	var count := 1 if weapon.front_grip == null else 2
	for slot in range(count):
		var foot: int = carry.get_grip_foot(slot)
		var target: Node3D = weapon.rear_grip if slot == 0 else weapon.front_grip
		var marker: Node3D = gait.get_parent().get_node("FootTargets/" + gait.FOOT_NAMES[foot])
		if marker.global_position.distance_to(target.global_position) > 0.04:
			return _fail("A carrying foot did not reach its authored weapon grip")
	return true


func _fail(message: String) -> bool:
	push_error("WEAPON CARRY FAIL: " + message)
	return false


func _uncrossed(carry: Node, gait: SpiderLegController3D, weapon: Weapon3D) -> bool:
	var first := gait.get_leg_origin(carry.get_grip_foot(0))
	var second := gait.get_leg_origin(carry.get_grip_foot(1))
	var rear := weapon.rear_grip.global_position
	var front := weapon.front_grip.global_position
	return Geometry2D.segment_intersects_segment(Vector2(first.x, first.y), Vector2(rear.x, rear.y),
		Vector2(second.x, second.y), Vector2(front.x, front.y)) == null
