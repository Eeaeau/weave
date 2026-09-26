class_name WindSelection
extends RefCounted
## Seedable item choice and a six-entry bag of balanced player sides.

var _random := RandomNumberGenerator.new()
var _remaining_sides: Array[int] = []


func reset(selection_seed: int) -> void:
	_random.seed = selection_seed
	_remaining_sides.clear()


func next_side() -> int:
	if _remaining_sides.is_empty():
		_remaining_sides.assign([0, 0, 0, 1, 1, 1])
		for index in range(_remaining_sides.size() - 1, 0, -1):
			var other := _random.randi_range(0, index)
			var previous := _remaining_sides[index]
			_remaining_sides[index] = _remaining_sides[other]
			_remaining_sides[other] = previous
	return _remaining_sides.pop_back()


func choose_entry(round_number: int, entries: Array[WindSpawnEntry]) -> WindSpawnEntry:
	var eligible: Array[WindSpawnEntry] = []
	var total_weight := 0.0
	for entry in entries:
		if entry == null or entry.scene == null or entry.data == null:
			continue
		var weight := entry.weight_at(round_number)
		if weight <= 0.0:
			continue
		var instance := entry.scene.instantiate()
		var valid := instance is Collectible3D
		if instance != null:
			instance.free()
		if not valid:
			push_warning("Wind entry scene must inherit Collectible3D")
			continue
		eligible.append(entry)
		total_weight += weight
	if eligible.is_empty():
		return null
	var choice := _random.randf() * total_weight
	for entry in eligible:
		choice -= entry.weight_at(round_number)
		if choice < 0.0:
			return entry
	return eligible.back()
