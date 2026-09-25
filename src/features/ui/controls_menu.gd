class_name ControlsMenu
extends Control
## Editable action catalog. Add or remove rows here when the jam game changes.

signal closed

const ACTIONS := [
	{ "name": "Pause", "action": "pause" },
]
const BINDING_ROW: PackedScene = preload("res://src/features/ui/control_binding_row.tscn")

@export var save_path: String = "user://input_bindings.cfg"

var _capture_action := ""
var _capture_device := ""
var _capture_slot := -1
var _buttons: Dictionary = {}

@onready var rows: VBoxContainer = $Center/Panel/Scroll/Rows
@onready var status_label: Label = $Center/Panel/Status


func _ready() -> void:
	visible = false
	_load_bindings()
	_build_rows()
	$Center/Panel/ResetButton.pressed.connect(reset_defaults)
	$Center/Panel/BackButton.pressed.connect(close_menu)


func _unhandled_input(event: InputEvent) -> void:
	if (visible and not event.is_echo()
			and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"))):
		close_menu()
		get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	if not visible or _capture_action.is_empty():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		get_viewport().set_input_as_handled()
		if event.keycode == KEY_ESCAPE or event.physical_keycode == KEY_ESCAPE:
			_cancel_capture()
			status_label.text = "Rebinding cancelled."
			return
		if _capture_device == "keyboard":
			var binding := InputEventKey.new()
			binding.physical_keycode = (
				event.physical_keycode if event.physical_keycode else event.keycode
			)
			_set_binding(binding)
	elif _capture_device == "gamepad" and event is InputEventJoypadButton and event.pressed:
		get_viewport().set_input_as_handled()
		var binding := InputEventJoypadButton.new()
		binding.button_index = event.button_index
		_set_binding(binding)
	elif (_capture_device == "gamepad"
			and event is InputEventJoypadMotion
			and absf(event.axis_value) > 0.7):
		get_viewport().set_input_as_handled()
		var binding := InputEventJoypadMotion.new()
		binding.axis = event.axis
		binding.axis_value = signf(event.axis_value)
		_set_binding(binding)


func open() -> void:
	visible = true
	status_label.text = " "
	$Center/Panel/BackButton.grab_focus()


func close_menu() -> void:
	_cancel_capture()
	visible = false
	closed.emit()


func _build_rows() -> void:
	for child in rows.get_children():
		child.queue_free()
	_buttons.clear()
	for entry in ACTIONS:
		var action: String = entry.action
		var row: HBoxContainer = BINDING_ROW.instantiate()
		rows.add_child(row)
		var label: Label = row.get_node("ActionLabel")
		label.text = entry.name
		for device in ["keyboard", "gamepad"]:
			for slot in 2:
				var button: Button = row.get_node("%s%d" % [device.capitalize(), slot])
				button.pressed.connect(_begin_capture.bind(action, device, slot))
				_buttons[_slot_key(action, device, slot)] = button
	_refresh_buttons()


func _begin_capture(action: String, device: String, slot: int) -> void:
	_capture_action = action
	_capture_device = device
	_capture_slot = slot
	status_label.text = "Press a %s input for %s (Esc cancels)." % [
		device,
		action.replace("_", " "),
	]
	_refresh_buttons()


func _cancel_capture() -> void:
	_capture_action = ""
	_capture_device = ""
	_capture_slot = -1
	_refresh_buttons()


func _set_binding(binding: InputEvent) -> void:
	for entry in ACTIONS:
		var action: String = entry.action
		if action == _capture_action:
			continue
		for existing in InputMap.action_get_events(action):
			if existing.is_match(binding, true):
				status_label.text = "That input is already used by %s." % entry.name
				return
	var events := InputMap.action_get_events(_capture_action)
	var matching_indices: Array[int] = []
	for index in events.size():
		if _is_device_event(events[index], _capture_device):
			matching_indices.append(index)
	if _capture_slot < matching_indices.size():
		events[matching_indices[_capture_slot]] = binding
	else:
		events.append(binding)
	InputMap.action_erase_events(_capture_action)
	for event in events:
		InputMap.action_add_event(_capture_action, event)
	_save_bindings()
	status_label.text = "%s binding updated." % _capture_action.replace("_", " ").capitalize()
	_cancel_capture()


func _is_device_event(event: InputEvent, device: String) -> bool:
	if device == "keyboard":
		return event is InputEventKey
	return event is InputEventJoypadButton or event is InputEventJoypadMotion


func _slot_key(action: String, device: String, slot: int) -> String:
	return "%s/%s/%d" % [action, device, slot]


func _refresh_buttons() -> void:
	for entry in ACTIONS:
		var action: String = entry.action
		for device in ["keyboard", "gamepad"]:
			_refresh_action_device(action, device)


func _refresh_action_device(action: String, device: String) -> void:
	var events: Array[InputEvent] = []
	for event in InputMap.action_get_events(action):
		if _is_device_event(event, device):
			events.append(event)
	for slot in 2:
		var button: Button = _buttons.get(_slot_key(action, device, slot))
		if button == null:
			continue
		if action == _capture_action and device == _capture_device and slot == _capture_slot:
			button.text = "Press input..."
		else:
			button.text = _event_name(events[slot]) if slot < events.size() else "+ Add"


func _event_name(event: InputEvent) -> String:
	if event is InputEventKey:
		return event.as_text().replace(" (Physical)", "")
	if event is InputEventJoypadMotion:
		var axis_name := "Left stick" if event.axis < 2 else "Right stick"
		var direction := "Left" if event.axis == 0 and event.axis_value < 0 else "Right"
		if event.axis % 2 == 1:
			direction = "Up" if event.axis_value < 0 else "Down"
		return "%s %s" % [axis_name, direction]
	if event is InputEventJoypadButton:
		var names := {
			0: "A / Cross",
			6: "Start",
			11: "D-pad Up",
			12: "D-pad Down",
			13: "D-pad Left",
			14: "D-pad Right",
		}
		return names.get(event.button_index, "Pad button %d" % event.button_index)
	return event.as_text()


func _load_bindings() -> void:
	var config := ConfigFile.new()
	var error := config.load(save_path)
	if error == ERR_FILE_NOT_FOUND:
		return
	if error != OK:
		push_warning("Could not load input bindings: %s" % error_string(error))
		return
	for entry in ACTIONS:
		var action: String = entry.action
		if not InputMap.has_action(action) or not config.has_section_key("bindings", action):
			continue
		var events: Variant = config.get_value("bindings", action)
		if not events is Array or events.is_empty():
			continue
		var valid := true
		for event in events:
			if (not event is InputEventKey
					and not event is InputEventJoypadButton
					and not event is InputEventJoypadMotion):
				valid = false
		if not valid:
			continue
		InputMap.action_erase_events(action)
		for event in events:
			InputMap.action_add_event(action, event)


func _save_bindings() -> void:
	var config := ConfigFile.new()
	for entry in ACTIONS:
		var action: String = entry.action
		config.set_value("bindings", action, InputMap.action_get_events(action))
	var error := config.save(save_path)
	if error != OK:
		push_warning("Could not save input bindings: %s" % error_string(error))


func reset_defaults() -> void:
	for entry in ACTIONS:
		var action: String = entry.action
		var setting: Dictionary = ProjectSettings.get_setting("input/" + action, {})
		InputMap.action_erase_events(action)
		for event in setting.get("events", []):
			InputMap.action_add_event(action, event)
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	_cancel_capture()
	status_label.text = "Default bindings restored."
