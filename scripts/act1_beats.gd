class_name Act1Beats
extends Node
## Act I's scripted story beats, across the rooms of the LDtk world.
##
## Three scenes:
##   1. WAKING (room 1) — the game fades up from black, Hooshang comes round and
##      works out he isn't where he should be. He has control after this.
##   2. THE MEETING (room 1) — walking into the RumiTrigger brings Rumi in. Rumi
##      says nothing for a long moment; Hooshang fills the silence, gets no
##      answer, and talks himself into a concussion theory. Then Rumi answers,
##      names the journey, and reaches out. Hooshang agrees to one step. No
##      ability yet — this beat is the introduction.
##   3. THE GIFT (room 2) — at the second encounter Rumi explains the gap and
##      grants the DASH. Deliberately not in room 1: the ability arrives in the
##      room that first demands it, so the lesson and the need land together.
##
## Lives as a child of the world (ldtk/Act1World.tscn) rather than inside the
## RumiTriggers, because story beats are code with staging in them, while the
## trigger stays a generic "player got here" detector any room can drop in. Each
## trigger hands this script its beat through `defer_to_cutscene` + `triggered`.
##
## FUTURE: later Acts get their own script alongside this one. If a third turns
## up, the shared parts (fade, hold, portrait tints) want extracting first.

## Portrait tints in the dialogue box — alpha > 0 is what makes a portrait show.
## Hooshang has real portrait art (below) so his tint is plain white; Rumi is
## still the tinted stand-in.
const HOOSHANG_PALE := Color(1.0, 1.0, 1.0, 1.0)
const RUMI_GOLD := Color(1.0, 0.82, 0.42, 1.0)

## Hooshang's face per line. Each beat names the state it wants rather than a
## file, so re-cutting the portrait sheet never touches the dialogue.
const FACES := {
	"dazed": preload("res://assets/portraits/hooshang_dazed.png"),
	"confused": preload("res://assets/portraits/hooshang_confused.png"),
	"hesitant": preload("res://assets/portraits/hooshang_hesitant.png"),
	"skeptical": preload("res://assets/portraits/hooshang_skeptical.png"),
	"annoyed": preload("res://assets/portraits/hooshang_annoyed.png"),
	"vulnerable": preload("res://assets/portraits/hooshang_vulnerable.png"),
}

## Rumi's line at the second encounter. It teaches the control itself, so there
## is no separate system hint after it.
const DASH_LINE := "Some gaps won't yield to a jump. Press the SHIFT key to dash."

const EMOTE_SCENE := preload("res://scenes/ui/EmoteBubble.tscn")
## Script lines that are nothing but punctuation. These are reactions, not
## speech: they play as a bubble over the speaker's head instead of opening the
## dialogue banner. A banner that slides in, types out "...", and then waits for
## a button press turns a beat of silence into paperwork — you watch a reaction,
## you read a line. See scenes/ui/emote_bubble.gd.
const EMOTE_LINES := {
	"!": EmoteBubble.Kind.EXCLAIM,
	"...": EmoteBubble.Kind.ELLIPSIS,
}

## Room holding the waking scene and the first meeting (LDtk level identifier).
@export var room_name := "Level_1_Office"
## Room holding the second encounter, where the dash is granted.
@export var dash_room_name := "Level_1"

@export_group("Waking")
## How long the screen stays fully black before it starts lifting.
@export var black_hold := 0.5
## How long the fade up from black takes.
@export var fade_time := 1.4
## Beat of stillness after the fade before he speaks — he's coming round.
@export var come_round_pause := 0.5
## How long he holds each direction while looking around.
@export var look_time := 0.5

@export_group("The meeting")
## Where Rumi materialises, in pixels from the trigger. Hooshang is standing ON
## the trigger when it fires, so Rumi needs to arrive to one side — otherwise
## they occupy the same spot and there is no distance for him to close when he
## reaches out. Positive = the far side from Hooshang's approach.
@export var rumi_stand_offset := 24.0
## The unhurried silence after Rumi appears, before Hooshang breaks it.
@export var silence_time := 1.7
## Pause before Rumi finally answers.
@export var before_rumi_speaks := 0.7

@export_group("Emotes")
## Where the bubble's tail sits, relative to the speaker's origin.
##
## Measured, not guessed. Hooshang's DRAWN head — the top opaque row of his
## frame, not the top of the 88px frame itself — sits about 11px above his
## origin, so -22 left the tail pointing at nothing, with 13px of daylight under
## it. This keeps a couple of pixels' clearance and no more.
@export var emote_height := -14.0

var _world: LdtkWorld
var _room: Node2D
var _dash_room: Node2D
var _fade: ColorRect
var _opening_played := false


func _ready() -> void:
	_world = _find_world()
	if _world == null:
		push_error("Act1Beats: no LdtkWorld ancestor — put this inside the world scene.")
		return
	_build_fade()
	# The rooms don't exist yet: LdtkWorld instantiates the imported world in
	# its OWN _ready(), and a parent's _ready runs AFTER its children's. So wait
	# for them rather than looking now and finding nothing.
	for i in 10:
		if not _world.rooms.is_empty():
			break
		await get_tree().process_frame
	_room = _find_room(room_name)
	if _room == null:
		push_warning("Act1Beats: no room named '%s' — beats disabled." % room_name)
		_fade.color.a = 0.0
		return

	# Claim both encounters BEFORE the player could reach either, or the trigger
	# plays its own generic one-liner instead of the scripted beat.
	_claim(_room, _play_meeting)
	_dash_room = _find_room(dash_room_name)
	if _dash_room != null:
		_claim(_dash_room, _play_dash_gift)
	else:
		push_warning("Act1Beats: no room named '%s' — the dash is never granted."
			% dash_room_name)

	# Only wake him where he actually wakes. The debug picker can start the
	# world in any room, and fading up from black in room 3 would be nonsense.
	if _world.current_room == _room:
		await _play_waking()
	else:
		_fade.color.a = 0.0


## Take a room's Rumi beat off its trigger and onto `handler(player, trigger)`.
func _claim(room: Node2D, handler: Callable) -> void:
	var trigger := _find_trigger(room)
	if trigger == null:
		return
	trigger.defer_to_cutscene = true
	trigger.triggered.connect(handler.bind(trigger))


# ------------------------------------------------------------- 1. waking ----

func _play_waking() -> void:
	if _opening_played:
		return
	_opening_played = true
	var player := _world.player
	player.input_locked = true
	# Start the run dashless so Rumi's gift is an actual gift. Hooshang.tscn
	# ships with has_dash on (the test gym and later rooms want it), and the
	# LDtk world instantiates that scene as-is — so without this the ability was
	# already his and the whole beat granted him nothing. Done HERE, inside the
	# waking scene, so it only applies to a run that starts at the beginning:
	# the debug picker dropping straight into a later room keeps its dash.
	player.has_dash = false

	await _hold(black_hold)
	var t := create_tween()
	t.tween_property(_fade, "color:a", 0.0, fade_time) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await t.finished
	await _hold(come_round_pause)

	await _hooshang("Where am I?", "dazed")

	# "(looking around)" is a stage direction, so play it rather than print it.
	player.look(-1)
	await _hold(look_time)
	player.look(1)
	await _hold(look_time * 0.6)

	await _hooshang("This doesn't feel like my cubicle...", "confused")
	player.input_locked = false


# ------------------------------------------------------------ 2. meeting ----

func _play_meeting(player: Player, trigger: LdtkRumiTrigger) -> void:
	player.input_locked = true
	player.look(1)  # he's walking right into this; face the visitor

	# Rumi arrives first — that's what Hooshang is reacting to. He materialises
	# ahead of Hooshang (on the side he was walking towards), not on top of him.
	var ahead := signf(trigger.global_position.x - player.global_position.x)
	if ahead == 0.0:
		ahead = 1.0
	await trigger.appear(ahead * rumi_stand_offset)
	trigger.breathe(true)

	await _hooshang("!", "confused")
	await _hooshang("Hello??", "hesitant")
	await _hooshang("...", "hesitant")
	await _hooshang(
		"Who are you? I've worked in this office fifteen years. I've never once seen you at an all hands.",
		"skeptical")

	# He says nothing yet. He only stands there, unhurried, the light along his
	# sleeves breathing slightly — that breathing is trigger.breathe(true),
	# already running since he appeared.
	await _hold(silence_time)

	await _hooshang(
		"Are you going to say something, or just stand there glowing at me...",
		"annoyed")
	await _hooshang("...", "vulnerable")
	await _hooshang("I think I hit my head harder than I thought...", "vulnerable")

	await _hold(before_rumi_speaks)
	await _rumi("You stand at the beginning of your most important journey, Hooshang jaan")
	# "(muttering)" is carried by the wording and his face. It used to slow the
	# typewriter down, but a line that types at its own rate reads as a different
	# KIND of text rather than a quieter one — every line reveals at
	# DialogueBox.chars_per_second now.
	await _hooshang("A journey? I just wanted to make it to my car.", "skeptical")
	await _rumi("Do not turn away now. The way out is the way through, and the way through is inward.")
	await _rumi("You have knocked on this door your whole life, from the inside.")
	await _rumi("Walk toward the light. You need not see the whole road, only the next step of it.")

	# He reaches out — one hand, sleeve trailing light — and touches his chest.
	# Something wrapped in cloth for fifty years comes loose. No ABILITY here,
	# though: the dash is the second encounter's gift, one room later, where
	# there is finally a gap that needs it.
	await trigger.step_to(player.global_position.x)
	await trigger.swell()
	await trigger.give_to(player)
	player.flash()
	await _hold(0.45)

	# He answers with Rumi still standing there, and only then does Rumi go.
	await _hooshang("One step.[p] Okay. One step I can probably do.", "hesitant")

	await trigger.vanish()
	player.input_locked = false
	trigger.arm_room_door()


# --------------------------------------------------------------- 3. gift ----

## Second encounter: the dash, in the room whose gaps demand it.
func _play_dash_gift(player: Player, trigger: LdtkRumiTrigger) -> void:
	player.input_locked = true
	player.look(1)

	var ahead := signf(trigger.global_position.x - player.global_position.x)
	if ahead == 0.0:
		ahead = 1.0
	await trigger.appear(ahead * rumi_stand_offset)
	trigger.breathe(true)
	await _hold(before_rumi_speaks)

	await Dialogue.say("Rumi", DASH_LINE, RUMI_GOLD)

	# The gift: he closes the distance, the light swells, crosses the gap, and
	# it's Hooshang's. The ability lands on the same frame the mote does.
	await trigger.step_to(player.global_position.x)
	await trigger.swell()
	await trigger.give_to(player)
	player.flash()
	player.has_dash = true
	await _hold(0.5)

	await trigger.vanish()
	player.input_locked = false
	trigger.arm_room_door()


## One of Hooshang's lines, with the face that goes with it — or a bubble over
## his head, if the "line" is only punctuation.
func _hooshang(text: String, face: String) -> void:
	if EMOTE_LINES.has(text):
		await _emote(_world.player, EMOTE_LINES[text])
		return
	await Dialogue.say("Hooshang", text, HOOSHANG_PALE, FACES.get(face))


## Pop a reaction over `over` and wait for it to finish. Parented to the speaker
## so it tracks them, and freed after — nothing of it outlives the beat.
func _emote(over: Node2D, kind: EmoteBubble.Kind) -> void:
	if over == null:
		return
	var bubble: EmoteBubble = EMOTE_SCENE.instantiate()
	over.add_child(bubble)
	bubble.position = Vector2(0.0, emote_height)
	await bubble.play(kind)
	bubble.queue_free()


## One of Rumi's. He has no portrait art yet, so he gets the tinted stand-in.
func _rumi(text: String) -> void:
	await Dialogue.say("Rumi", text, RUMI_GOLD)


# -------------------------------------------------------------- plumbing ----

## Black sheet for the fade up. Built in code and on its own high CanvasLayer so
## it covers the whole screen regardless of the world's camera or lighting.
func _build_fade() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 90  # under the dialogue box, over everything else
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 1)
	_fade.anchor_right = 1.0
	_fade.anchor_bottom = 1.0
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_fade)


func _hold(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _find_world() -> LdtkWorld:
	var n := get_parent()
	while n != null:
		if n is LdtkWorld:
			return n
		n = n.get_parent()
	return null


func _find_room(name: String) -> Node2D:
	for room in _world.rooms:
		if room.name == name:
			return room
	return null


## The room's Rumi trigger, wherever in the room it was dropped.
func _find_trigger(room: Node) -> LdtkRumiTrigger:
	if room is LdtkRumiTrigger:
		return room
	for child in room.get_children():
		var found := _find_trigger(child)
		if found != null:
			return found
	return null
