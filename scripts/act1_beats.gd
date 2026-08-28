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
	"hesitant": preload("res://assets/portraits/hooshang_hesitant.png"),
	"skeptical": preload("res://assets/portraits/hooshang_skeptical.png"),
	"annoyed": preload("res://assets/portraits/hooshang_annoyed.png"),
	"vulnerable": preload("res://assets/portraits/hooshang_vulnerable.png"),
	"shocked": preload("res://assets/portraits/hooshang_shocked.png"),
	# Four states the beats ask for that have no drawing of their own, pointed at
	# the nearest one that does. They are listed as their own states rather than
	# the beats just saying "skeptical" twice, because the beat is where the
	# ACTING is described — when the sheet is re-cut these get their own faces
	# and not one line of dialogue moves.
	#
	# "confused" HAD its own drawing and lost it: the painted set that replaced
	# the pixel-art heads has a `shocked` where the old sheet had a `confused`.
	# It points at hesitant rather than shocked because both lines it serves are
	# quiet ones — "This doesn't feel like my cubicle..." and "I can't see a
	# thing." — and shocked is a startle, mouth open. Aliasing beat the
	# alternative, which was one 8-bit head in the middle of six paintings.
	"confused": preload("res://assets/portraits/hooshang_hesitant.png"),
	"wary": preload("res://assets/portraits/hooshang_skeptical.png"),
	"unconvinced": preload("res://assets/portraits/hooshang_skeptical.png"),
	"deflecting": preload("res://assets/portraits/hooshang_hesitant.png"),
	# Deadpan. Aliased to skeptical because the line it serves is a dry
	# restatement of something absurd, which is doubt with the inflection taken
	# out — the nearest thing already drawn.
	"flat": preload("res://assets/portraits/hooshang_skeptical.png"),
}

## Rumi's face per line, same convention as Hooshang's: a beat names the state
## it wants rather than a file.
const RUMI_FACES := {
	"serene": preload("res://assets/portraits/rumi_serene.png"),
	"sorrowful": preload("res://assets/portraits/rumi_sorrowful.png"),
	"urgent": preload("res://assets/portraits/rumi_urgent.png"),
	"warm_open": preload("res://assets/portraits/rumi_warm_open.png"),
	"wistful": preload("res://assets/portraits/rumi_wistful.png"),
}

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
## Room where the dash is granted. NOT staged from here any more: it is the dash
## tutorial's room, and scripts/dash_tutorial.gd hands the ability over at the
## moment the floor goes, with the lesson that needs it following in the same
## breath. The name stays because "where the dash comes from" is a story fact
## worth being able to read off one export, and the tests ask for it here.
@export var dash_room_name := "Level_2"
## Room holding the third encounter, at the mouth of the sounding tiles.
@export var music_room_name := "Level_7"
## Room holding the Darkshang encounter.
@export var chase_room_name := "Level_14"
## Room holding the V1 encounter.
@export var v1_room_name := "Level_V1"
## Room holding the V2 encounter.
@export var v2_room_name := "Level_V2"
## Room holding the V3 encounter.
@export var v3_room_name := "Level_V3"
## Where that room's entrance leads once the shadow has been seen — the escape
## continuing, not the room he arrived from. "" leaves the doorway alone.
@export var chase_way_back := "Level_15"

@export_group("The collapse")
## First and last room of the escape that comes apart as he walks into it, by
## level number. The whole return row: the building is failing behind him the
## entire way home, not just once. Set them equal to collapse a single room, or
## first > last to turn the beat off.
@export var collapse_first_room := 16
@export var collapse_last_room := 25
## Beat of stillness before anything moves. He walks in, and for a moment nothing
## happens — the drop lands harder for having been waited for.
@export var collapse_lead_in := 0.6
## How hard the camera rattles while a room is coming down, in px.
@export var collapse_shake := 1.6
## The single hard jolt on the frame it lets go, before the rattle settles in.
## Bigger than collapse_shake — this one is the crack, not the tremor.
@export var collapse_jolt := 2.4

@export_group("The dark rooms")
## Rooms of the escape that are unlit, by level number. Walking into one grants
## the glow outright — he earned it at the sounding tiles and this is the same
## reward, given rather than played for. The alternative was a note puzzle in
## every dark room of a chase, which is a reading test in the middle of a sprint.
##
## Re-granted rather than made permanent because NoteSequence deliberately takes
## the glow back on every room change and on every death (it owns that reward's
## lifetime, scoped to one room and one life). Fighting that would break the
## tiles puzzle; re-granting on arrival costs one line and leaves it intact.
@export var glow_rooms: Array[int] = [15, 19, 20, 21]

@export_group("The collapsing building")
## Ambient shudder and falling debris across the escape, ramping from the first
## room to the last. This is the BACKGROUND of the collapse — the building
## groaning the whole way out — under the per-room RoomCollapse event above.
##
## Rooms outside first..last get nothing at all, so the outbound half of the Act
## is untouched.
@export var ambience_first_room := 15
@export var ambience_last_room := 24
## Strength in the first room and in the last, 0..1 (see CollapseAmbience).
## Starts gentle rather than at zero: room 12 is where he has just met Darkshang
## and the building should already feel wrong. Not lower than this — at 320x180
## the camera offset a weaker room 12 asks for rounds away to no movement at all,
## so the bottom of the ramp would be indistinguishable from the Act's first half.
@export var ambience_first_strength := 0.25
@export var ambience_last_strength := 1.0
## Brick and mortar coming out of the walls, as its own ramp over its own rooms.
##
## Starts a room LATER than the dust and the shaking, and that gap is the point:
## room 12 is where he meets the shadow and the building only groans at him, and
## 13 is the first room that actually comes apart — it is where RoomCollapse
## starts dropping the level's own props (`collapse_first_room`), so it is where
## the walls should start losing pieces too. Ends with the rest of the ambience,
## at `ambience_last_room`.
@export var brick_first_room := 16
@export var brick_first_strength := 0.3
@export var brick_last_strength := 1.0
## Shape of the ramp between them. 1.0 is a straight line; above it the early
## rooms stay quiet longer and the last few get bad quickly, which is the
## difference between a building that is failing and one that has been failing
## at a constant rate for ten rooms. At 1.6 the halfway room (17) sits at about
## half strength, and rooms 19-21 carry the whole top third of the range —
## including the point where CollapseAmbience's constant tremor cuts in.
@export var ambience_curve := 1.6

@export_group("The moon turns")
## The window that turns to blood the moment the shadow appears, and the light
## paired with it. Room 11's, wired in ldtk/Act1World.tscn.
##
## The beat: Hooshang has walked past this same cold blue moon for eleven rooms.
## He crosses the threshold, Darkshang is standing there, and while Rumi explains
## what it is the moon behind them goes dark and comes back red — and it is still
## red in room 12, and every room of the escape after it. The escape row's blood
## moon is not a different moon. It is this one, after this.
##
## Paths rather than names looked up in script: the two nodes live under Backdrop
## and Lights in the world scene, and this script has no business knowing that
## layout (STYLE_GUIDE §9). "" on either turns the beat off.
@export var blood_moon_window: NodePath
@export var blood_moon_glow: NodePath
## ANY FURTHER WINDOWS IN THE SAME ROOM, paired by index with `blood_moon_glows`.
##
## Level_14's back wall carries two moons, and they are one sky: they must go
## dark and come back red as a single event, not as two windows that happen to
## have been told the same thing. So this is a LIST driven from one call site in
## one frame (`_turn_the_moon`) rather than a second copy of the beat — two call
## sites is two places for the duration, the signal or the snap-on-load to drift,
## and the failure would be a room with one red moon and one blue one.
##
## The pair above is kept as its own export rather than folded in here: it is the
## window the beat was written about, `tests/chase_route_test.gd` finds the moon
## through it, and a scene that never fills these in behaves exactly as before.
##
## A window with no glow beside it is allowed — leave the matching entry empty,
## or short the list. The window still turns; nothing lights the room from it.
@export var blood_moon_windows: Array[NodePath] = []
@export var blood_moon_glows: Array[NodePath] = []
## How long the turn takes. Tuned against the encounter's dialogue rather than
## chosen: it starts on the threshold, before the first line, and should still be
## finishing as Rumi says "Don't let it absorb you."
@export var blood_moon_seconds := 8.0

@export_group("The end of the chase")
## Where Darkshang gives up, and the line in that room he gives up at. Once
## Hooshang is past it the shadow stops dead where it stands — still there, still
## visible in the doorway, no longer coming — and nothing can restart it.
##
## The line is the cubicle bulb's world x (`CubicleBulbRoom22`, x = 100). He
## arrives at the right of room 22 at x = 200 and walks LEFT toward his desk, so
## "past" is a smaller x: he crosses under the dead office light and that is the
## moment it is over. Deliberately a NUMBER and not a lookup of the lamp — this
## script has no business reaching into the Lights node by name — but move the
## bulb and move this with it.
##
## Set HERE rather than as a SafeZone entity in LDtk only because room 22 has no
## entities to spare and this is a fact about Act I's ending. A SafeZone dragged
## across the same line would do the identical job; see safe_zone_trigger.gd.
@export var chase_ends_room := "Level_25"
@export var chase_ends_past_x := 100.0
## How long the shadow takes to thin out to nothing, in seconds.
@export var dissolve_time := 1.6
## Silence after it, before Hooshang dares say anything. The beat where he is
## alone in the room is what makes the question worth asking.
@export var after_dissolve_pause := 1.2
## Where Rumi stands, in px from Hooshang. POSITIVE — to his right, which in room
## 22 puts him between Hooshang and the sunrise window, so he is already standing
## in front of the light when he says "the ones that grew toward the light".
@export var rumi_end_offset := 34.0

@export_group("Act II")
## Where Act I hands over. Empty until the Act II world exists, which returns to
## the title screen with the run banked instead — see _play_act_two.
@export_file("*.tscn") var act_two_scene := ""
## The whirl of gold light that takes them: how bright Rumi's own glow swells,
## how long it takes to swallow the screen, and what colour it goes.
@export var whirl_energy := 9.0
@export var whirl_time := 2.2
@export var whirl_color := Color(1.0, 0.86, 0.55)
## The card that lands on the other side of it.
@export var act_card_text := "ACT II\n\nChildhood, Iran"
@export var card_fade := 0.9
@export var card_hold := 2.4

@export_group("The way home")
## Last room of the escape, and where its Exit leads. The return trip ends where
## the game began: he walks out of room 21 and back into his own cubicle.
##
## Set HERE rather than in the room's LDtk `NextRoom` field only because this is
## a story fact about Act I rather than a fact about that room — moving it into
## LDtk would work identically, and this writes the same metadata the importer
## would have. "" leaves the Exit to the normal play order.
@export var loop_room_name := "Level_25"
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
## The one ambience rig, moved from room to room rather than one per room.
var _ambience: CollapseAmbience
## Whether the room he is standing in is one of the dark ones — read on death,
## to put the glow back after NoteSequence takes it.
var _glow_here := false
## Whether we are in the room the chase ends in and still waiting for the line to
## be crossed. Set on arrival, cleared on leaving or on it happening, and the
## only thing that makes this script process at all.
var _watch_for_stand_down := false
## The chase room's threshold, held so a save can ask whether it has been crossed
## and tell it so on the way back in.
var _chase: DarkshangTrigger
var _world: LdtkWorld
var _room: Node2D
var _music_room: Node2D
var _fade: ColorRect
var _opening_played := false
## Room he was in before the current one, so a beat can ask which way he came.
var _last_room: Node2D
## Rooms that have already come down, by name. A room collapses once — walking
## back into one that has already fallen finds it fallen, not falling again.
var _collapsed := {}


func _ready() -> void:
	# Off until a room asks for it — see _apply_room_mood. Defining _process at
	# all turns it on by default, and it must not tick for the whole Act.
	set_process(false)
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
	_music_room = _find_room(music_room_name)
	if _music_room != null:
		_claim(_music_room, _play_music_beat)
	else:
		push_warning("Act1Beats: no room named '%s' — the tiles go unexplained."
			% music_room_name)
	var v1_room := _find_room(v1_room_name)
	if v1_room != null:
		_claim(v1_room, _play_level_v1_beat)
	var v2_room := _find_room(v2_room_name)
	if v2_room != null:
		_claim(v2_room, _play_level_v2_beat)
	var v3_room := _find_room(v3_room_name)
	if v3_room != null:
		_claim(v3_room, _play_level_v3_beat)

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
		# And the sky stays as he left it. A resumed run that put the cold blue
		# moon back over room 11 would be saying the encounter had not happened,
		# in the one room where the whole point is that it did.
		_turn_the_moon(false)


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
	#await _hooshang("...", "hesitant")
	await _hooshang(
		"Who are you? [p] I've worked in this office fifteen years. I've never seen you once.",
		"skeptical")

	# He says nothing yet. He only stands there, unhurried, the light along his
	# sleeves breathing slightly — that breathing is trigger.breathe(true),
	# already running since he appeared.
	await _hold(silence_time)

	await _hooshang(
		"Are you going to say something, or just stand there glowing at me...",
		"annoyed")
	#await _hooshang("...", "vulnerable")
	await _hooshang("...[p] I think I hit my head harder than I thought.", "vulnerable")

	await _hold(before_rumi_speaks)
	await _rumi("You stand at the beginning of your most important journey, Hooshang jaan.", "warm_open")
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
	await _rumi("You will not reach the parking lot from here. This is not that building.[p] It is the one you carry inside you.", "serene")
	await _hooshang("...Inside me?", "wary")
	await _rumi("Your mind has built its own rooms, and you must go down through every one.", "serene")
	await _rumi("The office that swallowed your years.[p] Your childhood.[p] And beneath them the places and things you have never let go of.", "sorrowful")
	await _hooshang("And I'm supposed to just walk through my own head.", "unconvinced")
	# One thought per banner. These four were a single line, and at ~310
	# characters it grew the box to eight rows and most of the screen — the
	# banner is built to grow (DialogueBox._fit_banner) so nothing was clipped,
	# it simply stopped reading as dialogue and started reading as a page. Every
	# other line in this scene is under 110; these now are too.
	await _rumi("Not walk through. You have done that your whole life.", "serene")
	await _rumi("To pass, you must meet what waits in each room.", "serene")
	#await _rumi("The grief you swallowed.[p] The dreams you set down \"for later.\"[p] The thoughts that still circle you in the dark.")
	await _rumi("They are not memories, jaan. They are still alive.[p] And they will not let you by until you face them.", "urgent")

	# He asks for an extension, in the exact words he has used his whole life —
	# and Rumi does not argue, he just repeats the word back. That is the beat
	# the scene is built around, so nothing else happens on top of it.
	await _hooshang("Look this really isn't a good time. I just lost my job.[p] I'll get to all that[p] ...Later.", "deflecting")
	await _rumi("...Later.[p] Yes, it's always later isn't it.", "wistful")

	await _rumi("You have knocked on this door your whole life, from the inside.[p] Now it opens.", "warm_open")
	await _rumi("You need not see the whole road, only the next step of it.", "serene")

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
	# Rumi grants nothing here — the room itself is the gift, and what he
	# hands over is permission to trust it.
	await _rumi("The dark awaits you, you think you've lost your rhythm.[p] You haven't. It's only sleeping, here, in these tiles.", "serene")
	# The actual RULE of the room, said out loud: all five pads, each once, IN
	# ORDER, and the reward is the glow (scenes/props/note_tile.gd and
	# scripts/note_sequence.gd). It is the only tutorial the puzzle gets — the
	# stretch is unlit and there is nothing to read the mechanic off — so if
	# the sequence rule ever changes, this line is part of the change.
	await _rumi("Wake the notes in their order, one after the next, until they join into a melody.[p] Complete it, and its light will gather on you, enough to carry you through the dark ahead.", "serene")

	# He answers with Rumi still standing there, same as the cubicle scene — the
	# deadpan only lands if the person it is aimed at is still in the room.
	await _hooshang("So I play the tune, I get a light.[p] ...Fine.", "flat")

	await trigger.vanish()
	player.input_locked = false
	trigger.arm_room_door()


# ------------------------------------------------------------- 4.5. vertical beats ----

func _play_level_v1_beat(player: Player, trigger: LdtkRumiTrigger) -> void:
	player.input_locked = true
	_rumi_trigger = trigger
	_dialogue_vside = DialogueBox.VSide.TOP
	player.look(1)  # face the visitor appearing on the right

	# Rumi appears 24px to the right of the player.
	var rumi_offset_x := player.global_position.x + 24.0 - trigger.global_position.x
	await trigger.appear(rumi_offset_x)
	trigger.breathe(true)

	await _rumi("These are the thoughts you would rather not have, Hooshang jaan.", "serene")
	await _rumi("You cannot strike them down.[p] There is nothing here to strike.", "serene")
	await _rumi("Let it come, watch it travel,[p] and step where it is not.", "serene")

	trigger.breathe(false)
	await trigger.vanish()
	player.input_locked = false
	trigger.arm_room_door()


func _play_level_v2_beat(player: Player, trigger: LdtkRumiTrigger) -> void:
	player.input_locked = true
	_rumi_trigger = trigger
	_dialogue_vside = DialogueBox.VSide.TOP
	player.look(1)  # face the visitor appearing on the right

	# Rumi appears 24px to the right of the player.
	var rumi_offset_x := player.global_position.x + 24.0 - trigger.global_position.x
	await trigger.appear(rumi_offset_x)
	trigger.breathe(true)

	await _rumi("And these jaan, are the thoughts you like.", "warm_open")
	await _hooshang("...These ones are going to kill me too, aren’t they?", "wary")
	await _rumi("Examine them and you will find they are made of the same thing.", "wistful")
	await _rumi("Craving is the heavier of the two.[p] Fear, at least, you already know you shouldn’t chase.", "serene")

	trigger.breathe(false)
	await trigger.vanish()
	player.input_locked = false
	trigger.arm_room_door()


func _play_level_v3_beat(player: Player, trigger: LdtkRumiTrigger) -> void:
	player.input_locked = true
	_rumi_trigger = trigger
	_dialogue_vside = DialogueBox.VSide.TOP
	player.look(1)  # face the visitor appearing on the right

	# Rumi appears 24px to the right of the player.
	var rumi_offset_x := player.global_position.x + 24.0 - trigger.global_position.x
	await trigger.appear(rumi_offset_x)
	trigger.breathe(true)

	await _rumi("Now both. Watch how they travel.[p] One rises and falls. One crosses. One circles you in the dark.", "serene")
	await _rumi("Do not sort them, jaan. Pleasant, unpleasant —[p] both are only weather.", "warm_open")
	await _rumi("Meet them the same way, and the way through opens on its own.", "serene")
	await _hooshang("Weather. Right.[p] ...And I just walk through the weather.", "flat")
	await _rumi("You have been walking through it your whole life, jaan.[p] Today you do it on purpose.", "warm_open")

	trigger.breathe(false)
	await trigger.vanish()
	player.input_locked = false
	trigger.arm_room_door()


# ------------------------------------------------------------- 5. chase ----

## Meeting Darkshang re-points the room's entrance.
##
## Level_14 is walked into from the left and the reveal turns Hooshang round, so
## the way out is the way he came — but the room behind him is not where the
## escape goes. Level_15 hangs below the row and is authored right to left (its
## PlayerStart is at its right end, its Exit at its left), which is the chase
## continuing. Without this, running back out of the boss room undoes the room
## you just entered and drops you in Level_13 with a shadow behind you.
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
	# Connected BEFORE the chase_way_back guard below, and separately from it.
	# The moon turning and the doorway re-pointing are two unrelated things that
	# happen on the same threshold, and folding them into one handler means
	# blanking `chase_way_back` to leave a doorway alone silently takes the moon
	# with it — the same trap `_wire_collapse` hit with `room_changed`.
	#
	# ON `chase_begun`, NOT `triggered`, and that is the one difference from the
	# doorway below. `triggered` fires the instant he crosses the line, which is
	# BEFORE the reveal beat — so the whole turn, eight seconds of it, played out
	# underneath the dialogue banner and was over by the time the box came down.
	# The most deliberate visual in the Act, spent behind a text box.
	#
	# The doorway keeps `triggered` for the reason written above it: a route that
	# is missed strands the player, so it must not wait on a beat that could be
	# interrupted. The moon is the opposite case — nothing depends on it, and a
	# beat that never finishes leaves a save whose resume snaps the moon red
	# anyway (`_turn_the_moon(false)`), so the worst an interruption costs here is
	# the animation, not the state.
	_chase.chase_begun.connect(func() -> void: _turn_the_moon(true))

	if chase_way_back == "":
		return
	_chase.triggered.connect(func(_player: Player) -> void:
		_world.set_way_back(room, chase_way_back))


## The moon goes dark and comes back red. See MoonWindow.eclipse() for the shape
## of it, and the `blood_moon_*` exports above for why it belongs to this script.
##
## `animated` false snaps it, for a save resumed after the encounter: the turn
## already happened, and replaying it on load would be a cutscene nobody asked
## for playing over a player who has their controls.
##
## EVERY WINDOW IN THE ROOM, IN THE SAME FRAME. `eclipse()` builds its own tween,
## so two windows started on the same frame with the same duration stay in step
## for the whole ramp — but only because nothing else ever calls them. That is
## the entire reason this loop exists rather than a second wiring somewhere.
func _turn_the_moon(animated: bool) -> void:
	var duration := blood_moon_seconds if animated else 0.0
	for pair in _moon_pairs():
		var window := get_node_or_null(pair[0] as NodePath) as MoonWindow
		if window == null:
			push_warning("Act1Beats: %s points at no MoonWindow — that moon never turns."
				% pair[0])
			continue
		var glow_path: NodePath = pair[1]
		var glow: LampFixture = null
		if not glow_path.is_empty():
			glow = get_node_or_null(glow_path) as LampFixture
		window.eclipse(duration, glow)


## The room's windows and their lights, as [window, glow] paths — the single
## export first, then the list, skipping blanks. Built fresh each time rather
## than cached in _ready: this is called from the encounter and from a resumed
## save, and both already have the nodes.
func _moon_pairs() -> Array:
	var pairs: Array = []
	if not blood_moon_window.is_empty():
		pairs.append([blood_moon_window, blood_moon_glow])
	for i in blood_moon_windows.size():
		var window_path: NodePath = blood_moon_windows[i]
		if window_path.is_empty():
			continue
		var glow_path := NodePath()
		if i < blood_moon_glows.size():
			glow_path = blood_moon_glows[i]
		pairs.append([window_path, glow_path])
	return pairs


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
	# Connected FIRST, and unconditionally. `room_changed` drives the escape's
	# ambience and the dark rooms' glow as well as the collapse, and those must
	# not stop working because the collapse's own rooms happen to be missing —
	# the three used to share this one early return.
	_last_room = _world.current_room
	_world.room_changed.connect(_on_room_changed)
	_build_ambience()
	if _world.player != null:
		_world.player.died.connect(_on_player_died)
	# Whatever room the world opened in — the debug picker drops straight into
	# room 16, and it should be lit and shaking on arrival like any other way in.
	if _world.current_room != null:
		_apply_room_mood(_world.current_room, LdtkWorld.play_index(_world.current_room))

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


## The single ambience rig, parented to the world so it is torn down with it.
func _build_ambience() -> void:
	if _ambience != null:
		return
	var scene: PackedScene = load("res://scenes/props/CollapseAmbience.tscn")
	if scene == null:
		return
	_ambience = scene.instantiate()
	_world.add_child(_ambience)


func _on_room_changed(room: Node2D) -> void:
	var arriving_from := _last_room
	_last_room = room
	var here := LdtkWorld.play_index(room)
	_apply_room_mood(room, here)
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


## Everything a room turns on just by being entered: the glow if it is one of the
## dark ones, and the ambient shudder at this room's place on the ramp.
##
## Both are re-applied on EVERY arrival rather than once, because both can be
## taken away while he is still in the room — NoteSequence revokes the glow on
## death, and a room re-entered from the far side is a fresh arrival.
func _apply_room_mood(room: Node2D, here: int) -> void:
	_glow_here = glow_rooms.has(here)
	_light_him(_glow_here)
	_stir_building(room, here)
	_watch_for_stand_down = chase_ends_room != "" and str(room.name) == chase_ends_room
	set_process(_watch_for_stand_down)


## The last thing the chase does. Once Hooshang is past the line, the shadow
## stops where it stands and stays stopped — see Darkshang.stand_down(), and the
## note on `chase_ends_past_x` for why the line is where it is.
##
## Polled rather than hung off an Area2D because room 22's entities live in LDtk
## and that file cannot always be written to (it is held open by the editor); a
## number on this script needs nothing placed. `set_process` is off everywhere
## else, so this costs one comparison per frame in exactly one room.
func _process(_delta: float) -> void:
	if not _watch_for_stand_down:
		return
	var player := _world.player if _world != null else null
	if player == null:
		return
	if player.global_position.x > chase_ends_past_x:
		return
	_watch_for_stand_down = false
	set_process(false)
	_play_chase_end()


## The end of Act I: the shadow goes out, Rumi comes back, and the light takes
## them both somewhere else.
##
## THE ONE THING HE HAD TO DO WAS STOP. The reveal in room 11 named Darkshang as
## a seed Hooshang sowed and kept watering; this pays that off — it is not beaten,
## it is left unwatered, and the roots stay in the ground. So the shadow is gone
## before the first line, and Hooshang's question is asked to an empty room.
##
## Rumi is STAGED here rather than triggered. Room 22 has no entities to spare
## (LdtkRumiTrigger.staged), and he stands between Hooshang and the sunrise
## window on purpose: his last line points at the light, and he is already in
## front of it when he says so.
func _play_chase_end() -> void:
	var player := _world.player
	if player == null:
		return
	player.input_locked = true
	# Both of them end up on the floor of a five-tile room, so the top of the
	# screen is the clear half (CLAUDE.md, dialogue rules).
	_dialogue_vside = DialogueBox.VSide.TOP

	var shadow := _shadow_in_play()
	if shadow != null:
		await shadow.dissolve(dissolve_time)
	# The room with nothing in it. He does not speak into the moment the shadow
	# vanishes — he speaks after enough silence to be sure of it.
	await _hold(after_dissolve_pause)
	await _hooshang("It's... gone?", "shocked")

	_rumi_trigger = LdtkRumiTrigger.staged(
		Vector2(player.global_position.x + rumi_end_offset, player.global_position.y))
	_world.add_child(_rumi_trigger)
	await get_tree().process_frame        # let its _ready build the glow
	await _rumi_trigger.appear()
	_rumi_trigger.breathe(true)
	await _hold(arrival_pause)

	await _rumi("No, jaan. A darkness grown this strong cannot be defeated overnight.[p] But stop watering it, and it stops growing.", "serene")
	await _hooshang("So I never had to defeat it. I just had to stop feeding it.", "vulnerable")
	await _rumi("Yes. The roots remain. It may green again someday, if ever you water it.[p] But you know the way of it now, you need only stop. Let the thought come, let it stand, let it go. Do not water it with your fear, and it withers on its own.", "wistful")
	await _rumi("Come. Not every seed you carry grew into this.[p] Let me show you the ones that grew toward the light.", "warm_open")

	await _play_act_two()


## "The whirl of gold light takes them."
##
## Rumi's own glow blooms until it has swallowed the room, the screen goes to
## GOLD rather than to black — this is not a scene ending, it is being carried
## out of one — and the card names where they land.
##
## WHERE IT GOES. `act_two_scene` is empty because Act II is not built yet, and
## an empty one returns to the title screen with the run banked. Point it at the
## Act II world when it exists and this beat needs no other change; that is the
## whole reason the hand-off is a path and not a call.
func _play_act_two() -> void:
	var bloom := create_tween().set_parallel()
	if _rumi_trigger != null:
		_rumi_trigger.breathe(false)
		bloom.tween_property(_rumi_trigger.get_node("RumiLight"), "energy",
			whirl_energy, whirl_time).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN)
	_fade.color = Color(whirl_color, 0.0)
	bloom.tween_property(_fade, "color:a", 1.0, whirl_time) \
		.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN)
	await bloom.finished

	await _show_act_card()

	SaveGame.save_now()

	# DEFERRED, and with the tree captured first. Both hand-offs tear the current
	# world down, and THIS NODE IS A CHILD OF THAT WORLD — calling either one
	# inline frees the object whose coroutine is still running, and everything
	# after the call is undefined. It showed up as `get_tree()` coming back null
	# one line later, which is the polite version of the failure.
	var tree := get_tree()
	if act_two_scene != "" and ResourceLoader.exists(act_two_scene):
		Screen.load_scene.bind(act_two_scene).call_deferred()
		return
	# Nothing to go to yet. Bank the run and hand back to the title screen, which
	# is exactly what the pause menu's QUIT does — a finished Act should leave the
	# game in a state you can start something else from, not sitting on a card.
	MainMenu.open.bind(tree).call_deferred()


## The Act II title card, over the gold. Held on a plain black plate so the words
## are readable against a screen that is currently the colour of a light bulb.
func _show_act_card() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 95
	add_child(layer)
	var plate := ColorRect.new()
	plate.color = Color(0.03, 0.025, 0.035, 0.0)
	plate.anchor_right = 1.0
	plate.anchor_bottom = 1.0
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(plate)
	var label := Label.new()
	label.text = act_card_text
	label.anchor_right = 1.0
	label.anchor_bottom = 1.0
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.62))
	label.modulate.a = 0.0
	layer.add_child(label)

	var t := create_tween().set_parallel()
	t.tween_property(plate, "color:a", 1.0, card_fade)
	t.tween_property(label, "modulate:a", 1.0, card_fade).set_delay(card_fade * 0.5)
	await t.finished
	await _hold(card_hold)
	var out := create_tween()
	out.tween_property(layer, "visible", false, 0.0).set_delay(card_fade)
	await _hold(card_fade)
	layer.queue_free()


## Grant or drop the glow, deferred a frame.
##
## The frame matters. NoteSequence is connected to the same `room_changed` signal
## and revokes the glow from its handler; which of us runs first is connection
## order, which is scene-tree order, which is not something either script should
## be relying on. Waiting a frame means this always lands after the revoke,
## whatever order they were wired in.
func _light_him(on: bool) -> void:
	await get_tree().process_frame
	var player := _world.player if _world != null else null
	if player == null:
		return
	if on:
		player.grant_glow()
	# Not revoked on the way out — NoteSequence already does that on every room
	# change, and a second revoke here would be two owners for one flag.


## Point the ambience at this room, at its strength on the ramp. Rooms off the
## ramp get intensity 0, which stops the emitters and the shudder outright.
func _stir_building(room: Node2D, here: int) -> void:
	if _ambience == null or _world == null:
		return
	var strength := 0.0
	if here >= ambience_first_room and here <= ambience_last_room:
		# Across the row, bent by `ambience_curve`. `here` is the LEVEL NUMBER,
		# which is play order (CLAUDE.md) — using the room's world position would
		# read this row backwards, since the escape runs right to left across the
		# grid, and the building would calm down as he ran.
		var span := maxi(ambience_last_room - ambience_first_room, 1)
		var t := float(here - ambience_first_room) / float(span)
		strength = lerpf(ambience_first_strength, ambience_last_strength,
			pow(t, maxf(ambience_curve, 0.01)))
	# The wall's own ramp, over its own shorter stretch of rooms.
	var masonry := 0.0
	if here >= brick_first_room and here <= ambience_last_room:
		var brick_span := maxi(ambience_last_room - brick_first_room, 1)
		var bt := float(here - brick_first_room) / float(brick_span)
		masonry = lerpf(brick_first_strength, brick_last_strength,
			pow(bt, maxf(ambience_curve, 0.01)))
	_ambience.play_in(_world.room_rect(room), strength, masonry)


## The glow is taken back on death (NoteSequence again), and nothing fires
## `room_changed` on a respawn — so without this he stands up in a dark room with
## the lights off and no way to get them back short of leaving and returning.
func _on_player_died() -> void:
	if not _glow_here:
		return
	# Long enough to clear the respawn hold, so the grant lands on the player who
	# is standing up rather than the one still coming apart.
	await get_tree().create_timer(_world.respawn_delay + 0.25).timeout
	if _glow_here and _world != null and _world.player != null:
		_world.player.grant_glow()


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


## One of Rumi's, with the face that goes with it.
##
## His face goes on whichever end of the banner he is actually standing at, so
## the two of them read as talking across a space rather than out of the same
## corner. Hooshang is always the other one, so his stays left.
func _rumi(text: String, face: String) -> void:
	var side: int = _rumi_trigger.portrait_side(_world.player) if _rumi_trigger != null \
		else DialogueBox.Side.RIGHT
	await Dialogue.say("Rumi", text, RUMI_GOLD, RUMI_FACES.get(face), side, _dialogue_vside)


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
