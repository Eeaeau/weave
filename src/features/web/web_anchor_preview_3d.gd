@tool
class_name WebAnchorPreview3D
extends Node3D
## Shows every direct Marker3D child while editing, regardless of selection.

const PREVIEW_TEXTURE := preload("res://src/features/web/assets/editor_anchor_marker.svg")
const WEB_ANCHOR_LAYER := 1 << 4

@export_range(0.1, 1.0, 0.05) var projectile_hit_radius: float = 0.3
@export var preview_color: Color = Color(0.26, 0.91, 0.94):
	set(value):
		preview_color = value
		if Engine.is_editor_hint():
			refresh_editor_previews()


func _ready() -> void:
	child_entered_tree.connect(_on_anchor_entered)
	if Engine.is_editor_hint():
		refresh_editor_previews()
	else:
		refresh_projectile_hitboxes()


func _on_anchor_entered(node: Node) -> void:
	if node is Marker3D:
		if Engine.is_editor_hint():
			_ensure_preview(node)
		else:
			_ensure_projectile_hitbox(node)


func refresh_editor_previews() -> void:
	for anchor in get_children():
		if anchor is Marker3D:
			_ensure_preview(anchor)


func refresh_projectile_hitboxes() -> void:
	for anchor in get_children():
		if anchor is Marker3D:
			_ensure_projectile_hitbox(anchor)


func _ensure_projectile_hitbox(anchor: Marker3D) -> void:
	if anchor.get_node_or_null("ProjectileHitbox") != null:
		return
	var hitbox := Area3D.new()
	hitbox.name = "ProjectileHitbox"
	hitbox.add_to_group("web_anchor_hitboxes")
	hitbox.collision_layer = WEB_ANCHOR_LAYER
	hitbox.collision_mask = 0
	hitbox.monitoring = false
	anchor.add_child(hitbox)
	var collider := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = projectile_hit_radius
	collider.shape = shape
	hitbox.add_child(collider)


func _ensure_preview(anchor: Marker3D) -> void:
	var preview := anchor.get_node_or_null("EditorPreview") as Sprite3D
	if preview == null:
		preview = Sprite3D.new()
		preview.name = "EditorPreview"
		preview.texture = PREVIEW_TEXTURE
		preview.pixel_size = 0.008
		preview.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		preview.no_depth_test = true
		preview.fixed_size = true
		preview.render_priority = 100
		anchor.add_child(preview)
	preview.modulate = preview_color
