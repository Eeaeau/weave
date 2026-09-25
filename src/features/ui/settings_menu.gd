class_name SettingsMenu
extends Control
## Reusable settings panel for title and pause menus.

signal closed
signal hints_changed(enabled: bool)

const WINDOW_SIZES := [
	Vector2i(800, 450),
	Vector2i(960, 540),
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
]

@export var save_path: String = "user://settings.cfg"

var _config := ConfigFile.new()
var _dirty := false
var _active_section := ""
var _last_section := "General"

@onready var hints_check: CheckButton = $GeneralPage/Center/Menu/HintsCheck
@onready var master_slider: HSlider = $AudioPage/Center/Menu/MasterSlider
@onready var music_slider: HSlider = $AudioPage/Center/Menu/MusicSlider
@onready var sfx_slider: HSlider = $AudioPage/Center/Menu/SfxSlider
@onready var display_mode_option: OptionButton = $DisplayPage/Center/Menu/DisplayModeOption
@onready var window_size_option: OptionButton = $DisplayPage/Center/Menu/WindowSizeOption
@onready var fps_limit_option: OptionButton = $DisplayPage/Center/Menu/FpsLimitOption


func _ready() -> void:
	visible = false
	var error := _config.load(save_path)
	if error != OK and error != ERR_FILE_NOT_FOUND:
		push_warning("Could not load settings: %s" % error_string(error))
	hints_check.set_pressed_no_signal(_config.get_value("general", "show_hints", true))
	_load_volume("Master", master_slider)
	_load_volume("Music", music_slider)
	_load_volume("SFX", sfx_slider)
	_populate_display_options()
	_load_display_options()
	master_slider.value_changed.connect(_on_volume_changed.bind("Master"))
	music_slider.value_changed.connect(_on_volume_changed.bind("Music"))
	sfx_slider.value_changed.connect(_on_volume_changed.bind("SFX"))
	display_mode_option.item_selected.connect(_on_display_mode_selected)
	window_size_option.item_selected.connect(_on_window_size_selected)
	fps_limit_option.item_selected.connect(_on_fps_limit_selected)
	hints_check.toggled.connect(_on_hints_toggled)
	$Hub/Center/Menu/GeneralButton.pressed.connect(_show_section.bind("General"))
	$Hub/Center/Menu/DisplayButton.pressed.connect(_show_section.bind("Display"))
	$Hub/Center/Menu/AudioButton.pressed.connect(_show_section.bind("Audio"))
	$Hub/Center/Menu/InputButton.pressed.connect(_show_section.bind("Input"))
	$Hub/Center/Menu/BackButton.pressed.connect(close_menu)
	$GeneralPage/Center/Menu/BackButton.pressed.connect(back)
	$DisplayPage/Center/Menu/BackButton.pressed.connect(back)
	$AudioPage/Center/Menu/BackButton.pressed.connect(back)
	$ControlsMenu.closed.connect(_show_hub)


func _unhandled_input(event: InputEvent) -> void:
	if $ControlsMenu.visible:
		return
	if visible and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause")):
		if not event.is_echo():
			back()
			get_viewport().set_input_as_handled()


func open() -> void:
	visible = true
	_show_hub()


func back() -> void:
	if $ControlsMenu.visible:
		$ControlsMenu.close_menu()
	elif not _active_section.is_empty():
		_show_hub()
	else:
		close_menu()


func close_menu() -> void:
	if _dirty:
		_save()
	visible = false
	closed.emit()


func _show_section(section: String) -> void:
	_active_section = section
	_last_section = section
	$Hub.visible = false
	$GeneralPage.visible = section == "General"
	$DisplayPage.visible = section == "Display"
	$AudioPage.visible = section == "Audio"
	match section:
		"General":
			hints_check.grab_focus()
		"Display":
			display_mode_option.grab_focus()
		"Audio":
			master_slider.grab_focus()
		"Input":
			$ControlsMenu.open()


func _show_hub() -> void:
	_active_section = ""
	$GeneralPage.visible = false
	$DisplayPage.visible = false
	$AudioPage.visible = false
	$Hub.visible = true
	$Hub/Center/Menu.get_node(_last_section + "Button").grab_focus()


func _on_hints_toggled(enabled: bool) -> void:
	_dirty = true
	hints_changed.emit(enabled)


func _load_volume(bus_name: String, slider: HSlider) -> void:
	var value: float = clampf(float(_config.get_value("audio", bus_name, 100.0)), 0.0, 100.0)
	slider.set_value_no_signal(value)
	_apply_volume(bus_name, value)


func _apply_volume(bus_name: String, value: float) -> void:
	var bus := AudioServer.get_bus_index(bus_name)
	if bus >= 0:
		AudioServer.set_bus_volume_linear(bus, value / 100.0)


func _on_volume_changed(value: float, bus_name: String) -> void:
	_dirty = true
	_apply_volume(bus_name, value)


func _populate_display_options() -> void:
	display_mode_option.add_item("Windowed", 0)
	display_mode_option.add_item("Borderless fullscreen", 1)
	if not OS.has_feature("web"):
		display_mode_option.add_item("Exclusive fullscreen", 2)
	var usable := DisplayServer.screen_get_usable_rect(get_window().current_screen).size
	for size in WINDOW_SIZES:
		if usable == Vector2i.ZERO or (size.x <= usable.x and size.y <= usable.y):
			_add_window_size(size)
	var current_size := get_window().size
	if usable == Vector2i.ZERO or (current_size.x <= usable.x and current_size.y <= usable.y):
		_add_window_size(current_size)
	if window_size_option.item_count == 0:
		_add_window_size(current_size)
	for limit in [0, 30, 60, 120, 144, 240]:
		fps_limit_option.add_item("No engine cap" if limit == 0 else "%d FPS" % limit, limit)
	var monitor_size := DisplayServer.screen_get_size(get_window().current_screen)
	if monitor_size != Vector2i.ZERO:
		$DisplayPage/Center/Menu/DisplayHint.text = "Fullscreen uses this monitor: %d × %d" % [
			monitor_size.x, monitor_size.y,
		]
	if OS.has_feature("web"):
		$DisplayPage/Center/Menu/DisplayHint.text = "Browser fullscreen starts when you choose it."


func _add_window_size(size: Vector2i) -> void:
	for index in window_size_option.item_count:
		if window_size_option.get_item_metadata(index) == size:
			return
	var index := window_size_option.item_count
	window_size_option.add_item("%d × %d" % [size.x, size.y])
	window_size_option.set_item_metadata(index, size)


func _load_display_options() -> void:
	var legacy_fullscreen: bool = _config.get_value("display", "fullscreen", false)
	var default_mode := 1 if legacy_fullscreen else 0
	var mode: int = clampi(int(_config.get_value("display", "mode", default_mode)), 0,
			display_mode_option.item_count - 1)
	if OS.has_feature("web"):
		mode = 0  # Browsers require a fresh user action to enter fullscreen.
	display_mode_option.select(mode)
	var saved_size: Variant = _config.get_value("display", "window_size", Vector2i(1280, 720))
	var size_index := _find_window_size(saved_size)
	window_size_option.select(size_index)
	var fps_limit: int = int(_config.get_value("display", "fps_limit", 0))
	var fps_index := fps_limit_option.get_item_index(fps_limit)
	fps_limit_option.select(maxi(fps_index, 0))
	_apply_display_mode(mode)
	_apply_fps_limit(fps_limit_option.get_selected_id())


func _find_window_size(size: Variant) -> int:
	for index in window_size_option.item_count:
		if window_size_option.get_item_metadata(index) == size:
			return index
	for index in window_size_option.item_count:
		if window_size_option.get_item_metadata(index) == Vector2i(1280, 720):
			return index
	return window_size_option.item_count - 1


func _apply_display_mode(mode: int) -> void:
	window_size_option.disabled = mode != 0 or OS.has_feature("web")
	if DisplayServer.get_name() == "headless":
		return
	match mode:
		0:
			get_window().mode = Window.MODE_WINDOWED
			_apply_window_size()
		1:
			get_window().mode = Window.MODE_FULLSCREEN
		2:
			get_window().mode = Window.MODE_EXCLUSIVE_FULLSCREEN


func _apply_window_size() -> void:
	if DisplayServer.get_name() == "headless" or OS.has_feature("web"):
		return
	var target_size: Vector2i = window_size_option.get_item_metadata(window_size_option.selected)
	get_window().size = target_size


func _apply_fps_limit(limit: int) -> void:
	Engine.max_fps = limit


func _on_display_mode_selected(index: int) -> void:
	_dirty = true
	_apply_display_mode(display_mode_option.get_item_id(index))


func _on_window_size_selected(_index: int) -> void:
	_dirty = true
	_apply_window_size()


func _on_fps_limit_selected(index: int) -> void:
	_dirty = true
	_apply_fps_limit(fps_limit_option.get_item_id(index))


func _save() -> void:
	_config.set_value("general", "show_hints", hints_check.button_pressed)
	_config.set_value("audio", "Master", master_slider.value)
	_config.set_value("audio", "Music", music_slider.value)
	_config.set_value("audio", "SFX", sfx_slider.value)
	_config.set_value("display", "mode", display_mode_option.get_selected_id())
	_config.set_value("display", "window_size",
			window_size_option.get_item_metadata(window_size_option.selected))
	_config.set_value("display", "fps_limit", fps_limit_option.get_selected_id())
	var error := _config.save(save_path)
	if error != OK:
		push_warning("Could not save settings: %s" % error_string(error))
	else:
		_dirty = false
