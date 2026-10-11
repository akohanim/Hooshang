extends Node
## The cage is a rescue milestone; the author's story continues outside it.
const TEXT := preload("res://resources/dialogue/act2_author_script.tres")
var world: Node
var playing := false
var finished := false
var actor: Jamshid
var _camera_bottom := 0

func _ready() -> void:
	world = get_parent()

func _physics_process(_delta: float) -> void:
	if playing or world.current_room == null: return
	finished = bool(world.story_flags.get("cell_reunion", false))
	if not world.rescued or world.current_room.name != "Prison_Hub": return
	actor = world._cage.get_parent().get_node("PrisonJamshid") as Jamshid
	if finished:
		actor.position.x = 90
		actor.face_left(false)
		return
	if not world._transitioning and world.player.is_on_floor(): play_scene()

func play_scene() -> void:
	if playing or finished: return
	playing = true
	Dialogue.begin_conversation(self, world.player)
	_camera_bottom = world.player.camera.limit_bottom
	world.player.camera.limit_bottom += 64
	world.player.camera.reset_smoothing()
	actor.face_left(true)
	for i in 9:
		if Dialogue.scene_skip_requested(self): break
		if i == 2:
			# The existing actor artwork has no embrace clip. Stage the reunion
			# with close silhouettes, without replacing either character drawing.
			await _animate(world.player, "global_position:x", actor.global_position.x - 9, 0.55)
			world.player.cutscene_rest(false, 1)
		var line: Dictionary = TEXT.scenes.cell[i]
		var is_child: bool = line.speaker == "HOOSHANG"
		await Dialogue.say(line.speaker.capitalize(), line.text, Color.WHITE,
			Act2Beats.CHILD_FACES.get(line.get("face","neutral"),Act2Beats.CHILD_FACES.neutral) if is_child else Jamshid.portrait(line.get("face","friendly")),
			DialogueBox.Side.LEFT if is_child else DialogueBox.Side.RIGHT,
			DialogueBox.VSide.BOTTOM)
	if not Dialogue.scene_skip_requested(self):
		actor.play_pose("walk")
		await _animate(actor, "position:x", 90.0, 1.6)
	_finish()

func _animate(node: Node, property: String, value: Variant, seconds: float) -> void:
	if Dialogue.scene_skip_requested(self): return
	var tween := create_tween()
	tween.tween_property(node, property, value, seconds)
	while tween.is_running() and not Dialogue.scene_skip_requested(self):
		await get_tree().process_frame
	if tween.is_valid(): tween.kill()

func _finish() -> void:
	actor.position.x = 90
	actor.face_left(false)
	actor.play_pose("idle")
	world.story_flags["cell_reunion"] = true
	finished = true
	playing = false
	world.player.camera.limit_bottom = _camera_bottom
	world.player.camera.reset_smoothing()
	Dialogue.end_conversation()
	world._refresh()
	SaveGame.save_now()
