class_name WindGust
extends AudioStreamPlayer
## Plays one gust for the full wind group and fades when it ends.

@export_range(-60.0, 0.0, 0.1) var level_db: float = -9.0
@export_range(0.1, 5.0, 0.1) var fade_seconds: float = 1.0

var _fade_elapsed: float = -1.0


func start_gust() -> void:
	_fade_elapsed = -1.0
	volume_db = level_db
	if stream == null:
		push_warning("Wind gust stream is missing")
		return
	play()


func finish_gust() -> void:
	_fade_elapsed = 0.0


func advance(delta: float) -> void:
	if _fade_elapsed < 0.0 or not playing:
		return
	_fade_elapsed = minf(_fade_elapsed + maxf(delta, 0.0), fade_seconds)
	volume_db = lerpf(level_db, -60.0, _fade_elapsed / fade_seconds)
	if _fade_elapsed >= fade_seconds:
		stop()
		_fade_elapsed = -1.0
