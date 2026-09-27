extends SceneTree
## Verify the moth uses the packed, looping flight animation.

const MOTH_SCENE_PATH := "res://src/features/collectibles/insects/windborne_insect.tscn"
const ATLAS_PATH := (
	"res://src/features/collectibles/insects/assets/moth_flight_strip.png"
)
const EXPECTED_REGIONS := [
	Rect2(0, 0, 512, 512),
	Rect2(512, 0, 512, 512),
	Rect2(1024, 0, 512, 512),
	Rect2(512, 0, 512, 512),
]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := load(MOTH_SCENE_PATH) as PackedScene
	var insect := scene.instantiate() as WindborneInsect3D
	root.add_child(insect)
	await process_frame
	var moth := insect.get_node_or_null("AnimatedMoth") as AnimatedSprite3D
	if moth == null or insect.get_node_or_null("Sprite3D") != null:
		_fail("The moth placeholder must be replaced by an AnimatedSprite3D")
		return
	var frames := moth.sprite_frames
	if (frames == null or not frames.has_animation(&"flight")
			or frames.get_frame_count(&"flight") != 4
			or not is_equal_approx(frames.get_animation_speed(&"flight"), 8.0)
			or not frames.get_animation_loop(&"flight")
			or moth.autoplay != &"flight"):
		_fail("Moth must autoplay a looping four-step flight animation")
		return
	for frame_index in frames.get_frame_count(&"flight"):
		var frame := frames.get_frame_texture(&"flight", frame_index) as AtlasTexture
		if (frame == null or frame.atlas == null
				or frame.atlas.resource_path != ATLAS_PATH
				or frame.region != EXPECTED_REGIONS[frame_index]):
			_fail("Moth frames must use the packed ping-pong flight strip")
			return
	var initial_frame := moth.frame
	await create_timer(0.2).timeout
	if moth.animation != &"flight" or moth.frame == initial_frame:
		_fail("Moth flight animation must advance while it is in the scene tree")
		return
	insect.queue_free()
	await process_frame
	print("MOTH VISUAL PASS: packed ping-pong flight animation")
	quit(0)


func _fail(message: String) -> void:
	push_error("MOTH VISUAL FAIL: " + message)
	quit(1)
