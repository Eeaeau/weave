class_name WindborneInsect3D
extends Collectible3D
## Shows the insect's benefit and lets the active spider eat nearby caught insects.


func _ready() -> void:
	super._ready()
	if not collectible is InsectData:
		return
	var data := collectible as InsectData
	var label := Label3D.new()
	label.name = "BenefitLabel"
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.pixel_size = 0.002
	label.font_size = 32
	label.offset = Vector2(0, 160)
	label.text = "+%d silk" % data.silk_amount if data.silk_amount > 0 else "Healing insect"
	label.modulate = Color(0.65, 1.0, 1.0) if data.silk_amount > 0 else Color(1.0, 0.5, 0.6)
	add_child(label)
	if data.health_amount > 0:
		$AnimatedMoth.modulate = Color(1.0, 0.5, 0.6)


func _physics_process(_delta: float) -> void:
	if not visible or pickup_area == null or not pickup_area.monitoring:
		return
	# A spider can become active while already overlapping this insect.
	for area in pickup_area.get_overlapping_areas():
		_area_entered(area)
		if not visible:
			return


func after_picked_up() -> void:
	super.after_picked_up()
	queue_free()
