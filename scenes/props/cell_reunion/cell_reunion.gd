extends Node
## The cage is a rescue milestone; the author's story continues outside it.
const TEXT := preload("res://resources/dialogue/act2_author_script.tres")
var world: Node
var playing := false
var finished := false
var actor: Jamshid
var _camera_bottom := 0
## Stop on the main floor before the lower-left doorway's open well (x80–120).
@export var passage_x := 132.0
var _signage: Dictionary = {}

func _ready() -> void:
	world = get_parent()

func _physics_process(_delta: float) -> void:
	if playing or world.current_room == null: return
	finished = bool(world.story_flags.get("cell_reunion", false))
	if not world.rescued and world.collected.size() == 4 and not world.story_flags.get("keys_found",false):
		if not world._transitioning and not world.player.input_locked and world.player.is_on_floor():
			_key_reaction()
		return
	if not world.rescued or world.current_room.name != "Prison_Hub": return
	actor = world._cage.get_parent().get_node("PrisonJamshid") as Jamshid
	if finished:
		actor.position.x = passage_x
		actor.face_left(false)
		return
	# Do not summon the reunion from another balcony or the far side of the hall.
	# Both bodies must share the cell's floor before the close approach begins.
	if not world._transitioning and not world.player.input_locked and world.player.is_on_floor() \
			and absf(world.player.hitbox_rect().end.y-actor.global_position.y)<2.0 \
			and absf(world.player.global_position.x-actor.global_position.x)<112.0:
		play_scene()

## The author's fourth-key promise belongs on safe ground, once, before rescue.
func _key_reaction() -> void:
	playing = true
	_quiet_signage()
	Dialogue.begin_conversation(self,world.player)
	for line: Dictionary in TEXT.scenes.keys:
		await Dialogue.say("Hooshang",line.text,Color.WHITE,Act2Beats.CHILD_FACES.happy,
			DialogueBox.Side.LEFT,DialogueBox.VSide.TOP)
	world.story_flags["keys_found"] = true
	Dialogue.end_conversation()
	_restore_signage()
	playing = false
	SaveGame.save_now()

func play_scene() -> void:
	if playing or finished: return
	playing = true
	_quiet_signage()
	Dialogue.begin_conversation(self, world.player)
	_camera_bottom = world.player.camera.limit_bottom
	world.player.camera.limit_bottom += 64
	world.player.camera.reset_smoothing()
	actor.face_left(true)
	var hug: int = TEXT.cue("cell", "Come on. Let's go.")
	for i in TEXT.scenes.cell.size():
		if Dialogue.scene_skip_requested(self): break
		if i == hug:
			# The existing actor artwork has no embrace clip. Stage the reunion
			# with close silhouettes, without replacing either character drawing.
			world.player.look(1 if actor.global_position.x > world.player.global_position.x else -1)
			world.player.visual.play("run")
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
		await _animate(actor, "position:x", passage_x, 1.6)
	_finish()

func _animate(node: Node, property: String, value: Variant, seconds: float) -> void:
	if Dialogue.scene_skip_requested(self): return
	var tween := create_tween()
	tween.tween_property(node, property, value, seconds)
	while tween.is_running() and not Dialogue.scene_skip_requested(self):
		await get_tree().process_frame
	if tween.is_valid(): tween.kill()

func _finish() -> void:
	actor.position.x = passage_x
	actor.face_left(false)
	actor.play_pose("idle")
	world.story_flags["cell_reunion"] = true
	finished = true
	playing = false
	world.player.camera.limit_bottom = _camera_bottom
	world.player.camera.reset_smoothing()
	Dialogue.end_conversation()
	_restore_signage()
	world._refresh()
	SaveGame.save_now()

func _quiet_signage() -> void:
	if world._hud!=null:
		_signage[world._hud]=world._hud.visible
		world._hud.hide()
	for prop in world.props:
		if prop.kind=="PrisonSign" and world.current_room.is_ancestor_of(prop):
			_signage[prop]=prop.visible
			prop.hide()

func _restore_signage() -> void:
	for item in _signage:
		if is_instance_valid(item): item.visible=_signage[item]
	_signage.clear()
