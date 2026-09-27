class_name CaughtCollectible3D
extends Node3D
## Keeps a wind collectible attached to its supporting web face.

var web: Web3D
var face_key: String
var item: Collectible3D
var _releasing := false


func configure(support_web: Web3D, support_face: String, caught_item: Collectible3D) -> void:
	web = support_web
	face_key = support_face
	item = caught_item
	web.geometry_changed.connect(_on_geometry_changed)
	child_exiting_tree.connect(_on_child_exiting_tree)
	if item.pickup_area:
		item.pickup_area.set_deferred("monitoring", true)


func _on_geometry_changed() -> void:
	if _releasing or web.has_catch_face(face_key):
		return
	_releasing = true
	if item.pickup_area:
		item.pickup_area.set_deferred("monitoring", false)
	var tween := create_tween()
	tween.tween_property(item, "position", item.position + Vector3.DOWN * 1.2, 0.5)
	tween.tween_callback(queue_free)


func _on_child_exiting_tree(child: Node) -> void:
	if child == item and not _releasing:
		call_deferred("queue_free")
