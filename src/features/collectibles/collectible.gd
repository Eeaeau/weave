class_name Collectible3D
extends Node3D
## Shared world object for weapons and insects.

@export var collectible: CollectibleData
@export var pickup_area: Area3D


func _ready() -> void:
	assert(pickup_area, "Collectible3D '{0}' needs a pickup_area".format([name]))
	pickup_area.connect("area_entered", _area_entered)


func after_picked_up() -> void:
	if pickup_area:
		pickup_area.set_deferred("monitoring", false)
	self.visible = false


func _area_entered(area: Area3D) -> void:
	var parent = area.get_parent_node_3d()
	if parent and parent is PlayerSpider3D:
		if parent.pick_up(self):
			after_picked_up()
