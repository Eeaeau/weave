class_name SoftWindLayer
extends AudioStreamPlayer
## Plays short wind gusts with varied gaps, levels, and smooth edges.

@export_range(-60.0, 0.0, 0.1) var level_db: float = -21.0
@export_range(0.1, 5.0, 0.1) var fade_seconds: float = 1.5
@export_range(1.0, 60.0, 0.1) var interval_min: float = 8.0
@export_range(1.0, 60.0, 0.1) var interval_max: float = 16.0
@export var random_seed: int = 0

var _random := RandomNumberGenerator.new()
var _waiting: float = 0.0
var _next_interval: float = INF
var _playback_elapsed: float = 0.0
var _peak_db: float = -21.0


func _ready() -> void:
	_random.seed = random_seed if random_seed != 0 else randi()
	volume_db = -60.0
	if stream == null:
		push_warning("Soft wind stream is missing")
		return
	_next_interval = sample_interval()


func _process(delta: float) -> void:
	advance(delta)


func sample_interval() -> float:
	return _random.randf_range(interval_min, interval_max)


func trigger() -> void:
	if stream == null:
		return
	_peak_db = level_db + _random.randf_range(-3.0, 2.0)
	_playback_elapsed = 0.0
	volume_db = -60.0
	play()


func advance(delta: float) -> void:
	if stream == null:
		return
	if not playing:
		_waiting += maxf(delta, 0.0)
		if _waiting >= _next_interval:
			_waiting = 0.0
			trigger()
		return
	_playback_elapsed += maxf(delta, 0.0)
	var remaining := stream.get_length() - _playback_elapsed
	if remaining <= 0.0:
		stop()
		volume_db = -60.0
		_next_interval = sample_interval()
		return
	var edge := minf(_playback_elapsed, remaining) / fade_seconds
	volume_db = lerpf(-60.0, _peak_db, clampf(edge, 0.0, 1.0))
