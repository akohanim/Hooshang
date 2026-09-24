class_name JamshidNpc
extends Node2D
## Jamshid standing in a room, greeting Hooshang when he comes near.
##
## The visual actor (Jamshid.tscn / jamshid.gd) is deliberately kept as a dumb
## sprite that only knows how to hold a pose — this is the node that gives him a
## PLACE in the world and something to say. Dropped into a room as an LDtk
## `Jamshid` entity and built by scripts/ldtk_entities_post_import.gd; the words
## and the reach are its two LDtk fields, so moving him or rewriting his line
## never touches code.
##
## PROXIMITY, not an Area2D. "Within 50px of Jamshid" is a distance, and a
## distance is what this measures — polled every physics frame, the same "asked
## fresh every frame" shape Key's own deliver_radius uses (scenes/props/key.gd)
## and for the same reason SlideZone/Ladder/Pond poll their overlaps: a
## checkpoint respawn, a room loading with him already standing there and the
## frame after a teleport all have to work with no boundary ever crossed. A
## CircleShape2D would also have measured to the edge of his HITBOX rather than
## to him, which is a different number than the one written down.

## Fired the moment Hooshang comes within reach, before anything is said. A
## cutscene director (scripts/act2_beats.gd) connects to this to stage a bigger
## beat than a one-line greeting — the same defer_to_cutscene + triggered split
## LdtkRumiTrigger uses for Act 1.
signal triggered(player: Player)

## What he says, as a SCRIPT rather than a line: one spoken line per line of
## text, played a button press at a time. Set from LDtk's `DialogueLine`.
##
## A line may open with a PORTRAIT STATE in parentheses — `(excited)`,
## `(worried)` — naming which of Jamshid.FACES he wears for it, and may carry a
## speaker heading ("JAMSHID — ") so a script can be pasted in exactly as it was
## written. Both are read and stripped, never printed. See
## scripts/dialogue_script.gd, which does the reading and which Rumi's own
## trigger shares.
@export_multiline var dialogue_line: String = ""

## How close, in px, Hooshang has to come before the greeting starts. Measured
## between the two origins — his is the middle of his 9x12 box, Jamshid's is his
## feet — so this is roughly "close enough to talk to", not a hitbox overlap.
@export var trigger_radius := 50.0

## When a cutscene owns this encounter, it sets this so the NPC does not play
## its own one-line greeting — it just emits `triggered` and steps aside. Set
## from code (the director that takes over), not from LDtk: which encounters are
## scripted is a story fact, not level data.
@export var defer_to_cutscene := false

## Which face he wears for a line that names none of its own. Falls back to
## Jamshid.FACES' own default if this is not a state he has.
@export var default_face := "friendly"

## Face left. Every source frame faces right, so this is the mirror — set it for
## a Jamshid the player walks up to from the left, which is most of them.
@export var facing_left := false

## Which pose he holds while waiting. "sit" is the other useful one.
@export_enum("idle", "walk", "sit") var idle_pose := "idle"

## Standing height in world pixels, handed straight to the actor.
@export_range(8.0, 64.0, 1.0) var standing_height := 16.0

## Stand him on the floor beneath where he was placed rather than at exactly the
## height the LDtk entity sits at. Off = he stays put, for a Jamshid deliberately
## on a ledge the probe would drop him off.
@export var snap_to_ground := true

## How far down to look for that floor, in px. Comfortably more than a room.
const FLOOR_PROBE_DEPTH := 400.0

## The stand-in portrait's tint, used only if his real art ever fails to load —
## `Jamshid.portrait()` always returns a texture, so in practice DialogueBox
## takes the "real art: never tint it" branch and this is never seen. Passed
## anyway because `side` sits behind it in say()'s argument list.
const JAMSHID_WARM := Color(0.95, 0.72, 0.38, 1.0)

@onready var actor: Jamshid = $Actor

## Greeted already. Once per world load: walking back past him should not replay
## the reunion, and neither should a death between the trigger and the line.
var _greeted := false
## The ground probe needs the physics server to have the room's tilemap in it,
## which is not true yet in _ready() — so it runs on the first physics frame
## instead, exactly once.
var _snapped := false


func _ready() -> void:
	add_to_group("jamshid_npc")
	actor.standing_height = standing_height
	actor.face_left(facing_left)
	actor.play_pose(idle_pose)


func _physics_process(_delta: float) -> void:
	if not _snapped:
		_snapped = true
		if snap_to_ground:
			_stand_on_floor()
	if _greeted:
		return
	var player := get_tree().get_first_node_in_group("player") as Player
	if player == null:
		return
	# Another beat (a Rumi line, a story door, a room slide) already owns him —
	# two conversations opening the same banner is the one thing that cannot be
	# allowed to happen. He is still standing here; try again next frame.
	if player.input_locked:
		return
	if global_position.distance_to(player.global_position) > trigger_radius:
		return
	_greeted = true
	triggered.emit(player)
	if defer_to_cutscene:
		return
	_greet(player)


## Put his feet on the first world surface below him. His origin IS his feet
## (see assets/characters/jamshid/README.md), so unlike Rumi there is no transparent
## padding to measure off the sprite — the probe's hit point is the answer.
func _stand_on_floor() -> void:
	var from := global_position - Vector2(0.0, 8.0)
	var query := PhysicsRayQueryParameters2D.create(from, from + Vector2(0.0, FLOOR_PROBE_DEPTH))
	query.collision_mask = 1  # world
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if hit:
		global_position.y = hit.position.y


## The greeting. Takes his controls for the duration, the same as every other
## scripted beat in the project, and hands them back however the script ends.
func _greet(player: Player) -> void:
	var beats := script_beats()
	Dialogue.begin_conversation(self, player)
	for beat: Dictionary in beats:
		await Dialogue.say("Jamshid", beat["text"], JAMSHID_WARM,
			Jamshid.portrait(beat["face"]), portrait_side(player))
	Dialogue.end_conversation()


## `dialogue_line` parsed into [{text, face}], in order, with a line that names
## no state falling back to `default_face`.
##
## Public and pure so a test can read a script without staging the beat — the
## parsing is the part that can go quietly wrong, and the failure it makes is a
## stage direction printed on screen as though Jamshid said it.
func script_beats() -> Array[Dictionary]:
	var beats := DialogueScript.parse(dialogue_line, Jamshid.FACES, "Jamshid")
	for beat: Dictionary in beats:
		if beat["face"] == "":
			beat["face"] = default_face
	return beats


## Which end of the dialogue banner Jamshid's face belongs at: the side he is
## actually standing on. Read off his position rather than off `facing_left`, so
## it cannot disagree with what is on screen.
func portrait_side(other: Node2D) -> int:
	if other == null:
		return DialogueBox.Side.RIGHT
	return DialogueBox.Side.RIGHT if global_position.x >= other.global_position.x \
		else DialogueBox.Side.LEFT
