class_name WebMatch3D
extends Node3D
## Composes the 3D arena, actors, web, collectible markers, and reusable UI.

@onready var hud: MatchHud = $MatchHud
@onready var pause_settings: SettingsMenu = $PauseMenu/SettingsMenu
@onready var wind_event: WindEvent3D = $BranchCanopy/WindEvent
@onready var catch_webs: Array[Web3D] = [$WebA, $WebB]


func _ready() -> void:
	hud.set_show_hints(pause_settings.hints_check.button_pressed)
	pause_settings.hints_changed.connect(hud.set_show_hints)
	wind_event.item_contact.connect(_on_item_contact)


func _on_item_contact(item: Collectible3D, side: int, _local_point: Vector2,
		world_point: Vector3) -> void:
	var preferred_web := catch_webs[side] if side >= 0 and side < catch_webs.size() else null
	var candidate_webs: Array[Web3D] = []
	if preferred_web != null:
		candidate_webs.append(preferred_web)
	for web in catch_webs:
		if web != preferred_web:
			candidate_webs.append(web)
	for web in candidate_webs:
		var face_key := web.find_catch_face(world_point)
		if face_key.is_empty():
			continue
		_catch_item(item, web, face_key, world_point)
		return


func _catch_item(item: Collectible3D, web: Web3D, face_key: String,
		world_point: Vector3) -> void:
	var caught := CaughtCollectible3D.new()
	web.get_node("CaughtItems").add_child(caught)
	caught.global_position = world_point
	if wind_event.claim(item, caught):
		caught.configure(web, face_key, item)
	else:
		caught.queue_free()
