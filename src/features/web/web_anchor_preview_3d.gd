@tool
class_name WebAnchorPreview3D
extends Node3D
## Shows every direct Marker3D child while editing, regardless of selection.

const PREVIEW_TEXTURE := preload("res://src/features/web/assets/editor_anchor_marker.svg")

@export var preview_color: Color = Color(0.26, 0.91, 0.94):
	set(value):
		preview_color = value
		if Engine.is_editor_hint():
			refresh_editor_previews()


func _ready() -> void:
	if Engine.is_editor_hint():
		child_entered_tree.connect(_on_anchor_entered)
		refresh_editor_previews()


func _on_anchor_entered(node: Node) -> void:
	if node is Marker3D:
		_ensure_preview(node)


func refresh_editor_previews() -> void:
	for anchor in get_children():
		if anchor is Marker3D:
			_ensure_preview(anchor)


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
