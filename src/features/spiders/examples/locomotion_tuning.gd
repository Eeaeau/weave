extends Node3D
# gdstyle:ignore-file=quality/allocation-in-loop
## Compare the old grouped gait with the game's current movement and spring settings.

const SPIDER := preload("res://src/features/spiders/player_spider.tscn")
const GROUPED_GAIT := preload("res://src/features/spiders/spider_leg_controller_3d.gd")

var automatic_movement := true
var actors: Array[PlayerSpider3D] = []
var webs: Array[Web3D] = []
var _velocities: Array[Vector3] = []
var _dots: Array[Array] = []
var _statuses: Array[Label] = []
var _phase := 0.0
var _warmup := 0.0
var _walk_speed := PlayerSpider3D.MOVE_SPEED
var _show_dots := true
var _equipped := false
var _deformation: WebDeformation3D


func _ready() -> void:
	get_window().content_scale_size = Vector2i(1280, 960)
	var camera := Camera3D.new()
	camera.position = Vector3(0, 0, 15)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 10.2
	add_child(camera)
	camera.current = true
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("26333d")
	add_child(environment)
	var canvas := CanvasLayer.new()
	add_child(canvas)
	for side in range(2):
		_add_comparison(side, canvas)
	_deformation = webs[1].get_deformation()
	_add_sliders(canvas)
	var controls := Label.new()
	controls.text = """Space: auto/manual | WASD/arrows: move | E: launcher | F2: dots
F3: web targeting | F4: local pull | F5: global spring"""
	controls.position = Vector2(35, 870)
	controls.add_theme_font_size_override("font_size", 18)
	canvas.add_child(controls)


func _process(delta: float) -> void:
	_warmup += delta
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if not input.is_zero_approx():
		automatic_movement = false
	var phase_rate := 0.7 * _walk_speed / PlayerSpider3D.MOVE_SPEED
	if automatic_movement and _warmup > 1.5:
		_phase += phase_rate * delta
	for side in range(actors.size()):
		var desired := Vector3.ZERO
		if automatic_movement:
			if _warmup > 1.5:
				desired = Vector3(cos(_phase) * 0.8, -sin(_phase) * 0.35, 0) * phase_rate
		else:
			desired = Vector3(input.x, -input.y, 0) * (2.0 if side == 0 else _walk_speed)
		if side == 0:
			_velocities[side] = desired
		else:
			var acceleration := 6.0
			if desired.is_zero_approx() or _velocities[side].length() > desired.length() + 0.001:
				acceleration = 10.0
			if _velocities[side].dot(desired) < 0.0:
				acceleration = 12.0
			_velocities[side] = _velocities[side].move_toward(desired, acceleration * delta)
		var travel := _velocities[side] * delta
		var next := actors[side].global_position + travel
		if actors[side].is_on_web(Vector2(next.x, next.y)):
			actors[side].global_position = next
			if travel.length_squared() > 0.000001:
				actors[side].face_direction(atan2(travel.x, -travel.y))
		else:
			_velocities[side] = Vector3.ZERO
		_update_debug(side)


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.physical_keycode == KEY_SPACE:
		automatic_movement = not automatic_movement
	elif key.physical_keycode == KEY_F2:
		_show_dots = not _show_dots
	elif key.physical_keycode == KEY_E:
		_toggle_equipment()
	elif key.physical_keycode == KEY_F3:
		var gait := actors[1].get_node("SpiderRig/LegController")
		gait.targeting_mode = 1 - gait.targeting_mode
	elif key.physical_keycode == KEY_F4:
		_deformation.local_pull_enabled = not _deformation.local_pull_enabled
	elif key.physical_keycode == KEY_F5:
		_deformation.global_spring_enabled = not _deformation.global_spring_enabled


func _add_comparison(side: int, canvas: CanvasLayer) -> void:
	var web := Web3D.new()
	web.position = Vector3(-3.4 if side == 0 else 3.4, 0, 0)
	web.rotation.x = PI / 2.0
	web.rings = 6
	web.curve_segments = 1
	web.web_width = 0.012
	web.deformation_enabled = side == 1
	for point in [Vector3(-2.8, 0, -2.1), Vector3(2.8, 0, -2.1), Vector3(0, 0, 3.2)]:
		var anchor := Marker3D.new()
		web.add_child(anchor)
		anchor.position = point
		web.valid_nodes.append(anchor)
	web.edges = [Vector2i(0, 1), Vector2i(1, 2), Vector2i(2, 0)]
	add_child(web)
	webs.append(web)
	var actor := SPIDER.instantiate() as PlayerSpider3D
	actor.rotation.x = PI / 2.0
	actor.position = web.position
	actor.network_controlled = true
	actor.webs = [web]
	actor.get_node("SpiderRig/BoneAttachment3D/BodyOffset").randomize_idle_phase = false
	var gait := actor.get_node("SpiderRig/LegController")
	if side == 0:
		gait.set_script(GROUPED_GAIT)
		gait.step_duration = 0.22
		actor.visual_turn_speed = 3.0
		actor.body_surge = 0.0
	add_child(actor)
	gait.support_web = web
	actors.append(actor)
	_velocities.append(Vector3.ZERO)
	var heading := Label.new()
	heading.text = "Previous: instant body / grouped feet"
	if side == 1:
		heading.text = "Current: contact gait / elastic web"
	heading.position = Vector2(35 + side * 640, 20)
	heading.add_theme_font_size_override("font_size", 23)
	canvas.add_child(heading)
	var status := Label.new()
	status.position = Vector2(35 + side * 640, 57)
	canvas.add_child(status)
	_statuses.append(status)
	var dots: Array = []
	for index in range(8):
		var dot := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.035
		sphere.height = 0.07
		sphere.radial_segments = 8
		sphere.rings = 4
		dot.mesh = sphere
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		dot.material_override = material
		add_child(dot)
		var label := Label3D.new()
		label.text = ("L" if index % 2 == 0 else "R") + str(int(index / 2) + 1)
		label.font_size = 24
		label.outline_size = 4
		label.pixel_size = 0.004
		label.position = Vector3(0.07, 0.07, 0.0)
		dot.add_child(label)
		dots.append(dot)
	_dots.append(dots)


func _update_debug(side: int) -> void:
	var gait: SpiderLegController3D = actors[side].get_node("SpiderRig/LegController")
	var planted := 0
	var stepping := 0
	for index in range(8):
		var foot := gait._feet[index]
		var dot: MeshInstance3D = _dots[side][index]
		dot.visible = _show_dots
		dot.global_position = foot.marker.global_position
		if side == 1 and gait.targeting_mode == SpiderLegController3D.TargetingMode.WEB:
			dot.global_position += _deformation.displacement_at(dot.global_position)
		dot.global_position.z = 1.0
		var material := dot.material_override as StandardMaterial3D
		if foot.carried:
			material.albedo_color = Color.SKY_BLUE
		elif gait._is_stepping(index):
			material.albedo_color = Color.YELLOW
			stepping += 1
		elif foot.dangling:
			material.albedo_color = Color.ORANGE_RED
		else:
			material.albedo_color = Color.LIME_GREEN
			planted += 1
	var values := [planted, stepping, _velocities[side].length()]
	_statuses[side].text = "Planted: %s  Stepping: %s  Speed: %.2f" % values


func _toggle_equipment() -> void:
	_equipped = not _equipped
	for actor in actors:
		if _equipped and actor.weapons.size() < 3:
			var scene := load("res://src/features/collectibles/weapons/weapon_rocket_launcher.tscn")
			var item := scene.instantiate() as Weapon3D
			actor.add_child(item)
			actor.pick_up(item)
			item.after_picked_up()
		actor.select_weapon(2 if _equipped else 0)


func _add_sliders(canvas: CanvasLayer) -> void:
	_slider(
		canvas,
		"Walk speed",
		0,
		0.4,
		2.0,
		0.05,
		_walk_speed,
		func(value: float): _walk_speed = value,
	)
	_slider(
		canvas,
		"Turn speed",
		1,
		0.4,
		3.0,
		0.1,
		actors[1].visual_turn_speed,
		func(value: float): actors[1].visual_turn_speed = value,
	)
	var gait := actors[1].get_node("SpiderRig/LegController")
	_slider(
		canvas,
		"Min stride",
		2,
		0.08,
		0.5,
		0.01,
		gait.minimum_stride,
		func(value: float): gait.minimum_stride = value,
	)
	_slider(
		canvas,
		"Body settle",
		3,
		0.0,
		0.04,
		0.0025,
		actors[1].body_surge,
		func(value: float): actors[1].body_surge = value,
	)
	_slider(
		canvas,
		"Depth sway",
		4,
		0.0,
		0.1,
		0.005,
		_deformation.depth_sway,
		func(value: float): _deformation.depth_sway = value,
	)
	_slider(
		canvas,
		"Web pull",
		0,
		0.0,
		0.2,
		0.01,
		_deformation.pull_amount,
		func(value: float): _deformation.pull_amount = value,
		0,
	)
	_slider(
		canvas,
		"Max bend",
		1,
		0.0,
		0.1,
		0.005,
		_deformation.maximum_bend,
		func(value: float): _deformation.maximum_bend = value,
		0,
	)
	_slider(
		canvas,
		"Settle speed",
		2,
		6.0,
		30.0,
		1.0,
		_deformation.settle_speed,
		func(value: float): _deformation.settle_speed = value,
		0,
	)
	_slider(
		canvas,
		"Web weight",
		3,
		0.0,
		3.0,
		0.1,
		_deformation.weight,
		func(value: float): _deformation.weight = value,
		0,
	)
	_slider(
		canvas,
		"Web tension",
		4,
		4.0,
		40.0,
		1.0,
		_deformation.tension,
		func(value: float): _deformation.tension = value,
		0,
	)
	_slider(
		canvas,
		"Web damping",
		5,
		0.1,
		1.2,
		0.05,
		_deformation.damping,
		func(value: float): _deformation.damping = value,
		0,
	)
	_slider(
		canvas,
		"Max sag",
		6,
		0.0,
		0.3,
		0.01,
		_deformation.maximum_sag,
		func(value: float): _deformation.maximum_sag = value,
		0,
	)


func _slider(canvas: CanvasLayer, caption: String, row: int, minimum: float, maximum: float,
		increment: float, initial: float, changed: Callable, column: int = 1) -> void:
	var column_x := 35 + column * 640
	var label := Label.new()
	label.position = Vector2(column_x, 108 + row * 23)
	label.text = "%s: %s" % [caption, String.num(initial, 3)]
	canvas.add_child(label)
	var slider := HSlider.new()
	slider.position = Vector2(column_x + 180, 112 + row * 23)
	slider.custom_minimum_size = Vector2(350, 18)
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = increment
	slider.value = initial
	slider.focus_mode = Control.FOCUS_NONE
	canvas.add_child(slider)
	slider.value_changed.connect(func(value: float):
		label.text = "%s: %s" % [caption, String.num(value, 3)]
		changed.call(value))
