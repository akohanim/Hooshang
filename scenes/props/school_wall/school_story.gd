extends Node2D
## Two separately staged encounters placed in LDtk: the arrest and palace gate.
const SCRIPT := preload("res://resources/dialogue/act2_author_script.tres")
const FACES := Act2Beats.CHILD_FACES
const OFFICER_FACES := {
	"alarmed": preload("res://assets/characters/officer/portraits/officer_alarmed.png"),
	"angry": preload("res://assets/characters/officer/portraits/officer_angry.png"),
	"stern": preload("res://assets/characters/officer/portraits/officer_stern.png"),
}
## Script chapter played by this authored encounter.
@export_enum("wall", "palace") var chapter := "wall"
var world: Node
var room: Node2D
var playing := false
var finished := false
var officer_walking := false
var officer_speaking := false
var _camera_bottom := 0
@onready var cousin: Jamshid = $Wall/Jamshid
@onready var officer: AnimatedSprite2D = $Wall/Principal
@onready var curtain: ColorRect = $Curtain/Fade
@onready var painting_game: Node2D = $Wall/Painting

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
	cousin.play_pose("idle")
	queue_redraw()

func _draw() -> void:
	if chapter != "wall": return
	# A full-width pavement keeps the arrival, mural, and exit on one ground plane.
	draw_rect(Rect2(0, 0, 640, 40), Color("8b806e"))
	draw_rect(Rect2(0, 0, 640, 3), Color("d9c9a5"))
	for x in range(0, 640, 32):
		draw_line(Vector2(x, 4), Vector2(x - 5, 40), Color("766e60"), 1)

func _physics_process(_delta: float) -> void:
	if playing and officer.visible:
		var clip: StringName = &"walk" if officer_walking else &"idle"
		if officer_speaking and Dialogue._revealing and Dialogue._pause_left <= 0.0 and not officer_walking:
			clip = &"talk"
		if officer.animation != clip: officer.play(clip)
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
		_size_officer_to_player()
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

func _size_officer_to_player() -> void:
	var child: AnimatedSprite2D = world.player.visual
	var child_art := child.sprite_frames.get_frame_texture("idle", 0).get_image()
	var officer_art := officer.sprite_frames.get_frame_texture("idle", 0).get_image()
	var child_height := child_art.get_used_rect().size.y * absf(child.scale.y)
	var officer_height := float(officer_art.get_used_rect().size.y)
	# Match visible silhouettes, not the transparent 88px/48px canvas sizes.
	officer.scale = Vector2.ONE * (child_height * 2.0 / officer_height)

func _wall() -> void:
	var lines: Array = SCRIPT.scenes.wall
	# Each beat is staged just BEFORE the line it is anchored to (Act2Script.cue).
	var mural: int = SCRIPT.cue("wall", "Your moustache")
	var painting_break: int = SCRIPT.cue("wall", "We should go")
	var poem: int = SCRIPT.cue("wall", "\"This world is a prison")
	var whistle: int = SCRIPT.cue("wall", "Hey!")
	var can_drops: int = SCRIPT.cue("wall", "Who painted")
	var hooks_cans: int = SCRIPT.cue("wall", "Me.")
	var led_away: int = SCRIPT.cue("wall", "How long")
	for i in lines.size():
		if Dialogue.scene_skip_requested(self): return
		if i == mural:
			# Jamshid starts the mural; Hooshang must add the later marks.
			$Wall/Graffiti.stage = 1
			cousin.play_pose("idle")
			await get_tree().create_timer(0.35).timeout
		if i == painting_break:
			await _painting_break()
			if Dialogue.scene_skip_requested(self): return
		if i == poem:
			$Wall/Poem.show()
			$Wall/Poem.modulate.a = 0
			await _animate($Wall/Poem,"modulate:a",1.0,0.6)
		if i == whistle:
			$Whistle.play()
			officer.show()
			officer.flip_h = false
			officer_walking = true
			await _animate(officer,"position",Vector2(182,0),0.65)
			officer_walking = false
			officer.frame = 0
		if i == can_drops:
			# The shout is what opens Hooshang's hand.
			$Wall/Can.rotation = PI/2
			await _animate($Wall/Can,"position",Vector2(90,-3),0.15)
			$Clack.play()
		if i == hooks_cans:
			await _animate($Wall/OtherCan,"position:x",137.0,0.3)
		if i == led_away:
			# Jamshid is marched off before Hooshang finds his words.
			cousin.face_left(false)
			cousin.play_pose("walk")
			officer_walking = true
			officer.flip_h = true
			var escort := create_tween()
			escort.tween_property(officer,"position",Vector2(296,0),1.8)
			await _animate(cousin,"position",Vector2(310,0),1.8)
			if escort.is_valid(): escort.kill()
			officer_walking = false
			cousin.play_pose("idle")
			if Dialogue.scene_skip_requested(self): return
		await _say(lines[i])
	if Dialogue.scene_skip_requested(self): return
	await _animate(curtain,"color:a",1.0,0.3)
	$Wall.hide()
	await _animate(curtain,"color:a",0.0,0.4)

func _painting_break() -> void:
	cousin.play_pose("idle")
	world.player.camera.limit_bottom = _camera_bottom
	world.player.camera.reset_smoothing()
	# X belongs to spraying here. Z/Y keeps a deliberate whole-scene skip.
	Dialogue.release_player_for_interaction(self, &"glow")
	await painting_game.play(world.player, $Wall/Graffiti, $Wall/Can, cousin, self)
	Dialogue.hold_player_after_interaction(self, world.player)
	world.player.camera.limit_bottom = _camera_bottom + 64
	world.player.camera.reset_smoothing()
	if Dialogue.scene_skip_requested(self): return
	# Walk back into the dialogue composition only after the player finishes.
	world.player.cutscene_rest(false, -1 if world.player.global_position.x > global_position.x + 86 else 1)
	world.player.visual.play("run")
	await _animate(world.player, "global_position", global_position + Vector2(86, -6), 0.35)
	world.player.cutscene_rest(false, 1)
	$Wall/Can.position = Vector2(91, -13)
	$Wall/Can.show()

func _say(line: Dictionary) -> void:
	if Dialogue.scene_skip_requested(self): return
	var speaker: String = line.speaker
	officer_speaking = speaker == "OFFICER"
	var face: Texture2D = null
	if speaker == "HOOSHANG": face = FACES.get(line.get("face","neutral"),FACES.neutral)
	if speaker == "JAMSHID": face = Jamshid.portrait(line.get("face","friendly"))
	if speaker == "OFFICER": face = OFFICER_FACES.get(line.get("face", "stern"), OFFICER_FACES.stern)
	await Dialogue.say(speaker.capitalize(),line.text,Color.WHITE if face != null else Color.TRANSPARENT,face,
		DialogueBox.Side.LEFT if speaker == "HOOSHANG" else DialogueBox.Side.RIGHT,
		DialogueBox.VSide.BOTTOM)
	officer_speaking = false

func _animate(node: Node, property: String, value: Variant, seconds: float) -> void:
	if Dialogue.scene_skip_requested(self): return
	var tween := create_tween()
	tween.tween_property(node,property,value,seconds)
	while tween.is_running() and not Dialogue.scene_skip_requested(self):
		await get_tree().process_frame
	if tween.is_valid(): tween.kill()

func _finish() -> void:
	painting_game.active = false
	painting_game.get_node("HUD/Panel").hide()
	cousin.play_pose("idle")
	officer_walking = false
	officer_speaking = false
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
