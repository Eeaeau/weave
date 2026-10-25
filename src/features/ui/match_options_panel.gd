extends PanelContainer

signal drop_count_changed(value: int)

@onready var drop_count: SpinBox = %DropCount


func _ready() -> void:
	drop_count.value_changed.connect(func(value: float) -> void:
		drop_count_changed.emit(int(value)))


func set_values(values: Dictionary, can_edit: bool, note: String = "") -> void:
	drop_count.set_value_no_signal(values.drops)
	drop_count.editable = can_edit
	%SettingsNote.text = note


func get_values() -> Dictionary:
	return { "map": "canopy", "drops": int(drop_count.value) }
