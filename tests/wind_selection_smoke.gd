extends SceneTree
## Checks wind side balance and the round-gated collectible catalog.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if not (_balanced_side_bag() and _round_unlocks() and _invalid_entries()):
		quit(1)
		return
	print("WIND SELECTION PASS: balanced sides and round-gated items")
	quit(0)


func _balanced_side_bag() -> bool:
	var selection := WindSelection.new()
	selection.reset(42)
	var first: Array[int] = []
	for index in 6:
		first.append(selection.next_side())
	if first.count(0) != 3 or first.count(1) != 3:
		return _fail("Six spawns must offer three chances to each side")
	selection.reset(42)
	for side in first:
		if selection.next_side() != side:
			return _fail("A fixed seed must reproduce the side order")
	return true


func _round_unlocks() -> bool:
	var pebble: WindSpawnEntry = load("res://src/features/wind/entries/pebble.tres")
	var moth: WindSpawnEntry = load("res://src/features/wind/entries/silk_moth.tres")
	var cutter: WindSpawnEntry = load("res://src/features/wind/entries/twig_cutter.tres")
	var beetle: WindSpawnEntry = load("res://src/features/wind/entries/health_beetle.tres")
	if pebble == null or moth == null or cutter == null or beetle == null:
		return _fail("The four initial wind entries must load")
	if pebble.weight_at(1) != 10.0 or moth.weight_at(1) != 10.0:
		return _fail("The two common entries must be available in round one")
	if cutter.weight_at(2) != 0.0 or cutter.weight_at(3) != 1.0:
		return _fail("Twig Cutter must unlock in round three")
	if beetle.weight_at(4) != 0.0 or beetle.weight_at(5) != 1.0:
		return _fail("Health Beetle must unlock in round five")
	if cutter.weight_at(4) <= cutter.weight_at(3) or beetle.weight_at(6) <= beetle.weight_at(5):
		return _fail("Later entries must gain selection weight")
	return true


func _invalid_entries() -> bool:
	var selection := WindSelection.new()
	selection.reset(7)
	if selection.choose_entry(1, []) != null:
		return _fail("An empty catalog must select nothing")
	var unavailable := WindSpawnEntry.new()
	unavailable.scene = load("res://src/features/collectibles/weapons/windborne_weapon.tscn")
	unavailable.data = load("res://src/features/collectibles/weapons/pebble.tres")
	unavailable.earliest_round = 5
	if selection.choose_entry(1, [unavailable]) != null:
		return _fail("A locked entry must not be selected")
	var missing_scene := WindSpawnEntry.new()
	missing_scene.data = unavailable.data
	missing_scene.base_weight = 10.0
	if selection.choose_entry(1, [missing_scene]) != null:
		return _fail("An entry without a scene must be ignored")
	return true


func _fail(message: String) -> bool:
	push_error("WIND SELECTION FAIL: " + message)
	return false
