class_name MatchHud
extends CanvasLayer
## Identifies the scene as an editable layout prototype.

var show_hints := true

@onready var status: Label = $Margin/Panel/Status
@onready var energy_bar: ProgressBar = $LowerLeftPanel/EnergyBar
@onready var team_label: Label = $LowerLeftPanel/TeamLabel
@onready var actions_remaining_label: Label = $LowerLeftPanel/ActionsRemainingLabel
@onready var weapons_container: BoxContainer = $WeaponsContainer


func _ready() -> void:
	_update_status()
	for child in weapons_container.get_children():
		child.visible = false


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


func update_actions_remaining(n: int) -> void:
	if actions_remaining_label:
		actions_remaining_label.text = "Actions remaining: " + str(n)


func update_weapon(weapons: Array[Weapon3D], selected_weapon_idx: int) -> void:
	var containers: Array[PanelContainer] = []
	for child in weapons_container.get_children():
		if child is PanelContainer:
			containers.append(child)

	assert(
		len(weapons) <= len(containers),
		"more weapons in inventory than display containers! {0} > {1}".format(
			[len(weapons), len(containers)]
			),
	)
	for i in range(len(containers)):
		var w_container = containers[i]
		var weapon: Weapon3D = null
		if i < len(weapons):
			weapon = weapons.get(i)

		if not weapon:
			w_container.visible = false
		else:
			w_container.visible = true
			var texture_rect: TextureRect = w_container.get_child(0)
			texture_rect.texture = weapon.icon
			var number_label: Label = texture_rect.get_child(0)
			number_label.text = str(i + 1)
			if i == selected_weapon_idx:
				w_container.self_modulate.r8 = 0
				w_container.self_modulate.g8 = 0
			else:
				w_container.self_modulate.r8 = 0xff
				w_container.self_modulate.g8 = 0xff
