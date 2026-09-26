@tool
extends EditorPlugin


class WebPolygonGizmo extends EditorNode3DGizmoPlugin:

	func _init() -> void:
		create_material(
			"polygon",
			Color(0.2, 0.8, 1.0, 1.0)
		)

		create_handle_material(
			"handles"
		)


	func _get_gizmo_name() -> String:
		return "WebPolygon3D"


	func _has_gizmo(node: Node3D) -> bool:
		return node is WebPolygon3D


	func _redraw(gizmo: EditorNode3DGizmo) -> void:
		gizmo.clear()

		var polygon := gizmo.get_node_3d() as WebPolygon3D

		if polygon == null:
			return

		if polygon.points.size() == 0:
			return


		# -------------------------------------------------
		# Polygon outline
		# -------------------------------------------------

		var lines := PackedVector3Array()

		for i in range(polygon.points.size()):
			lines.append(polygon.points[i])
			lines.append(
				polygon.points[(i + 1) % polygon.points.size()]
			)

		gizmo.add_lines(
			lines,
			get_material("polygon", gizmo),
			false
		)


		# -------------------------------------------------
		# Handles
		# -------------------------------------------------

		var handles := PackedVector3Array()

		for point in polygon.points:
			handles.append(point)

		gizmo.add_handles(
			handles,
			get_material("handles", gizmo),
			[]
		)


	func _get_handle_name(
		gizmo: EditorNode3DGizmo,
		handle_id: int,
		secondary: bool
	) -> String:

		return "Point %d" % handle_id


	func _get_handle_value(
		gizmo: EditorNode3DGizmo,
		handle_id: int,
		secondary: bool
	) -> Variant:

		var polygon := gizmo.get_node_3d() as WebPolygon3D

		if polygon == null:
			return Vector3.ZERO

		if handle_id < 0 or handle_id >= polygon.points.size():
			return Vector3.ZERO

		return polygon.points[handle_id]

	func _set_handle(
		gizmo: EditorNode3DGizmo,
		handle_id: int,
		secondary: bool,
		camera: Camera3D,
		screen_pos: Vector2
	) -> void:

		var polygon := gizmo.get_node_3d() as WebPolygon3D

		if polygon == null:
			return

		if handle_id < 0 or handle_id >= polygon.points.size():
			return


		# Mouse ray in world space.
		var ray_origin := camera.project_ray_origin(screen_pos)
		var ray_direction := camera.project_ray_normal(screen_pos)


		# Polygon's local Z axis in world space.
		var normal := polygon.global_transform.basis.z.normalized()

		var plane := Plane(
			normal,
			normal.dot(polygon.global_position)
		)


		var hit: Variant = plane.intersects_ray(
			ray_origin,
			ray_direction
		)

		if hit == null:
			return


		# Convert world position to polygon-local space.
		var world_position: Vector3 = hit

		var local_position: Vector3 = (
			polygon.global_transform.affine_inverse()
			* world_position
		)

		# Keep the point on the local XY plane.
		local_position.z = 0.0


		# Update the array as a whole so Godot sees
		# the exported property changing.
		var new_points: Array[Vector3] = polygon.points.duplicate()

		new_points[handle_id] = local_position

		polygon.points = new_points

		polygon.draw()



	func _commit_handle(
		gizmo: EditorNode3DGizmo,
		handle_id: int,
		secondary: bool,
		restore: Variant,
		cancel: bool
	) -> void:

		var polygon := gizmo.get_node_3d() as WebPolygon3D

		if polygon == null:
			return

		if cancel:
			polygon.points = restore
			polygon.draw()


var gizmo_plugin: WebPolygonGizmo


func _enter_tree() -> void:
	gizmo_plugin = WebPolygonGizmo.new()

	add_node_3d_gizmo_plugin(
		gizmo_plugin
	)


func _exit_tree() -> void:
	if gizmo_plugin:
		remove_node_3d_gizmo_plugin(
			gizmo_plugin
		)

	gizmo_plugin = null
