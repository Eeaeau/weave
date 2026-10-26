extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var path := "res://src/features/multiplayer/command_authority.gd"
	if not FileAccess.file_exists(path):
		_fail("Host command authority is missing")
		return
	var authority = load(path).new()
	authority.set_turn("match", 3, 1, 21)
	var codec = load("res://src/features/multiplayer/player_command.gd")
	var command = codec.new()
	command.held = 65
	var packet: Dictionary = command.to_packet("match", 3, 1, 1)
	if authority.accept(20, packet, 2).accepted or authority.held != 0:
		_fail("A different client controlled the active spider")
		return
	if not authority.accept(21, packet, 2).accepted or not authority.has_pending():
		_fail("The active team's command was rejected")
		return
	var accepted = authority.take_command()
	if not accepted.action_pressed or not accepted.is_pressed("move_left") \
			or authority.accept(21, packet, 2).accepted:
		_fail("A command edge was lost or a duplicate was executed twice")
		return
	accepted = authority.take_command()
	if accepted.action_pressed or not accepted.is_pressed("move_left"):
		_fail("Held movement did not continue without repeating its press edge")
		return
	packet.seq = 2
	packet.held = 0
	authority.accept(21, packet, 2)
	authority.set_turn("match", 4, 2, 20)
	if authority.held != 0 or authority.has_pending() or authority.accept(21, packet, 2).accepted \
			or authority.take_command().action_released:
		_fail("Held input or a stale command crossed the turn boundary")
		return
	print("COMMAND AUTHORITY PASS: actual sender, turn, sequence and input edge ownership")
	quit(0)


func _fail(reason: String) -> void:
	push_error("COMMAND AUTHORITY FAIL: " + reason)
	quit(1)
