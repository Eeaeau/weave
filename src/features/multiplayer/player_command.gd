class_name PlayerCommand
extends RefCounted

const HELD_ACTIONS := [
	"move_left", "move_right", "move_up", "move_down",
	"aim_left", "aim_right", "action", "skip_wind",
]
const PACKET_KEYS := ["match", "turn", "seq", "actor", "held", "select", "cycle", "cancel",
	"aim", "charge"]
const AIM_PRECISION := 10_000.0
const MAX_TIMING_CORRECTION := 0.25

var held: int = 0
var selection: int = -1
var cycle: int = 0
var cancel: bool = false
var action_pressed: bool = false
var action_released: bool = false
var final_aim: float = NAN
var final_charge: float = -1.0


static func from_input() -> PlayerCommand:
	var command := PlayerCommand.new()
	for index in range(HELD_ACTIONS.size()):
		if (InputMap.has_action(HELD_ACTIONS[index])
				and Input.is_action_pressed(HELD_ACTIONS[index])):
			command.held |= 1 << index
	for index in range(5):
		if Input.is_action_just_pressed("select_%d" % (index + 1)):
			command.selection = index
	command.cycle = int(Input.is_action_just_pressed("cycle_silk_target_next")) \
		- int(Input.is_action_just_pressed("cycle_silk_target_previous"))
	command.cancel = Input.is_action_just_pressed("cancel_silk_build")
	command.action_pressed = Input.is_action_just_pressed("action")
	command.action_released = Input.is_action_just_released("action")
	return command


func is_pressed(action: String) -> bool:
	var index := HELD_ACTIONS.find(action)
	return index >= 0 and (held & (1 << index)) != 0


func movement_direction() -> Vector3:
	return Vector3(
		int(is_pressed("move_right")) - int(is_pressed("move_left")),
		int(is_pressed("move_up")) - int(is_pressed("move_down")), 0
	).normalized()


func to_packet(match_id: String, turn_id: int, sequence: int, actor_id: int) -> Dictionary:
	return {"match": match_id, "turn": turn_id, "seq": sequence, "actor": actor_id,
		"held": held, "select": selection, "cycle": cycle, "cancel": cancel,
		"aim": null if is_nan(final_aim) else int(round(final_aim * AIM_PRECISION)),
		"charge": -1 if final_charge < 0 else int(round(final_charge * AIM_PRECISION))}


static func from_packet(packet: Dictionary, previous_held: int) -> PlayerCommand:
	var command := PlayerCommand.new()
	command.held = packet.held
	command.selection = packet.select
	command.cycle = packet.cycle
	command.cancel = packet.cancel
	command.action_pressed = (command.held & 64) != 0 and (previous_held & 64) == 0
	command.action_released = (command.held & 64) == 0 and (previous_held & 64) != 0
	if command.action_released or ((previous_held & 48) != 0 and (command.held & 48) == 0):
		if packet.aim != null:
			command.final_aim = float(packet.aim) / AIM_PRECISION
	if command.action_released and packet.charge >= 0:
		command.final_charge = float(packet.charge) / AIM_PRECISION
	return command


static func validate_packet(packet: Variant, match_id: String, turn_id: int,
		actor_id: int, inventory_size: int) -> String:
	if not packet is Dictionary or packet.size() != PACKET_KEYS.size() \
			or not packet.has_all(PACKET_KEYS):
		return "Invalid command fields"
	for key in ["turn", "seq", "actor", "held", "select", "cycle"]:
		if not packet[key] is int:
			return "Invalid numeric field"
	if not packet.match is String or packet.match != match_id \
			or packet.turn != turn_id or packet.actor != actor_id:
		return "Wrong match, turn or actor"
	if packet.seq < 1 or packet.seq > 2_147_483_647 or packet.held < 0 or packet.held > 255 \
			or packet.select < -1 or packet.select >= inventory_size:
		return "Invalid sequence, held actions or inventory selection"
	if packet.cycle < -1 or packet.cycle > 1 or not packet.cancel is bool:
		return "Invalid targeting action"
	if (packet.aim != null and (not packet.aim is int or absi(packet.aim) > 100_000_000)) \
			or not packet.charge is int or packet.charge < -1 or packet.charge > 6_000_000:
		return "Invalid final aim or charge"
	return ""
