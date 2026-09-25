extends SceneTree
## Verify the 2D starter's scene composition and inherited placeholders.


func _initialize() -> void:
	create_timer(30.0).timeout.connect(func() -> void: push_error("SMOKE TIMEOUT"); quit(2))
	call_deferred("_run")


func _run() -> void:
	var scene: PackedScene = load("res://src/game/web_match.tscn")
	if scene == null:
		_fail("Match scene did not load")
		return
	var match_scene: Node2D = scene.instantiate()
	root.add_child(match_scene)
	await process_frame
	if not match_scene is WebMatch2D:
		_fail("Match root is not 2D")
		return
	if not (_check_spiders(match_scene) and _check_map(match_scene)
			and _check_webs(match_scene) and _check_collectibles(match_scene)
			and _check_audio()):
		return
	match_scene.queue_free()
	await process_frame
	print("SMOKE PASS: 2D map, spiders, webs, collectible inheritance, and audio slots")
	quit(0)


func _check_spiders(match_scene: Node2D) -> bool:
	var player: PlayerSpider2D = match_scene.get_node("PlayerSpider")
	var opponent: OpponentSpider2D = match_scene.get_node("OpponentSpider")
	if not player is BaseSpider2D or not opponent is BaseSpider2D:
		return _fail("Spider scene inheritance is broken")
	return true


func _check_map(match_scene: Node2D) -> bool:
	var map: BranchCanopy2D = match_scene.get_node("BranchCanopy")
	if (map.get_node_or_null("PlayerBranchStart") == null
			or map.get_node_or_null("OpponentBranchStart") == null
			or map.get_node_or_null("BackgroundMusic") == null):
		return _fail("Map start markers or music slot are missing")
	return true


func _check_webs(match_scene: Node2D) -> bool:
	var strands := match_scene.get_node("StartingWebs").get_children()
	if strands.size() != 10:
		return _fail("Both starting webs should have five strands")
	for strand in strands:
		if not strand is WebStrand2D or strand.durability < 1:
			return _fail("Web strand placeholder is invalid")
	return true


func _check_collectibles(match_scene: Node2D) -> bool:
	var pebble: ThrownWeaponData = load("res://src/features/weapons/pebble.tres")
	var cutter: WebToolData = load("res://src/features/weapons/twig_cutter.tres")
	var moth: InsectData = load("res://src/features/insects/silk_moth.tres")
	var beetle: InsectData = load("res://src/features/insects/health_beetle.tres")
	var windborne_weapon: WindborneWeapon2D = match_scene.get_node("WindbornePebble")
	var windborne_insect: WindborneInsect2D = match_scene.get_node("WindborneMoth")
	if (not pebble is CollectibleData or not cutter is CollectibleData
			or not moth is CollectibleData or not beetle is CollectibleData):
		return _fail("Collectible data inheritance is broken")
	if (not windborne_weapon is Collectible2D or not windborne_insect is Collectible2D
			or windborne_weapon.collectible != pebble
			or windborne_insect.collectible != moth):
		return _fail("Collectible scene inheritance or data reference is broken")
	return true


func _check_audio() -> bool:
	if AudioServer.get_bus_index("Music") < 0 or AudioServer.get_bus_index("SFX") < 0:
		return _fail("Audio buses are missing")
	return true


func _fail(message: String) -> bool:
	push_error("SMOKE FAIL: " + message)
	quit(1)
	return false
