extends RefCounted

const LOCAL_SETUP_META := &"local_match_options"


static func defaults() -> Dictionary:
	return { "map": "canopy", "drops": 3 }


static func valid(values: Variant) -> bool:
	return values is Dictionary and values.get("map") == "canopy" \
		and values.get("drops") is int and values.drops >= 1 and values.drops <= 12


static func queue_local(tree: SceneTree, values: Dictionary) -> bool:
	if not valid(values):
		return false
	tree.set_meta(LOCAL_SETUP_META, { "map": values.map, "drops": values.drops })
	return true


static func consume_local(tree: SceneTree) -> Dictionary:
	var values: Dictionary = tree.get_meta(LOCAL_SETUP_META, {})
	if tree.has_meta(LOCAL_SETUP_META):
		tree.remove_meta(LOCAL_SETUP_META)
	return values
