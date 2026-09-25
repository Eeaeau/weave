class_name MatchHud
extends CanvasLayer
## Identifies the scene as an editable layout prototype.

var show_hints := true

@onready var status: Label = $Margin/Panel/Status


func _ready() -> void:
	_update_status()


func set_show_hints(enabled: bool) -> void:
	show_hints = enabled
	_update_status()


func _update_status() -> void:
	if not is_node_ready():
		return
	status.text = "WEAVE  |  2.5D scene prototype"
	if show_hints:
		status.text += "\nBranches, spiders, strands, and weapon are placeholders.\nEsc: pause"
