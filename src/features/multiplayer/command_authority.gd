class_name CommandAuthority
extends RefCounted

const COMMAND := preload("res://src/features/multiplayer/player_command.gd")
const MAX_PENDING := 32

var held := 0
var _match_id := ""
var _turn_id := -1
var _actor_id := -1
var _owner_id := -1
var _sequence := 0
var _pending: Array[PlayerCommand] = []


func set_turn(match_id: String, turn_id: int, actor_id: int, owner_id: int) -> void:
	_match_id = match_id
	_turn_id = turn_id
	_actor_id = actor_id
	_owner_id = owner_id
	_sequence = 0
	held = 0
	_pending.clear()


func accept(sender_id: int, packet: Variant, inventory_size: int) -> Dictionary:
	var reason := ""
	if sender_id != _owner_id:
		reason = "It is another player's turn"
	else:
		reason = COMMAND.validate_packet(packet, _match_id, _turn_id, _actor_id, inventory_size)
	if reason.is_empty() and packet.seq <= _sequence:
		reason = "Duplicate or stale command"
	if reason.is_empty() and _pending.size() >= MAX_PENDING:
		reason = "Too many pending commands"
	if reason.is_empty():
		_pending.append(COMMAND.from_packet(packet, held))
		held = packet.held
		_sequence = packet.seq
	return { "accepted": reason.is_empty(), "reason": reason }


func take_command() -> PlayerCommand:
	if not _pending.is_empty():
		return _pending.pop_front()
	var command := COMMAND.new()
	command.held = held
	return command


func has_pending() -> bool:
	return not _pending.is_empty()
