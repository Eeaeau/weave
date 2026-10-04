class_name BranchCanopy3D
extends Node3D
## Layered 2D artwork placed at several depths in the 3D arena.

var catch_webs: Array[Web3D] = []

@onready var action_camera: ActionCamera3D = $ParallaxCamera
@onready var wind_event: WindEvent3D = $WindEvent


func _ready() -> void:
	_connect_branch_webs()
	action_camera.set_wind_event(wind_event)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("8f6575")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("f0ae7d")
	environment.ambient_light_energy = 0.62
	$WorldEnvironment.environment = environment


func _connect_branch_webs() -> void:
	var left_branch := $Branches/LeftBranch as Node3D
	var right_branch := $Branches/RightBranch as Node3D
	var left_web := left_branch.get_node("StartingWeb") as Web3D
	var right_web := right_branch.get_node("StartingWeb") as Web3D
	var left_anchors := left_web.ordered_anchors(left_branch.get_node("WebAnchors"))
	var right_anchors := right_web.ordered_anchors(right_branch.get_node("WebAnchors"))
	left_web.valid_nodes = left_anchors + right_anchors
	right_web.valid_nodes = right_anchors + left_anchors
	catch_webs = [left_web, right_web]
