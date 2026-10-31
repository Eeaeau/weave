class_name GuidedRocket3D
extends Projectile3D

signal steering_changed

@export_range(0.2, 5.0, 0.1) var turn_speed := 2.5
@export_range(1.0, 15.0, 0.5) var flight_limit := 8.0

var steering := 0
var flight_age := 0.0


func _ready() -> void:
	super._ready()
	add_to_group("guided_rockets")


func _process(delta: float) -> void:
	if freeze or network_replica:
		return
	var step := minf(maxf(delta, 0.0), maxf(0.0, flight_limit - flight_age))
	var motion := sample_flight(global_position, velocity, steering * turn_speed, step)
	global_position = motion.position
	velocity = motion.velocity
	if global_position.distance_to(_launch_position) >= launch_ally_grace_distance:
		launch_ally_grace_distance = 0.0
	flight_age += step
	face_velocity()
	if flight_age >= flight_limit or global_position.y <= despawn_below_y:
		hit(null)


func launch(direction: float, power: float) -> void:
	super.launch(direction, power)
	face_velocity()


func set_steering(value: int) -> void:
	if freeze or network_replica:
		return
	var next := clampi(value, -1, 1)
	if steering != next:
		steering = next
		steering_changed.emit()


func face_velocity() -> void:
	if velocity.length_squared() > 0.0001:
		global_basis = Basis(Vector3.BACK, atan2(velocity.y, velocity.x))


static func sample_flight(point: Vector3, speed: Vector3, angular_speed: float,
		seconds: float) -> Dictionary:
	if absf(angular_speed) < 0.001:
		return {"position": point + speed * seconds + Vector3.DOWN * 4.905 * seconds * seconds,
			"velocity": speed + Vector3.DOWN * 9.81 * seconds}
	var sine := sin(angular_speed * seconds)
	var cosine := cos(angular_speed * seconds)
	var inverse := 1.0 / angular_speed
	var gravity := -9.81
	var offset := Vector3(
		(speed.x * sine + speed.y * (cosine - 1.0)) * inverse
			+ gravity * (sine * inverse - seconds) * inverse,
		(speed.x * (1.0 - cosine) + speed.y * sine) * inverse
			+ gravity * (1.0 - cosine) * inverse * inverse, 0)
	var next_speed := Vector3(
		speed.x * cosine - speed.y * sine + gravity * (cosine - 1.0) * inverse,
		speed.x * sine + speed.y * cosine + gravity * sine * inverse, 0)
	return { "position": point + offset, "velocity": next_speed }
