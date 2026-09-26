class_name CanopyAmbience
extends Node
## Crossfades the long forest bed.

@export_range(-60.0, 0.0, 0.1) var forest_volume_db: float = -24.0
@export_range(0.1, 5.0, 0.1) var crossfade_seconds: float = 2.0
@export_range(0.0, 120.0, 0.1) var forest_loop_seconds: float = 0.0

var _elapsed: float = 0.0
var _next_forest: float = INF
var _front: AudioStreamPlayer
var _back: AudioStreamPlayer
var _fade_elapsed: float = 0.0


func _ready() -> void:
	_front = $ForestA
	_back = $ForestB
	_front.volume_db = forest_volume_db
	_back.volume_db = -60.0
	if _front.stream == null:
		push_warning("Forest ambience stream is missing")
	else:
		_front.play()
		_schedule_forest()


func _process(delta: float) -> void:
	advance(delta)


func advance(delta: float) -> void:
	_elapsed += maxf(delta, 0.0)
	if _elapsed >= _next_forest:
		_start_crossfade()
	if _back.playing:
		_fade_elapsed = minf(_fade_elapsed + maxf(delta, 0.0), crossfade_seconds)
		var fraction := _fade_elapsed / crossfade_seconds
		_back.volume_db = lerpf(-60.0, forest_volume_db, fraction)
		_front.volume_db = lerpf(forest_volume_db, -60.0, fraction)
		if fraction >= 1.0:
			_front.stop()
			var previous := _front
			_front = _back
			_back = previous


func _schedule_forest() -> void:
	var length := forest_loop_seconds
	if length <= 0.0:
		length = _front.stream.get_length()
	_next_forest = _elapsed + maxf(length - crossfade_seconds, 0.1)


func _start_crossfade() -> void:
	_next_forest = INF
	if _back.stream == null:
		push_warning("Second forest ambience stream is missing")
		return
	_back.volume_db = -60.0
	_back.play()
	_fade_elapsed = 0.0
	_schedule_forest()
