class_name MatchHud
extends CanvasLayer
## Identifies the scene as an editable layout prototype.

var show_hints := true

@onready var status: Label = $Margin/Panel/Status
@onready var energy_bar: ProgressBar = $LowerLeftPanel/EnergyBar
@onready var team_label: Label = $LowerLeftPanel/TeamLabel

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
		status.text += "\nBranches, spiders, webs, and collectibles are placeholders.\nEsc: pause"


func update_energy(energy: float) -> void:
	"""
	Takes energy as a 0-1 float
	"""
	if energy_bar:
		energy_bar.value = energy

func update_team_label(text: String) -> void:
	if team_label:
		team_label.text = text
