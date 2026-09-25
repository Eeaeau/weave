class_name WindSpawnEntry
extends Resource
## Editable chance for one collectible to arrive in a round's wind event.

@export var scene: PackedScene
@export var data: CollectibleData
@export_range(0.0, 100.0, 0.1) var base_weight: float = 1.0
@export_range(1, 100) var earliest_round: int = 1
@export_range(0.0, 100.0, 0.1) var weight_growth_per_round: float = 0.0


func weight_at(round_number: int) -> float:
	if round_number < earliest_round:
		return 0.0
	return maxf(0.0, base_weight + weight_growth_per_round * (round_number - earliest_round))
