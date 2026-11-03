class_name WebDeformation3D
extends MeshInstance3D
## Shared cosmetic web response. Logical strands and collision stay undeformed.

const SPRING_MODEL := preload("res://src/features/web/web_spring_model_3d.gd")
const SPRITE_SHADER := preload("res://src/features/web/web_sprite_offset.gdshader")
const STRAND_SHADER := preload("res://src/features/web/web_strand_deformation.gdshader")
const MAX_CONTACTS := 64

@export var local_pull_enabled := true
@export var global_spring_enabled := true
@export_range(0.0, 0.2, 0.01) var pull_amount := 0.2
@export_range(0.0, 0.1, 0.005) var maximum_bend := 0.08
@export_range(6.0, 30.0, 1.0) var settle_speed := 30.0
@export_range(0.0, 3.0, 0.1) var weight := 3.0
@export_range(4.0, 40.0, 1.0) var tension := 10.0
@export_range(0.1, 1.2, 0.05) var damping := 0.35
@export_range(0.0, 0.3, 0.01) var maximum_sag := 0.3
@export_range(0.0, 0.1, 0.005) var depth_sway := 0.035
@export_range(0.0, 0.1, 0.005) var maximum_contact_gap := 0.04

var model: WebSpringModel3D
var _web: Web3D
var _segments: Array[Dictionary] = []
var _strand_segments: Dictionary = {}
var _groups: Dictionary = {}
var _influences: Dictionary = {}
var _sprite_materials: Dictionary = {}
var _surface := ArrayMesh.new()
var _material := ShaderMaterial.new()
var _spring_image: Image
var _spring_texture: ImageTexture
var _spring_data := PackedFloat32Array()
var _mesh_parameters: Array[Array] = []
var _contact_meta := PackedVector4Array()
var _contact_bends := PackedVector4Array()
var _view_normal := Vector3.BACK


func _process(delta: float) -> void:
	advance_visuals(delta)


func _exit_tree() -> void:
	_restore_materials()
	_set_original_strands_visible(true)


func _set_original_strands_visible(value: bool) -> void:
	if not is_instance_valid(_web) or not is_instance_valid(_web.polygon_container):
		return
	for child in _web.polygon_container.get_children():
		if child is WebPolygon3D:
			child.visible = value


func setup(web: Web3D) -> void:
	_web = web
	top_level = true
	global_transform = Transform3D.IDENTITY
	model = SPRING_MODEL.new()
	mesh = _surface
	_material.shader = STRAND_SHADER
	_contact_meta.resize(MAX_CONTACTS)
	_contact_bends.resize(MAX_CONTACTS)
	extra_cull_margin = 0.5
	material_override = _material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	process_priority = 100
	_web.geometry_changed.connect(_rebuild)
	_rebuild()


func register_gait(gait: SpiderLegController3D) -> void:
	if _groups.has(gait):
		return
	var landings: Array[float] = []
	landings.resize(8)
	landings.fill(-1.0)
	_groups[gait] = { "tips": {}, "contacts": {}, "landings": landings }


func unregister_gait(gait: SpiderLegController3D) -> void:
	_groups.erase(gait)
	if is_instance_valid(gait):
		_restore_materials(gait.get_parent().get_parent())


func observe_foot(gait: SpiderLegController3D, index: int, tip: Vector3) -> void:
	if _groups.has(gait):
		_groups[gait].tips[index] = tip


func contact_target(gait: SpiderLegController3D, index: int) -> Dictionary:
	if not _web.deformation_enabled or not local_pull_enabled or not _groups.has(gait):
		return {}
	var contacts: Dictionary = _groups[gait].contacts
	if not contacts.has(index):
		return {}
	var state: Dictionary = contacts[index]
	if (not state.attached
			or gait._is_stepping(index)
			or gait._feet[index].dangling
			or gait.is_carried(index)):
		return {}
	var segment := _segments[state.segment]
	var anchor: Vector3 = segment.start.lerp(segment.end, state.t)
	var point := _rendered_point(state.segment, state.t)
	var warp := model.segment_offset(state.segment, state.t)
	return { "anchor": anchor, "base": point - warp, "warp": warp, "point": point }


func displacement_at(point: Vector3) -> Vector3:
	if model == null or not _web.deformation_enabled:
		return Vector3.ZERO
	return model.displacement_at(point)


func advance_visuals(delta: float) -> void:
	if not is_instance_valid(_web) or model == null:
		return
	if not _web.deformation_enabled:
		_restore_materials()
		visible = false
		_set_original_strands_visible(true)
		return
	var loads: Array[Dictionary] = []
	_influences.clear()
	for gait in _groups.keys():
		if not is_instance_valid(gait) or not gait.is_inside_tree():
			_groups.erase(gait)
			continue
		var group: Dictionary = _groups[gait]
		_collect_loads(gait, group, loads)
		if local_pull_enabled:
			for index in range(gait._feet.size()):
				_update_contact(gait, group, index, minf(delta, 0.05))
		else:
			group.contacts.clear()
	model.effect_enabled = global_spring_enabled
	model.weight = weight
	model.tension = tension
	model.damping = damping
	model.maximum_sag = maximum_sag
	model.depth_sway = depth_sway
	model.advance(delta, loads)
	for gait in _groups:
		_update_materials(gait)
	var active := not _groups.is_empty() and not _segments.is_empty()
	_set_original_strands_visible(not active)
	visible = active
	if not active:
		return
	var camera := get_viewport().get_camera_3d()
	_view_normal = camera.global_basis.z.normalized() if camera != null else model._normal
	_redraw()


func _rebuild() -> void:
	_segments = _web.get_support_segments()
	_strand_segments.clear()
	for index in range(_segments.size()):
		var id: String = _segments[index].strand_id
		if not _strand_segments.has(id):
			_strand_segments[id] = []
		_strand_segments[id].append(index)
	model.setup(_web)
	_influences.clear()
	_surface.clear_surfaces()
	_mesh_parameters.clear()
	_material.set_shader_parameter("contact_count", 0)
	_build_mesh()
	for group in _groups.values():
		group.contacts.clear()
	_set_original_strands_visible(_groups.is_empty())


func _collect_loads(
	gait: SpiderLegController3D,
	group: Dictionary,
	loads: Array[Dictionary],
) -> void:
	var attached: Array[int] = []
	var impacts: Dictionary = {}
	for index in range(gait._feet.size()):
		var foot := gait._feet[index]
		var landed: float = gait.landing_time(index) if gait.has_method("landing_time") else -1.0
		impacts[index] = landed >= 0.0 and landed > group.landings[index]
		group.landings[index] = landed
		if not foot.carried and not foot.dangling and not gait._is_stepping(index):
			attached.append(index)
	for index in attached:
		loads.append({"point": gait._feet[index].marker.global_position,
			"weight": 1.0 / attached.size(), "impact": impacts[index],
			"side": -1.0 if index % 2 == 0 else 1.0})


func _update_contact(
	gait: SpiderLegController3D,
	group: Dictionary,
	index: int,
	delta: float,
) -> void:
	var foot := gait._feet[index]
	var attached := not foot.carried and not foot.dangling and not gait._is_stepping(index)
	var found := -1
	var anchor := Vector3.ZERO
	var parameter := 0.0
	var tip: Vector3 = group.tips.get(index, foot.marker.global_position)
	var state: Dictionary = group.contacts.get(index, {})
	if attached and group.tips.has(index):
		var nearest := maximum_contact_gap
		var strand_id: String = foot.strand_id
		if strand_id.is_empty():
			strand_id = foot.support.get("strand_id", "")
		if strand_id.is_empty() and not state.is_empty() and state.attached:
			strand_id = _segments[state.segment].strand_id
		var candidates: Array = _strand_segments.get(strand_id, [])
		if strand_id.is_empty():
			candidates = range(_segments.size())
		for segment_index: int in candidates:
			var segment := _segments[segment_index]
			var line: Vector3 = segment.end - segment.start
			var along: float = (foot.marker.global_position - segment.start).dot(line)
			var t := clampf(
				along / maxf(line.length_squared(), 0.000001),
				0.0,
				1.0,
			)
			var point: Vector3 = segment.start + line * t
			var gap := point.distance_to(tip)
			if gap < nearest and t > 0.025 and t < 0.975:
				nearest = gap
				found = segment_index
				anchor = point
				parameter = t
	if found >= 0:
		if state.is_empty() or state.segment != found:
			state = {
				"segment": found,
				"t": parameter,
				"bend": Vector3.ZERO,
				"velocity": Vector3.ZERO,
			}
		state.t = parameter
	if state.is_empty():
		return
	state.attached = found >= 0
	var target := Vector3.ZERO
	if state.attached:
		var pull := gait._rig.to_global(foot.planted_anchor) - foot.marker.global_position
		target = (tip - anchor + pull * pull_amount).limit_length(maximum_bend)
	var steps := maxi(1, ceili(delta / 0.008))
	var dt := delta / steps
	for iteration in range(steps):
		var acceleration: Vector3 = (target - state.bend) * settle_speed * settle_speed
		acceleration -= state.velocity * settle_speed * (25.0 / 18.0)
		state.velocity += acceleration * dt
		state.bend = (state.bend + state.velocity * dt).limit_length(maximum_bend)
	if not state.attached and state.bend.length() < 0.0001 and state.velocity.length() < 0.001:
		group.contacts.erase(index)
	else:
		group.contacts[index] = state


func _deformation(segment_index: int, t: float) -> Vector3:
	if not _influences.has(segment_index):
		return Vector3.ZERO
	var segment := _segments[segment_index]
	var offset := Vector3.ZERO
	for state in _influences[segment_index]:
		var spread := minf(0.45, 0.35 / maxf(segment.start.distance_to(segment.end), 0.001))
		var influence := 1.0 - smoothstep(0.0, spread, absf(t - state.t))
		influence *= smoothstep(0.0, minf(spread, state.t), t)
		influence *= smoothstep(0.0, minf(spread, 1.0 - state.t), 1.0 - t)
		offset += state.bend * influence
	return offset.limit_length(maximum_bend)


func _redraw() -> void:
	var count := 0
	_influences.clear()
	for group in _groups.values():
		for state in group.contacts.values():
			if count >= MAX_CONTACTS:
				break
			var segment := _segments[state.segment]
			var spread := minf(0.45, 0.35 / maxf(segment.start.distance_to(segment.end), 0.001))
			_contact_meta[count] = Vector4(state.segment, state.t, spread, 0.0)
			_contact_bends[count] = Vector4(state.bend.x, state.bend.y, state.bend.z, 0.0)
			if not _influences.has(state.segment):
				_influences[state.segment] = []
			_influences[state.segment].append(state)
			count += 1
	for index in range(model._offsets.size()):
		_spring_data[index * 4] = model._offsets[index].x
		_spring_data[index * 4 + 1] = model._offsets[index].y
	_spring_image.set_data(model.field_size.x, model.field_size.y, false,
		Image.FORMAT_RGBAF, _spring_data.to_byte_array())
	_spring_texture.update(_spring_image)
	_material.set_shader_parameter("contact_count", count)
	_material.set_shader_parameter("contact_meta", _contact_meta)
	_material.set_shader_parameter("contact_bends", _contact_bends)
	_material.set_shader_parameter("maximum_bend", maximum_bend)
	_material.set_shader_parameter("web_color", _web.line_color)


func _build_mesh() -> void:
	if _segments.is_empty():
		return
	_spring_data.resize(maxi(model._points.size(), 1) * 4)
	_spring_data.fill(0.0)
	_spring_image = Image.create_from_data(model.field_size.x, model.field_size.y, false,
		Image.FORMAT_RGBAF, _spring_data.to_byte_array())
	_spring_texture = ImageTexture.create_from_image(_spring_image)
	_material.set_shader_parameter("spring_offsets", _spring_texture)
	_material.set_shader_parameter("gravity_direction", model.load_direction.normalized())
	_material.set_shader_parameter("depth_direction", model._normal)
	_material.set_shader_parameter("field_size", model.field_size)
	var vertices := PackedVector3Array()
	var texture_coordinates := PackedVector2Array()
	var spring_coordinates := PackedVector2Array()
	var camera := get_viewport().get_camera_3d()
	var normal := camera.global_basis.z.normalized() if camera != null else model._normal
	var previous_vertex := Vector3.ZERO
	var previous_uv := Vector2.ZERO
	var previous_uv2 := Vector2.ZERO
	for segment_index in range(_segments.size()):
		var segment := _segments[segment_index]
		var parameters: Array = []
		var count := maxi(2, ceili(segment.start.distance_to(segment.end) / 0.12))
		for sample in range(count + 1):
			parameters.append(float(sample) / count)
		parameters.sort()
		_mesh_parameters.append(parameters)
		var direction: Vector3 = segment.end - segment.start
		var side := direction.cross(normal).normalized() * _web.web_width
		for index in range(parameters.size()):
			var t: float = parameters[index]
			var point: Vector3 = segment.start.lerp(segment.end, t)
			var uv := Vector2(segment_index + t * 0.999, model.anchor_factor(point))
			var relative := point - model._origin
			var uv2 := Vector2(relative.dot(model._axis_u), relative.dot(model._axis_v))
			uv2 /= model.spacing
			if index == 0 and not vertices.is_empty():
				vertices.append(previous_vertex)
				texture_coordinates.append(previous_uv)
				spring_coordinates.append(previous_uv2)
				vertices.append(point - side)
				texture_coordinates.append(uv)
				spring_coordinates.append(uv2)
			vertices.append(point - side)
			vertices.append(point + side)
			texture_coordinates.append(uv)
			texture_coordinates.append(uv)
			spring_coordinates.append(uv2)
			spring_coordinates.append(uv2)
			previous_vertex = point + side
			previous_uv = uv
			previous_uv2 = uv2
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = texture_coordinates
	arrays[Mesh.ARRAY_TEX_UV2] = spring_coordinates
	_surface.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLE_STRIP, arrays)


func _rendered_point(segment_index: int, t: float) -> Vector3:
	var parameters: Array = _mesh_parameters[segment_index]
	var after: int = clampi(parameters.bsearch(t), 1, parameters.size() - 1)
	var before: float = parameters[after - 1]
	var finish: float = parameters[after]
	var segment := _segments[segment_index]
	var start_point: Vector3 = segment.start.lerp(segment.end, before)
	start_point += _deformation(segment_index, before) + model.segment_offset(segment_index, before)
	var finish_point: Vector3 = segment.start.lerp(segment.end, finish)
	finish_point += _deformation(segment_index, finish)
	finish_point += model.segment_offset(segment_index, finish)
	var fraction := clampf(inverse_lerp(before, finish, t), 0.0, 1.0)
	return start_point.lerp(finish_point, fraction)


func _update_materials(gait: SpiderLegController3D) -> void:
	var actor := gait.get_parent().get_parent() as BaseSpider3D
	var sprites: Array[Sprite3D] = []
	for sprite_name in ["Body", "LeftEye", "RightEye"]:
		sprites.append(actor.visual_rig.get_node("BoneAttachment3D/BodyOffset/" + sprite_name))
	if actor is PlayerSpider3D:
		sprites.append(actor.get_node("SelectedIndicator"))
		sprites.append(actor.get_node("AimingArrow/TheAimingArrow"))
		for weapon in actor.weapons:
			for child in weapon.get_children():
				if child is Sprite3D:
					sprites.append(child)
	var offset := displacement_at(actor.global_position)
	for sprite in sprites:
		_ensure_material(sprite, actor)
		_sprite_materials[sprite].material.set_shader_parameter("world_offset", offset)
	for sprite in _sprite_materials.keys():
		if not is_instance_valid(sprite):
			_sprite_materials.erase(sprite)


func _ensure_material(sprite: Sprite3D, actor: BaseSpider3D) -> void:
	if _sprite_materials.has(sprite):
		return
	var material := ShaderMaterial.new()
	material.shader = SPRITE_SHADER
	material.set_shader_parameter("sprite_texture", sprite.texture)
	var binding := { "original": sprite.material_override, "material": material }
	binding.actor = actor
	_sprite_materials[sprite] = binding
	sprite.material_override = material


func _restore_materials(actor: Node = null) -> void:
	for sprite in _sprite_materials.keys():
		var binding: Dictionary = _sprite_materials[sprite]
		if actor != null and binding.actor != actor:
			continue
		if is_instance_valid(sprite) and sprite.material_override == binding.material:
			sprite.material_override = binding.original
		_sprite_materials.erase(sprite)
