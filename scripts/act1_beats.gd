class_name Act1Beats
extends Node
## Act I's scripted story beats, across the rooms of the LDtk world.
##
## Four scenes:
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
##   4. THE TILES (room 5) — at the mouth of the sounding tiles, in a stretch
##      Hooshang cannot see across. No ability: the room is the gift, and Rumi
##      only tells him the tiles will answer him. He arrives faint and stays
##      faint — lighting the room would answer the problem for him.
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
	# Three states the meeting asks for that have no drawing of their own yet,
	# pointed at the nearest one that does. They are listed as their own states
	# rather than the beats just saying "skeptical" twice, because the beat is
	# where the ACTING is described — when the sheet is re-cut these get their
	# own faces and not one line of dialogue moves.
	"wary": preload("res://assets/portraits/hooshang_skeptical.png"),
	"unconvinced": preload("res://assets/portraits/hooshang_skeptical.png"),
	"deflecting": preload("res://assets/portraits/hooshang_hesitant.png"),
	# Deadpan. Aliased to skeptical because the line it serves is a dry
	# restatement of something absurd, which is doubt with the inflection taken
	# out — the nearest thing already drawn.
	"flat": preload("res://assets/portraits/hooshang_skeptical.png"),
}

## Rumi's two lines at the second encounter, with the gift between them. He names
## the need and hands the ability over first; the control comes after, once
## Hooshang actually has the thing the key operates. Teaching the button before
## the ability exists is an instruction; teaching it after is a use.
const DASH_OFFER_LINE := "Some walls won't yield to a jump. Take this, and dash."
## The key here has to match the `dash` action in project.godot — SHIFT, with X
## and the gamepad face buttons bound alongside it.
const DASH_CONTROL_LINE := "Press the SHIFT key to dash."

## Rumi's lines at the third encounter, over the sounding tiles. He grants
## nothing here — the room itself is the gift, and what he hands over is
## permission to trust it.
const RHYTHM_LINE := "Something waits ahead of you, in the dark. You think you've lost your rhythm.[p] You haven't. It's only sleeping — here, in these tiles."
## The actual RULE of the room, said out loud: all five pads, each once, IN
## ORDER, and the reward is the glow (scenes/props/note_tile.gd and
## scripts/note_sequence.gd). It is the only tutorial the puzzle gets — the
## stretch is unlit and there is nothing to read the mechanic off — so if the
## sequence rule ever changes, this line is part of the change.
const MUSIC_LINE := "Wake the notes in their order, one after the next, until they join into a melody.[p] Complete it, and its light will gather on you — enough to carry you through the dark ahead."

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
@export var room_name := "Level_0"
## Room holding the second encounter, where the dash is granted.
@export var dash_room_name := "Level_1"
## Room holding the third encounter, at the mouth of the sounding tiles.
@export var music_room_name := "Level_4"
## Room holding the Darkshang encounter.
@export var chase_room_name := "Level_11"
## Where that room's entrance leads once the shadow has been seen — the escape
## continuing, not the room he arrived from. "" leaves the doorway alone.
@export var chase_way_back := "Level_12"

@export_group("The collapse")
## First and last room of the escape that comes apart as he walks into it, by
## level number. The whole return row: the building is failing behind him the
## entire way home, not just once. Set them equal to collapse a single room, or
## first > last to turn the beat off.
@export var collapse_first_room := 13
@export var collapse_last_room := 22
## Beat of stillness before anything moves. He walks in, and for a moment nothing
## happens — the drop lands harder for having been waited for.
@export var collapse_lead_in := 0.6
## How hard the camera rattles while a room is coming down, in px.
@export var collapse_shake := 1.6
## The single hard jolt on the frame it lets go, before the rattle settles in.
## Bigger than collapse_shake — this one is the crack, not the tremor.
@export var collapse_jolt := 2.4

@export_group("The way home")
## Last room of the escape, and where its Exit leads. The return trip ends where
## the game began: he walks out of room 21 and back into his own cubicle.
##
## Set HERE rather than in the room's LDtk `NextRoom` field only because this is
## a story fact about Act I rather than a fact about that room — moving it into
## LDtk would work identically, and this writes the same metadata the importer
## would have. "" leaves the Exit to the normal play order.
@export var loop_room_name := "Level_22"
@export var loop_to_room_name := "Level_0"

@export_group("Waking")
## How long the screen stays fully black before it starts lifting.
@export var black_hold := 0.5
## How long the fade up from black takes.
@export var fade_time := 1.4
## Beat of stillness after the fade before he speaks — he's coming round.
@export var come_round_pause := 0.5
## How long he holds each direction while looking around. Both directions get
## the same beat — the second used to be shorter, which read as him losing
## interest rather than taking the room in.
@export var look_time := 0.8

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

@export_group("The tiles")
## How brightly Rumi arrives for the third encounter. He is "glowing faintly at
## the edge of the dark" here, not lighting the room — the whole beat is about
## crossing a stretch you cannot see, so a Rumi who turns the lights on would be
## answering the problem he came to talk about.
@export var rumi_faint_energy := 0.55
## Where he stands, in pixels from the trigger — the FAR side of the sounding
## tiles, so he is the thing you run toward.
##
## Measured off the room, not chosen: the ledge under the trigger runs out one
## tile along, where the tiles begin, and the next solid floor at that height is
## 96px on. Anything shorter stands him in the first gap, inside MusicNote1.
##
## Deliberately NOT signed by which way Hooshang walked in, the way the other two
## beats are. "Ahead" here is a fact about the room — the tiles run right — and a
## player who backtracks into this room from the far side would otherwise summon
## Rumi 96px off the left edge of the world.
@export var rumi_far_offset := 96.0
## How long the scene holds on him after he arrives, before Hooshang speaks. He
## turns up across a dark room without a word; give that a moment to land rather
## than stepping on it with the next banner.
@export var arrival_pause := 2.0

@export_group("Emotes")
## Where the bubble's tail sits, relative to the speaker's origin.
##
## Measured, not guessed. Hooshang's DRAWN head — the top opaque row of his
## frame, not the top of the 88px frame itself — sits about 11px above his
## origin, so -22 left the tail pointing at nothing, with 13px of daylight under
## it. This keeps a couple of pixels' clearance and no more.
@export var emote_height := -14.0

## The trigger staging Rumi right now. Held so his lines can ask it which side
## he is standing on rather than tracking that separately and drifting from it.
var _rumi_trigger: LdtkRumiTrigger
## Which screen edge THIS scene's banner sits flush against. Set once at the top
## of each `_play_*` beat, from where the player and Rumi actually stand in that
## room — never guessed line by line. See DialogueBox.VSide.
var _dialogue_vside: int = DialogueBox.VSide.TOP
## The chase room's threshold, held so a save can ask whether it has been crossed
## and tell it so on the way back in.
var _chase: DarkshangTrigger
var _world: LdtkWorld
var _room: Node2D
var _dash_room: Node2D
var _music_room: Node2D
var _fade: ColorRect
var _opening_played := false
## Room he was in before the current one, so a beat can ask which way he came.
var _last_room: Node2D
## Rooms that have already come down, by name. A room collapses once — walking
## back into one that has already fallen finds it fallen, not falling again.
var _collapsed := {}


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
	_music_room = _find_room(music_room_name)
	if _music_room != null:
		_claim(_music_room, _play_music_beat)
	else:
		push_warning("Act1Beats: no room named '%s' — the tiles go unexplained."
			% music_room_name)
	_wire_chase()
	_wire_collapse()
	_wire_loop_home()
	_restore_state()

	# Only wake him where he actually wakes. The debug picker can start the
	# world in any room, and fading up from black in room 3 would be nonsense.
	# `_opening_played` is checked HERE rather than left to _play_waking's own
	# guard, because that guard returns before the fade lifts — a run resumed in
	# room 1 would have come back to a black screen it never faded up from.
	if _world.current_room == _room and not _opening_played:
		await _play_waking()
	else:
		_fade.color.a = 0.0


## What Act I contributes to a save slot (see systems/save_game.gd).
##
## All three are "has this already happened", and all three are wrong by default
## rather than absent: a load that forgets them replays the waking scene in the
## middle of the run, drops the ceiling on a room that already fell, and reveals
## Darkshang a second time to a player who has been running from him for six
## rooms.
func save_state() -> Dictionary:
	return {
		"opening_played": _opening_played,
		"collapsed": _collapsed.keys(),
		"chase_seen": _chase != null and _chase.spent,
	}


## Pulled in _ready, for the same reason LdtkWorld pulls its own: the trigger
## being marked spent is a node this script has only just found.
func _restore_state() -> void:
	var state := SaveGame.state_for("act1")
	if state.is_empty():
		return
	_opening_played = bool(state.get("opening_played", false))
	var fallen: Variant = state.get("collapsed", [])
	if typeof(fallen) == TYPE_ARRAY:
		for room_name in fallen as Array:
			_collapsed[str(room_name)] = true
	# Spent, not re-fired: the chase itself is deliberately not saved (see the
	# note on _wire_chase), so what a resumed run inherits is the doorway the
	# encounter re-pointed and the fact that it is over.
	if _chase != null and bool(state.get("chase_seen", false)):
		_chase.spent = true


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
	# He wakes standing roughly mid-room, well clear of the ceiling — the top of
	# the screen is open.
	_dialogue_vside = DialogueBox.VSide.TOP
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
	await _hold(look_time)

	await _hooshang("This doesn't feel like my cubicle...", "confused")
	player.input_locked = false


# ------------------------------------------------------------ 2. meeting ----

func _play_meeting(player: Player, trigger: LdtkRumiTrigger) -> void:
	player.input_locked = true
	_rumi_trigger = trigger
	# Same room as the waking scene, and Rumi arrives at floor height beside him
	# — both of them stay in the lower half. Top is clear.
	_dialogue_vside = DialogueBox.VSide.TOP
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
		"Who are you? I've worked in this office fifteen years. I've never seen you once.",
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
	await _rumi("You stand at the beginning of your most important journey, Hooshang jaan.")
	# "(muttering)" is carried by the wording and his face. It used to slow the
	# typewriter down, but a line that types at its own rate reads as a different
	# KIND of text rather than a quieter one — every line reveals at
	# DialogueBox.chars_per_second now.
	await _hooshang("A journey? I just wanted to make it to my car.", "skeptical")

	# The turn: the building is not a building. Rumi names the premise of the
	# whole game here, and Hooshang argues with it rather than accepting it,
	# which is what keeps the exposition a scene instead of a briefing. Every
	# "[p]" is a breath held mid-line (DialogueBox.PAUSE_MARK) — stripped before
	# it is drawn, so it costs the reader nothing and paces the delivery.
	await _rumi("You will not reach the parking lot from here. This is not that building.[p] It is the one you carry inside you.")
	await _hooshang("...Inside me?", "wary")
	await _rumi("Inside you. Your mind has built its own rooms, and you must go down through every one.")
	await _rumi("The office that swallowed your years.[p] Your childhood.[p] And beneath them the places and things you have never let go of.")
	await _hooshang("And I'm supposed to just — walk through my own head. On purpose.", "unconvinced")
	# One thought per banner. These four were a single line, and at ~310
	# characters it grew the box to eight rows and most of the screen — the
	# banner is built to grow (DialogueBox._fit_banner) so nothing was clipped,
	# it simply stopped reading as dialogue and started reading as a page. Every
	# other line in this scene is under 110; these now are too.
	await _rumi("Not walk through. You have done that your whole life.")
	await _rumi("To pass, you must meet what waits in each room.")
	await _rumi("The grief you swallowed.[p] The dreams you set down \"for later.\"[p] The thoughts that still circle you in the dark.")
	await _rumi("They are not memories, jaan. They are still alive.[p] And they will not let you by until you face them.")

	# He asks for an extension, in the exact words he has used his whole life —
	# and Rumi does not argue, he just repeats the word back. That is the beat
	# the scene is built around, so nothing else happens on top of it.
	await _hooshang("Look — this really isn't a good time. I just lost my job.[p] I'll get to all that.[p] Later.", "deflecting")
	await _rumi("...Later.[p] Yes. That is the word, isn't it.")

	await _rumi("You have knocked on this door your whole life, from the inside.[p] Now it opens.")
	await _rumi("You need not see the whole road, only the next step of it.")

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
	await _hooshang("One step.[p] OK. One step I can probably do...", "hesitant")

	await trigger.vanish()
	player.input_locked = false
	trigger.arm_room_door()


# --------------------------------------------------------------- 3. gift ----

## Second encounter: the dash, in the room whose gaps demand it.
func _play_dash_gift(player: Player, trigger: LdtkRumiTrigger) -> void:
	player.input_locked = true
	_rumi_trigger = trigger
	# PlayerStart and the trigger both sit on the room's floor, near the bottom
	# of the screen. Top is clear.
	_dialogue_vside = DialogueBox.VSide.TOP
	player.look(1)

	var ahead := signf(trigger.global_position.x - player.global_position.x)
	if ahead == 0.0:
		ahead = 1.0
	await trigger.appear(ahead * rumi_stand_offset)
	trigger.breathe(true)
	await _hold(before_rumi_speaks)

	await _rumi(DASH_OFFER_LINE)

	# "take this" is the stage direction in that line, so it gets PLAYED: he
	# closes the distance, the light swells, crosses the gap, and it's
	# Hooshang's. The ability lands on the same frame the mote does.
	await trigger.step_to(player.global_position.x)
	await trigger.swell()
	await trigger.give_to(player)
	player.flash()
	player.has_dash = true
	await _hold(0.5)

	# Only now the button, with the dash already his to press it with.
	await _rumi(DASH_CONTROL_LINE)

	await trigger.vanish()
	player.input_locked = false
	trigger.arm_room_door()


# -------------------------------------------------------------- 4. tiles ----

## Third encounter, at the mouth of the sounding tiles. Nothing is granted here:
## the room is the gift. Hooshang cannot see the way across, and what Rumi hands
## him is the reason to step onto it anyway.
func _play_music_beat(player: Player, trigger: LdtkRumiTrigger) -> void:
	player.input_locked = true
	_rumi_trigger = trigger
	# PlayerStart and the trigger both sit near the CEILING here — this room
	# descends through the tiles rather than crossing them at floor height — so
	# the top of the screen is where he and Rumi actually are. Bottom is clear.
	_dialogue_vside = DialogueBox.VSide.BOTTOM

	# He speaks into the dark FIRST — the complaint is what Rumi answers by
	# turning up at all.
	await _hooshang("I can't see a thing.", "confused")

	# "glowing faintly at the edge of the dark" is staging, so it gets played: he
	# arrives dim, across the unlit stretch, and stays dim. See rumi_faint_energy
	# — a Rumi who lit the room would be solving the problem he came to talk
	# about, and standing him on the FAR side makes him the thing you cross to.
	await trigger.appear(rumi_far_offset, rumi_faint_energy)
	trigger.breathe(true)
	player.look(1)  # he is always deeper into the room; face him
	await _hold(arrival_pause)

	await _hooshang("You show up right before the parts I'm going to hate, don't you?",
		"annoyed")
	await _rumi(RHYTHM_LINE)
	await _rumi(MUSIC_LINE)

	# He answers with Rumi still standing there, same as the cubicle scene — the
	# deadpan only lands if the person it is aimed at is still in the room.
	await _hooshang("So I play the tune, I get a light.[p] ...Fine.", "flat")

	await trigger.vanish()
	player.input_locked = false
	trigger.arm_room_door()


# ------------------------------------------------------------- 5. chase ----

## Meeting Darkshang re-points the room's entrance.
##
## Level_11 is walked into from the left and the reveal turns Hooshang round, so
## the way out is the way he came — but the room behind him is not where the
## escape goes. Level_12 hangs below the row and is authored right to left (its
## PlayerStart is at its right end, its Exit at its left), which is the chase
## continuing. Without this, running back out of the boss room undoes the room
## you just entered and drops you in Level_10 with a shadow behind you.
##
## Hung off the encounter rather than set at load, because before it there is
## nothing to run from: the doorway is ordinary backtracking then and should stay
## ordinary. Hung off `triggered` — the instant he crosses the line — rather than
## `chase_begun`, so the route is already changed while the reveal is playing and
## cannot be missed by a beat that gets interrupted.
##
## Here rather than in darkshang_trigger.gd because which room the chase spills
## into is Act I's story, and the trigger stays a thing any Act can drop in.
## A NOTE ON SAVING THIS. What a slot carries away from the encounter is that it
## happened — the re-routed doorway (LdtkWorld's `_way_back`) and the trigger
## being spent. The chase in flight is deliberately dropped: where the shadow had
## got to is a mid-room fact, and a save taken at a room boundary has no honest
## place to put it. Resuming therefore finds the route changed and the corridor
## empty, which is the version a player can act on.
func _wire_chase() -> void:
	var room := _find_room(chase_room_name)
	if room == null:
		push_warning("Act1Beats: no room named '%s' — the chase is never re-routed."
			% chase_room_name)
		return
	_chase = _find_chase_trigger(room)
	if _chase == null:
		push_warning("Act1Beats: room '%s' has no DarkshangTrigger — its entrance still leads back."
			% chase_room_name)
		return
	if chase_way_back == "":
		return
	_chase.triggered.connect(func(_player: Player) -> void:
		_world.set_way_back(room, chase_way_back))


## The room's Darkshang trigger, wherever in the room it was dropped. Scoped to
## the room for the same reason _find_trigger is: the whole Act is loaded at
## once, so an unscoped group lookup would reach into rooms the player has never
## seen (STYLE_GUIDE §9).
func _find_chase_trigger(room: Node) -> DarkshangTrigger:
	if room is DarkshangTrigger:
		return room
	for child in room.get_children():
		var found := _find_chase_trigger(child)
		if found != null:
			return found
	return null


# ---------------------------------------------------------- 6. collapse ----

## Walking into the last room, the level itself gives way.
##
## Everything hanging in the air — belts, spike strips, the ledges he was going
## to use — drops to the floor while he and the shadow both stand still and watch
## it happen. The hold is the beat: a collapse the player can run through is
## scenery, and a collapse he cannot move during is the world ending.
##
## Hung off `room_changed` rather than a trigger entity so the room needs nothing
## placed in it — the beat belongs to ARRIVING, and there is no line across the
## doorway that arriving could miss.
func _wire_collapse() -> void:
	if collapse_first_room > collapse_last_room:
		return
	var found := 0
	for n in range(collapse_first_room, collapse_last_room + 1):
		if _find_room("Level_%d" % n) != null:
			found += 1
	if found == 0:
		# Not a warning: these rooms are authored in LDtk and may simply not
		# exist yet. The beat is inert until they do, and says so once rather
		# than every time the world loads.
		print("Act1Beats: no rooms in %d-%d — the collapse is waiting on them."
			% [collapse_first_room, collapse_last_room])
		return
	# Seed it with where he already is. room_changed has ALREADY fired for the
	# opening room by now (LdtkWorld emits it from its own _ready, and this script
	# waits for the rooms to exist before looking), so without this the very next
	# transition reports that he came from nowhere — and the debug picker, which
	# drops you straight into Level_12, could never reach the beat at all.
	_last_room = _world.current_room
	_world.room_changed.connect(_on_room_changed)


func _on_room_changed(room: Node2D) -> void:
	var arriving_from := _last_room
	_last_room = room
	var here := LdtkWorld.play_index(room)
	if here < collapse_first_room or here > collapse_last_room:
		return
	if _collapsed.has(room.name):
		return
	# Only on the way THROUGH, and only from the room before it. Backtracking
	# into a room ahead of him would otherwise pull its ceiling down while he is
	# walking the wrong way, and the beat would play out of order.
	if arriving_from == null or LdtkWorld.play_index(arriving_from) != here - 1:
		return
	_collapsed[room.name] = true
	_play_collapse(room)


func _play_collapse(room: Node2D) -> void:
	# One frame first. room_changed is emitted from INSIDE the camera slide,
	# before it hands control back — so input_locked is still true right now, and
	# a hold that captured it here would restore it afterwards and leave the
	# player watching a finished cutscene with no controls.
	await get_tree().process_frame

	var player := _world.player
	# Nothing hanging means nothing to watch: don't freeze him for a beat of
	# absolutely nothing happening, which is how an unfinished room would read.
	var falling := RoomCollapse.duration(room)
	if falling <= 0.0:
		return
	# Both held for exactly as long as the falling takes, measured rather than
	# guessed — the props are staggered, so the honest number is a function of
	# how many there are and how high they hang (RoomCollapse.duration).
	var beat := collapse_lead_in + falling
	player.hold(beat)
	var shadow := _shadow_in_play()
	if shadow != null:
		shadow.hold(beat)

	await _hold(collapse_lead_in)
	# The crack, then the tremor: one hard jolt on the frame it lets go, and a
	# decaying rattle for as long as things are still falling. The rumble is
	# started BEFORE the drop so the room is already shaking when the first prop
	# moves — the shake reads as the cause, not the reaction.
	player.shake(collapse_jolt)
	player.rumble(collapse_shake, falling)
	RoomCollapse.drop(room, self)


## Point the last room of the escape back at the cubicle he started in.
##
## Writes the same `next_room` metadata the LDtk importer writes from an Exit's
## `NextRoom` field (see ldtk_entities_post_import.gd), so the room manager needs
## to know nothing about this — to it, room 21's Exit simply names room 0, the
## way any non-linear jump does.
##
## Without it that Exit falls through to play order, which runs out at room 21
## and hands back nothing: walking into the last door of the game did nothing at
## all, which reads as the door being broken rather than as the end of the Act.
func _wire_loop_home() -> void:
	if loop_room_name == "" or loop_to_room_name == "":
		return
	var room := _find_room(loop_room_name)
	if room == null:
		return
	if _find_room(loop_to_room_name) == null:
		push_warning("Act1Beats: '%s' names no room — %s's Exit leads nowhere."
			% [loop_to_room_name, loop_room_name])
		return
	var exit := _world._exit_in(room)
	if exit == null:
		push_warning("Act1Beats: %s has no Exit to send home." % loop_room_name)
		return
	exit.set_meta("next_room", loop_to_room_name)


## The Darkshang currently chasing, if one is. Taken from the group rather than
## from the chase room, because by now he has followed the player out of it —
## he is the one thing in the Act that is deliberately not scoped to a room.
func _shadow_in_play() -> Darkshang:
	for node in get_tree().get_nodes_in_group("darkshang"):
		if node is Darkshang and node.visible:
			return node
	return null


## One of Hooshang's lines, with the face that goes with it — or a bubble over
## his head, if the "line" is only punctuation.
func _hooshang(text: String, face: String) -> void:
	if EMOTE_LINES.has(text):
		await _emote(_world.player, EMOTE_LINES[text])
		return
	await Dialogue.say("Hooshang", text, HOOSHANG_PALE, FACES.get(face),
		DialogueBox.Side.LEFT, _dialogue_vside)


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
##
## His face goes on whichever end of the banner he is actually standing at, so
## the two of them read as talking across a space rather than out of the same
## corner. Hooshang is always the other one, so his stays left.
func _rumi(text: String) -> void:
	var side: int = _rumi_trigger.portrait_side(_world.player) if _rumi_trigger != null \
		else DialogueBox.Side.RIGHT
	await Dialogue.say("Rumi", text, RUMI_GOLD, null, side, _dialogue_vside)


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
