extends Node3D
## Standalone visual preview; normal matches await a future turn controller.


func _ready() -> void:
	$WebMatch/WindbornePebble.hide()
	$WebMatch/WindborneMoth.hide()
	var event: WindEvent3D = $WebMatch/BranchCanopy/WindEvent
	event.item_contact.connect(func(item: Collectible3D, side: int,
			local_point: Vector2, _world_point: Vector3) -> void:
		print("WIND CONTACT: %s side=%d point=%s" % [
			item.collectible.display_name, side, local_point]))
	event.event_finished.connect(func(round_number: int) -> void:
		print("WIND FINISHED: round=%d" % round_number))
	event.start_round(1)
