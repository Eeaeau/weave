extends Node

signal received(sender: int, kind: String, payload: Dictionary)
signal packet_too_large(kind: String, byte_count: int)

const MAX_PACKET_BYTES := 65_536
const KINDS := ["prepare", "scene_ready", "snapshot", "snapshot_ack", "start", "command",
	"command_ack", "events", "state_ack", "recover", "wind", "wind_contact", "wind_skip",
	"projectile", "flame", "return_lobby"]

var sent_messages: Dictionary = {}
var sent_bytes: Dictionary = {}
var received_messages: Dictionary = {}


func _ready() -> void:
	GDSync.expose_func(_receive)


func send_to(peer: int, kind: String, payload: Dictionary) -> void:
	var byte_count := var_to_bytes([kind, payload]).size()
	if kind not in KINDS:
		return
	if byte_count > MAX_PACKET_BYTES:
		packet_too_large.emit(kind, byte_count)
		return
	if not GDSync.is_active():
		return
	sent_messages[kind] = sent_messages.get(kind, 0) + 1
	sent_bytes[kind] = sent_bytes.get(kind, 0) + byte_count
	GDSync.call_func_on(peer, _receive, kind, payload.duplicate(true))


func broadcast(kind: String, payload: Dictionary) -> void:
	for peer in GDSync.lobby_get_all_clients():
		if peer != GDSync.get_client_id():
			send_to(peer, kind, payload)


func _receive(kind: Variant, payload: Variant) -> void:
	if not kind is String or kind not in KINDS or not payload is Dictionary:
		return
	if var_to_bytes([kind, payload]).size() > MAX_PACKET_BYTES:
		return
	received_messages[kind] = received_messages.get(kind, 0) + 1
	received.emit(GDSync.get_sender_id(), kind, payload)
