extends SceneTree
# gdstyle:ignore-file=quality/allocation-in-loop


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var web := Web3D.new()
	web.rotation = Vector3(0.8, 0.4, -0.2)
	web.web_width = 0.03
	for point in [Vector3(-2, 0, -1), Vector3(2, 0, -1), Vector3(0, 0, 2)]:
		var anchor := Marker3D.new()
		anchor.position = point
		web.add_child(anchor)
		web.valid_nodes.append(anchor)
	web.edges = [Vector2i(0, 1), Vector2i(1, 2), Vector2i(2, 0)]
	root.add_child(web)
	var service := web.get_deformation() as WebDeformation3D
	var model := service.model
	for index in range(model._offsets.size()):
		var column := index % model.field_size.x
		model._offsets[index] = Vector2(0.3 if column % 2 == 0 else 0.0, 0.02)
	var arrays := service.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var coordinates: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
	var strand_coordinates: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var pairs := 0
	for index in range(vertices.size() - 1):
		if vertices[index].distance_to(vertices[index + 1]) < web.web_width:
			continue
		if strand_coordinates[index] != strand_coordinates[index + 1]:
			continue
		var center := (vertices[index] + vertices[index + 1]) * 0.5
		var field := _shader_sample(model, coordinates[index]) * strand_coordinates[index].y
		var offset := model.load_direction.normalized() * field.x + model._normal * field.y
		if (coordinates[index].distance_to(coordinates[index + 1]) > 0.00001
				or offset.distance_to(model.displacement_at(center)) > 0.00001):
			push_error("WEB SHADER FIELD FAIL: ribbon and CPU contact used different field samples")
			quit(1)
			return
		pairs += 1
	web.queue_free()
	await process_frame
	assert(pairs > 30, "The parity fixture must span multiple cells and strands")
	print("WEB SHADER FIELD PASS: %s ribbon pairs match CPU field on a rotated web" % pairs)
	quit(0)


func _shader_sample(model: WebSpringModel3D, coordinates: Vector2) -> Vector2:
	var cell := coordinates.clamp(Vector2.ZERO, Vector2(model.field_size - Vector2i.ONE))
	var start := Vector2i(floori(cell.x), floori(cell.y))
	var finish := (start + Vector2i.ONE).min(model.field_size - Vector2i.ONE)
	var fraction := cell - Vector2(start)
	var top := model._offsets[start.y * model.field_size.x + start.x].lerp(
		model._offsets[start.y * model.field_size.x + finish.x], fraction.x)
	var bottom := model._offsets[finish.y * model.field_size.x + start.x].lerp(
		model._offsets[finish.y * model.field_size.x + finish.x], fraction.x)
	return top.lerp(bottom, fraction.y)
