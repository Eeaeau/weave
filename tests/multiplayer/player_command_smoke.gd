extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var path := "res://src/features/multiplayer/player_command.gd"
	if not FileAccess.file_exists(path):
		_fail("Shared player command codec is missing")
		return
	var codec = load(path)
	var command = codec.new()
	command.held = 65
	command.selection = 2
	command.cycle = -1
	var packet: Dictionary = command.to_packet("match", 7, 4, 1)
	if codec.validate_packet(packet, "match", 7, 1, 3) != "":
		_fail("A valid player command was rejected")
		return
	var decoded = codec.from_packet(packet, 0)
	if not decoded.action_pressed or not decoded.is_pressed("move_left") \
			or decoded.selection != 2 or decoded.cycle != -1:
		_fail("Decoding did not preserve the action")
		return
	var released = codec.from_packet(codec.new().to_packet("match", 7, 5, 1), 64)
	if not released.action_released:
		_fail("Release was not derived from the previous held state")
		return
	var precise_release: Dictionary = packet.duplicate()
	precise_release.merge({ "held": 0, "aim": 6000, "charge": 10_000 }, true)
	var precise = codec.from_packet(precise_release, 80)
	if codec.validate_packet(precise_release, "match", 7, 1, 3) != "" \
			or precise.get("final_aim") != 0.6 or precise.get("final_charge") != 1.0:
		_fail("Final aim and charge did not survive command encoding")
		return
	var invalid_cases := [
		{ "match": "other" }, { "turn": 6 }, { "actor": 0 }, { "seq": -1 },
		{ "held": -1 }, { "held": 256 }, { "held": NAN }, { "held": true },
		{ "select": 3 }, { "cycle": 2 }, { "cancel": "true" }, { "extra": 1 },
		{ "aim": NAN }, { "aim": true }, { "charge": 1.5 }, { "charge": 6_000_001 },
	]
	for changes in invalid_cases:
		var invalid := packet.duplicate()
		invalid.merge(changes, true)
		if codec.validate_packet(invalid, "match", 7, 1, 3) == "":
			_fail("Invalid command accepted: %s" % changes)
			return
	print("PLAYER COMMAND PASS: bounded actions, identities, selection and edge decoding")
	quit(0)


func _fail(reason: String) -> void:
	push_error("PLAYER COMMAND FAIL: " + reason)
	quit(1)
