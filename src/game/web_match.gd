class_name WebMatch3D
extends Node3D

signal collectible_contact_resolved(id: String, caught: bool, world_point: Vector3)

const OPTIONS := preload("res://src/game/match_options.gd")

@export var sound_tracks: Array[AudioStream]

var _current_track_index := -1

## Composes the 3D arena, actors, web, collectible markers, and reusable UI.

@onready var hud: MatchHud = $MatchHud
@onready var pause_settings: SettingsMenu = $PauseMenu/SettingsMenu
@onready var wind_event: WindEvent3D = $BranchCanopy/WindEvent
@onready var catch_webs: Array[Web3D] = [
	$BranchCanopy/Branches/LeftBranch/StartingWeb,
	$BranchCanopy/Branches/RightBranch/StartingWeb,
]
@onready var audio_stream_player: AudioStreamPlayer = $AudioStreamPlayer


func _enter_tree() -> void:
	if get_node("/root/OnlineSession").is_match_active():
		return
	var local_options: Dictionary = OPTIONS.consume_local(get_tree())
	if not local_options.is_empty():
		get_node("BranchCanopy/WindEvent").group_size = local_options.drops


func _ready() -> void:
	for web in catch_webs:
		web.add_to_group("gameplay_webs")
	$MatchManager.match_finished.connect($GameOverMenu.show_result)
	hud.set_show_hints(pause_settings.hints_check.button_pressed)
	pause_settings.hints_changed.connect(hud.set_show_hints)
	wind_event.item_contact.connect(_on_item_contact)
	audio_stream_player.finished.connect(_on_audio_finished)
	_play_random_track()
	if get_node("/root/OnlineSession").is_match_active():
		_attach_multiplayer.call_deferred()


func _attach_multiplayer() -> void:
	if not get_node("/root/OnlineSession").is_match_active():
		return
	var driver: Node = load("res://src/features/multiplayer/match_replication.gd").new()
	driver.name = "MatchReplication"
	add_child(driver)
	get_node("/root/OnlineSession").attach_replication(driver, self)


func _on_audio_finished() -> void:
	_play_random_track()


func _play_random_track() -> void:
	if sound_tracks.is_empty():
		audio_stream_player.stop()
		return

	var next_index := randi_range(0, sound_tracks.size() - 1)
	if sound_tracks.size() > 1 and next_index == _current_track_index:
		next_index = (next_index + 1) % sound_tracks.size()
	_current_track_index = next_index
	audio_stream_player.stream = sound_tracks[next_index]
	audio_stream_player.play()


func _on_item_contact(item: Collectible3D, side: int, _local_point: Vector2,
		world_point: Vector3) -> void:
	if (get_node("/root/OnlineSession").is_match_active()
			and get_node("/root/GDSync").get_client_id()
			!= get_node("/root/OnlineSession").host_id):
		return
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
		collectible_contact_resolved.emit(item.get_meta("network_id", ""), true, world_point)
		return
	collectible_contact_resolved.emit(item.get_meta("network_id", ""), false, world_point)


func _catch_item(item: Collectible3D, web: Web3D, face_key: String,
		world_point: Vector3) -> void:
	var caught := CaughtCollectible3D.new()
	var id: String = item.get_meta("network_id", "")
	if not id.is_empty():
		caught.set_meta("network_id", id)
	web.get_node("CaughtItems").add_child(caught)
	caught.global_position = world_point
	if wind_event.claim(item, caught):
		caught.configure(web, face_key, item)
	else:
		caught.queue_free()
