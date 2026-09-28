class_name BranchCanopy3D
extends Node3D
## Layered 2D artwork placed at several depths in the 3D arena.


func _ready() -> void:
	_connect_branch_webs()
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
	var left_anchors := _branch_anchors(left_branch)
	var right_anchors := _branch_anchors(right_branch)
	left_web.valid_nodes = left_anchors + right_anchors
	right_web.valid_nodes = right_anchors + left_anchors


func _branch_anchors(branch: Node3D) -> Array[Node3D]:
	var anchors: Array[Node3D] = []
	for node in branch.get_node("WebAnchors").get_children():
		if node is Marker3D:
			anchors.append(node)
	return anchors
