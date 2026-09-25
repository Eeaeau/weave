class_name CanopyAmbience
extends Node
## Crossfades the forest bed and plays soft wind at varied intervals.

@export_range(-60.0, 0.0, 0.1) var forest_volume_db: float = -24.0
@export_range(-60.0, 0.0, 0.1) var soft_wind_volume_db: float = -21.0
@export_range(0.1, 5.0, 0.1) var crossfade_seconds: float = 2.0
@export_range(0.0, 120.0, 0.1) var forest_loop_seconds: float = 0.0
@export_range(1.0, 60.0, 0.1) var soft_wind_interval_min: float = 8.0
@export_range(1.0, 60.0, 0.1) var soft_wind_interval_max: float = 16.0
@export var random_seed: int = 0

var _random := RandomNumberGenerator.new()
var _elapsed: float = 0.0
var _next_forest: float = INF
var _next_soft_wind: float = INF
var _front: AudioStreamPlayer
var _back: AudioStreamPlayer
var _fade_elapsed: float = 0.0


func _ready() -> void:
	_random.seed = random_seed if random_seed != 0 else randi()
	_front = $ForestA
	_back = $ForestB
	_front.volume_db = forest_volume_db
	_back.volume_db = -60.0
	$SoftWind.volume_db = soft_wind_volume_db
	if _front.stream == null:
		push_warning("Forest ambience stream is missing")
	else:
		_front.play()
		_schedule_forest()
	if $SoftWind.stream == null:
		push_warning("Soft wind stream is missing")
	else:
		_next_soft_wind = sample_soft_wind_interval()


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
	if _elapsed >= _next_soft_wind:
		$SoftWind.volume_db = soft_wind_volume_db + _random.randf_range(-3.0, 2.0)
		$SoftWind.play()
		_next_soft_wind = _elapsed + sample_soft_wind_interval()


func sample_soft_wind_interval() -> float:
	return _random.randf_range(soft_wind_interval_min, soft_wind_interval_max)


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
