extends Node2D
## A cousin who waits, never a lethal pursuit. Waiting points live in LDtk.
const TEXT := preload("res://resources/dialogue/act2_author_script.tres")
## Horizontal distance that invites Jamshid to run to his next waiting point.
@export var follow_distance := 64.0
## Duration of a short playful hop between authored waiting points.
@export var hop_seconds := 0.75
var world: Node
var room: Node2D
var guides: Array[Node2D] = []
var index := 0
var moving := false
var playing := false
var was_active := false
var tween: Tween
var origin := Vector2.ZERO
var target := Vector2.ZERO
var camera_bottom := 0
var homes: Array[Vector2] = []
var generation := 0
## The script's chase is one scene played in two places: the banter on the run,
## then the unfinished wall where Jamshid stops. This is where the wall starts.
var at_wall := 0

func _ready() -> void:
	at_wall = TEXT.cue("chase", "We never finished it.")
	room = get_parent()
	world = room.get_parent()
	while world != null and not world is LdtkWorld: world = world.get_parent()
	room.set_meta("return_at_spawn_edge", true)
	for node in room.get_node("Entities").get_children():
		if node.has_meta("chase_guide"): guides.append(node)
		var sign := node.get_node_or_null("ExitSign")
		if sign != null: sign.hide()
	guides.sort_custom(func(a,b): return a.position.x < b.position.x)
	for guide in guides:
		homes.append(guide.position)
		guide.hide()
	world.player.died.connect(_reset_guide)
	room.get_node("CastleBackground").modulate = Color(0.64,0.57,0.52)
	$Wall.visible = room.fields.get("wing", "") == "EscapeWall"

func _physics_process(_delta: float) -> void:
	if world == null or guides.is_empty(): return
	var active: bool = world.current_room == room and world.player.state != Player.State.DEAD
	if not active:
		if was_active: _reset_guide()
		was_active = false
		return
	if not was_active:
		was_active = true
		index = 0
		for guide in guides: guide.hide()
		guides[0].show()
		guides[0].face_left(true)
	if playing or moving or world._transitioning or world.player.input_locked: return
	var x: float = world.player.global_position.x - room.global_position.x
	if room.name == "Act_2_Level_16" and x >= 88 and world.player.is_on_floor() and not world.story_flags.get("chase_banter",false):
		_conversation("chase_banter",0,at_wall)
		return
	if room.name == "Act_2_Level_19" and x >= 232 and world.player.is_on_floor() and not world.story_flags.get("wall_reunion",false):
		_conversation("wall_reunion",at_wall,TEXT.scenes.chase.size())
		return
	var entry_x: float = world.spawn_point_for(room).x-room.global_position.x
	if x > entry_x+24 and index < guides.size()-1 and x >= guides[index].position.x-follow_distance:
		_hop()

func _hop() -> void:
	moving = true
	var guide := guides[index]
	origin = guide.position
	target = guides[index+1].position
	guide.face_left(false)
	guide.play_pose("jump")
	tween = create_tween()
	tween.tween_method(_hop_at,0.0,1.0,hop_seconds)
	var revision := generation
	while tween.is_running() and revision == generation:
		await get_tree().process_frame
	if revision != generation: return
	guide.position = origin
	guide.hide()
	index += 1
	guides[index].show()
	guides[index].play_pose("idle")
	guides[index].face_left(true)
	moving = false

func _reset_guide() -> void:
	generation += 1
	if tween != null and tween.is_valid(): tween.kill()
	moving = false
	was_active = false
	index = 0
	for i in guides.size():
		guides[i].position = homes[i]
		guides[i].play_pose("idle")
		guides[i].hide()

func _hop_at(t: float) -> void:
	guides[index].position = origin.lerp(target,t) + Vector2(0,-sin(t*PI)*32)

func _conversation(flag: String, first: int, end: int) -> void:
	playing = true
	Dialogue.begin_conversation(self,world.player)
	camera_bottom = world.player.camera.limit_bottom
	world.player.camera.limit_bottom += 64
	world.player.camera.reset_smoothing()
	for i in range(first,end):
		if Dialogue.scene_skip_requested(self): break
		var line: Dictionary = TEXT.scenes.chase[i]
		var child: bool = line.speaker == "HOOSHANG"
		await Dialogue.say(line.speaker.capitalize(),line.text,Color.WHITE,
			Act2Beats.CHILD_FACES.get(line.get("face","neutral"),Act2Beats.CHILD_FACES.neutral) if child else Jamshid.portrait(line.get("face","friendly")),
			DialogueBox.Side.LEFT if child else DialogueBox.Side.RIGHT,DialogueBox.VSide.BOTTOM)
	world.story_flags[flag] = true
	world.player.camera.limit_bottom = camera_bottom
	world.player.camera.reset_smoothing()
	Dialogue.end_conversation()
	playing = false
	SaveGame.save_now()
