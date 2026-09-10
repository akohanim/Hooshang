extends Control
## Standalone art audition. No world, save slot, or story state is changed.

const ACTOR := preload("res://scenes/characters/jamshid/Jamshid.tscn")
const PORTRAIT_KEYS := ["friendly", "joyful", "worried", "sad", "determined"]
var actors: Array[Node2D] = []
var portrait_views: Array[TextureRect] = []
var clock := 0.0


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("242320"))
	var title := Label.new()
	title.text = "JAMSHID  /  Hooshang's best friend and cousin"
	title.position = Vector2(24, 14)
	add_child(title)
	for i in PORTRAIT_KEYS.size():
		var face := TextureRect.new()
		face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		face.texture = Jamshid.portrait(PORTRAIT_KEYS[i]).duplicate()
		face.position = Vector2(24 + 245 * i, 55)
		face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		face.size = Vector2(225, 300)
		face.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(face)
		face.set_deferred("size", Vector2(225, 300))
		portrait_views.append(face)
		var label := Label.new()
		label.text = PORTRAIT_KEYS[i].to_upper()
		label.position = Vector2(95 + 245 * i, 365)
		add_child(label)
	var poses := ["idle", "walk", "sit", "jump"]
	for i in poses.size():
		var actor := ACTOR.instantiate()
		actor.standing_height = 180
		actor.initial_pose = poses[i]
		actor.position = Vector2(160 + i * 315, 640)
		add_child(actor)
		actors.append(actor)
		var label := Label.new()
		label.text = poses[i].to_upper()
		label.position = Vector2(140 + i * 315, 662)
		add_child(label)
	var timer := Timer.new()
	timer.wait_time = 2.2
	timer.autostart = true
	timer.timeout.connect(func(): actors[3].play_pose("jump"))
	add_child(timer)
	if "--capture" in OS.get_cmdline_user_args():
		_capture.call_deferred()


func _capture() -> void:
	await get_tree().create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://assets/characters/jamshid/preview.png")
	get_tree().quit()


func _process(delta: float) -> void:
	clock += delta
	# Audition rest, talk, rest, blink. The real DialogueBox instead drives
	# these roles from typewriter activity and its independent blink clock.
	var phase := fmod(clock, 5.0)
	var frame := 0
	if phase > 1.0 and phase < 3.0:
		frame = 1 + int(clock * 8) % 2
	elif phase > 4.0 and phase < 4.15:
		frame = 3
	for view in portrait_views:
		var atlas := view.texture as AtlasTexture
		atlas.region.position.x = frame * atlas.region.size.x
