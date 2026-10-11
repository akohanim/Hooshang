extends Node2D
## Two separately staged encounters placed in LDtk: the arrest and palace gate.
const SCRIPT := preload("res://resources/dialogue/act2_author_script.tres")
const FACES := Act2Beats.CHILD_FACES
## Script chapter played by this authored encounter.
@export_enum("wall", "palace") var chapter := "wall"
var world: Node
var room: Node2D
var playing := false
var finished := false
var actor_clock := 0.0
var officer_walking := false
var _camera_bottom := 0
@onready var cousin: Jamshid = $Wall/Jamshid
@onready var officer: Sprite2D = $Wall/Principal
@onready var curtain: ColorRect = $Curtain/Fade

func _ready() -> void:
	room = get_parent().get_parent() as Node2D
	world = room
	while world != null and not world is LdtkWorld: world = world.get_parent()
	call_deferred("_restore")

func _restore() -> void:
	if world == null: return
	finished = bool(world.story_flags.get(chapter, false))
	$Wall.visible = chapter == "wall" and not finished
	$Banner.visible = chapter == "palace"
	$Banner.position.y = -96 if finished else -180
	cousin.face_left(true)

func _physics_process(delta: float) -> void:
	if playing and officer_walking:
		actor_clock += delta
		officer.frame = int(actor_clock * 8) % 4
	if finished or playing or world == null or world.current_room != room: return
	var at: Vector2 = to_local(world.player.global_position)
	if at.x >= 64 and world.player.is_on_floor() and not world._transitioning:
		play_scene()

func play_scene() -> void:
	if playing or finished: return
	playing = true
	Dialogue.begin_conversation(self, world.player)
	# Keep the actors above the bottom dialogue panel. The temporary lower
	# camera limit is restored for both normal completion and whole-scene skip.
	_camera_bottom = world.player.camera.limit_bottom
	world.player.camera.limit_bottom += 64
	world.player.camera.reset_smoothing()
	world.player.cancel_dialogue_motion()
	if chapter == "wall":
		world.player.global_position = global_position + Vector2(86,-6)
		world.player.cutscene_rest(false,1)
		await _wall()
	else:
		await _animate($Banner,"position:y",-96.0,0.6)
		$Banner/Quest.show()
		for line: Dictionary in SCRIPT.scenes.palace:
			if Dialogue.scene_skip_requested(self): break
			await _say(line)
	_finish()

func _wall() -> void:
	for i in SCRIPT.scenes.wall.size():
		if Dialogue.scene_skip_requested(self): return
		if i == 16:
			$Wall/Poem.show()
			$Wall/Poem.modulate.a = 0
			await _animate($Wall/Poem,"modulate:a",1.0,0.6)
		if i == 20:
			$Whistle.play()
			officer.show()
			officer_walking = true
			await _animate(officer,"position",Vector2(182,-32),0.65)
			officer_walking = false
			officer.frame = 0
			$Wall/Can.rotation = PI/2
			await _animate($Wall/Can,"position",Vector2(90,-3),0.15)
			$Clack.play()
		if i == 22:
			await _animate($Wall/OtherCan,"position:x",137.0,0.3)
		await _say(SCRIPT.scenes.wall[i])
	if Dialogue.scene_skip_requested(self): return
	cousin.face_left(false)
	cousin.play_pose("walk")
	officer_walking = true
	var escort := create_tween()
	escort.tween_property(officer,"position",Vector2(296,0),1.8)
	await _animate(cousin,"position",Vector2(310,0),1.8)
	if escort.is_valid(): escort.kill()
	if Dialogue.scene_skip_requested(self): return
	await _animate(curtain,"color:a",1.0,0.3)
	$Wall.hide()
	await _animate(curtain,"color:a",0.0,0.4)

func _say(line: Dictionary) -> void:
	if Dialogue.scene_skip_requested(self): return
	var speaker: String = line.speaker
	var face: Texture2D = null
	if speaker == "HOOSHANG": face = FACES.get(line.get("face","neutral"),FACES.neutral)
	if speaker == "JAMSHID": face = Jamshid.portrait(line.get("face","friendly"))
	await Dialogue.say(speaker.capitalize(),line.text,Color.WHITE if face != null else Color.TRANSPARENT,face,
		DialogueBox.Side.LEFT if speaker == "HOOSHANG" else DialogueBox.Side.RIGHT,
		DialogueBox.VSide.BOTTOM)

func _animate(node: Node, property: String, value: Variant, seconds: float) -> void:
	if Dialogue.scene_skip_requested(self): return
	var tween := create_tween()
	tween.tween_property(node,property,value,seconds)
	while tween.is_running() and not Dialogue.scene_skip_requested(self):
		await get_tree().process_frame
	if tween.is_valid(): tween.kill()

func _finish() -> void:
	officer_walking = false
	$Whistle.stop()
	$Clack.stop()
	curtain.color.a = 0
	$Wall.hide()
	$Banner/Quest.hide()
	if chapter == "palace": $Banner.position.y = -96
	world.story_flags[chapter] = true
	finished = true
	playing = false
	world.player.camera.limit_bottom = _camera_bottom
	world.player.camera.reset_smoothing()
	Dialogue.end_conversation()
	SaveGame.save_now()
