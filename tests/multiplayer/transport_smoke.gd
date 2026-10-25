extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var session := root.get_node("OnlineSession")
	var transport: Node = session.transport
	transport.send_to(-1, "snapshot", { "state": "x".repeat(70_000) })
	if session.state != "error" or not "too large" in session.message:
		push_error("TRANSPORT FAIL: Oversized state did not report an actionable failure")
		quit(1)
		return
	if not transport.sent_messages.is_empty():
		push_error("TRANSPORT FAIL: Oversized state was sent")
		quit(1)
		return
	session.leave_lobby()
	await process_frame
	await create_timer(0.2).timeout
	print("TRANSPORT PASS: oversized state fails visibly before sending")
	quit(0)
