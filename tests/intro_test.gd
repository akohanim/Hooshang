extends Node
## Act I story beats: the waking scene, the meeting with Rumi, and the dash.
##
## Guards the things that break silently. The dialogue ORDER (a reordered or
## dropped line is invisible until you sit through the scene), that Hooshang
## starts DASHLESS and STAYS dashless through room 1 — the dash belongs to the
## second encounter, in the room whose gaps demand it — and that control comes
## back, since a cutscene that forgets input_locked = false soft-locks the game.
## Run:  godot --headless res://tests/intro_test.tscn

const WAKING: Array[String] = [
	"Where am I?",
	"This doesn't feel like my cubicle...",
]
## The SPOKEN lines of the meeting, in order, both speakers interleaved.
##
## The script's "!" and "..." beats are deliberately NOT here: they play as
## bubbles over his head rather than in the banner, and are asserted separately
## in MEETING_EMOTES. A regression that quietly routed them back through the
## dialogue box would show up as extra entries in this list.
##
## "[p]" in the last line is a breath the typewriter holds for (see
## DialogueBox.PAUSE_MARK) — it is stripped before it is drawn, so what is
## pinned here is what a player actually reads.
const MEETING: Array[String] = [
	"Hello??",
	"Who are you? I've worked in this office fifteen years. I've never seen you once.",
	"Are you going to say something, or just stand there glowing at me...",
	"I think I hit my head harder than I thought...",
	"You stand at the beginning of your most important journey, Hooshang jaan.",
	"A journey? I just wanted to make it to my car.",
	"You will not reach the parking lot from here. This is not that building. It is the one you carry inside you.",
	"...Inside me?",
	"Inside you. Your mind has built its own rooms, and you must go down through every one.",
	"The office that swallowed your years. Your childhood. And beneath them the places and things you have never let go of.",
	"And I'm supposed to just — walk through my own head. On purpose.",
	"Not walk through. You have done that your whole life.",
	"To pass, you must meet what waits in each room.",
	"The grief you swallowed. The dreams you set down \"for later.\" The thoughts that still circle you in the dark.",
	"They are not memories, jaan. They are still alive. And they will not let you by until you face them.",
	"Look — this really isn't a good time. I just lost my job. I'll get to all that. Later.",
	"...Later. Yes. That is the word, isn't it.",
	"You have knocked on this door your whole life, from the inside. Now it opens.",
	"You need not see the whole road, only the next step of it.",
	"One step. OK. One step I can probably do...",
]
const MEETING_SPEAKERS: Array[String] = [
	"Hooshang", "Hooshang", "Hooshang", "Hooshang",
	"Rumi",
	"Hooshang",
	"Rumi",
	"Hooshang",
	"Rumi", "Rumi",
	"Hooshang",
	"Rumi", "Rumi", "Rumi", "Rumi",
	"Hooshang",
	"Rumi", "Rumi", "Rumi",
	"Hooshang",
]
## The wordless beats, in order: he startles, waits for an answer that does not
## come, then deflates before admitting he might be concussed.
const MEETING_EMOTES: Array[String] = ["!", "...", "..."]
## Hooshang's face per line, in order. The mapping is a directing choice, not
## something the code can infer, so it is pinned here. Rumi's lines are "" —
## he has no portrait art yet, only the tinted stand-in.
const WAKING_FACES: Array[String] = ["dazed", "confused"]
## Three of these are read back as a state the beat did not name. The meeting
## asks for "wary", "unconvinced" and "deflecting", and Act1Beats.FACES currently
## points all three at drawings that already exist — the first two at skeptical,
## the third at hesitant — because they have no art of their own yet. What is
## observable here is the TEXTURE, so that is what is pinned: the test cannot
## tell two states apart while they share a picture, and pretending otherwise
## would be an assertion that passes on a lie. Give them their own faces and
## these three entries change with the art, not with the script.
const MEETING_FACES: Array[String] = [
	"hesitant", "skeptical", "annoyed", "vulnerable",
	"",
	"skeptical",
	"",
	"skeptical",   # "wary"
	"", "",
	"skeptical",   # "unconvinced"
	"", "", "", "",
	"hesitant",    # "deflecting"
	"", "", "",
	"hesitant",
]

## The second encounter, in order. Two lines with the gift BETWEEN them: he names
## the need and hands the ability over, and only then names the key — so the
## button is taught to someone who already has the thing it operates.
const GIFT: Array[String] = [
	"Some walls won't yield to a jump. Take this, and dash.",
	"Press the SHIFT key to dash.",
]
## Whether Hooshang already had the dash as each GIFT line went up. This is what
## pins the gift to the MIDDLE of the exchange rather than either end of it.
const GIFT_HAS_DASH: Array[bool] = [false, true]

## The third encounter, at the mouth of the sounding tiles. He complains into the
## dark BEFORE Rumi turns up — the complaint is what Rumi answers by appearing —
## and nothing is granted here, so the room stays the gift.
const TILES: Array[String] = [
	"I can't see a thing.",
	"You show up right before the parts I'm going to hate, don't you?",
	"Something waits ahead of you, in the dark. You think you've lost your rhythm. You haven't. It's only sleeping — here, in these tiles.",
	"Wake the notes in their order, one after the next, until they join into a melody. Complete it, and its light will gather on you — enough to carry you through the dark ahead.",
	"So I play the tune, I get a light. ...Fine.",
]
const TILES_SPEAKERS: Array[String] = ["Hooshang", "Hooshang", "Rumi", "Rumi", "Hooshang"]
## The last entry is "flat" in the beat — read back as skeptical, which is the
## drawing that state currently points at. Same aliasing as MEETING_FACES.
const TILES_FACES: Array[String] = ["confused", "annoyed", "", "", "skeptical"]

var failures: Array[String] = []
var world: LdtkWorld
var lines: Array[String] = []
var speakers: Array[String] = []
var faces: Array[String] = []
## Whether the player had the dash as each line went up — the cheapest way to
## place an ability grant WITHIN a conversation rather than after it.
var dash_when_said: Array[bool] = []
# Rumi's distance from Hooshang, sampled when he appears and when he touches him.
var _gap_on_arrival := -1.0
var _gap_at_touch := -1.0
var _watch: LdtkRumiTrigger
# The gift mote: where it was first seen, and where it was last seen. The point
# of the beat is that the light MOVES from Rumi to Hooshang, and every way that
# has broken so far was silent — the mote sourced from Rumi's aura (above his
# head), or starting so far out along his arm that it crossed 6px and read as a
# flicker. Both looked fine in a still frame.
var _mote_first := Vector2.INF
var _mote_last := Vector2.INF
# Wordless beats seen, in order, and the instance already counted.
var emotes: Array[String] = []
var _last_emote_id := 0
# Every distinct typewriter speed seen while the scene played. There must only
# ever be one: beats used to slow the reveal down for a muttered line, which
# reads as a different KIND of text rather than a quieter one.
var _speeds: Array[float] = []
## Which end of the banner each line's portrait sat at. A speaker's face belongs
## on the side they are standing on, and Rumi materialises to Hooshang's right.
var sides: Array[String] = []
## Which screen edge the banner sat flush against for each line: "top" or
## "bottom". A director's choice per room (DialogueBox.VSide, act1_beats.gd's
## `_dialogue_vside`) — pinned here so a future scene that forgets to set it, or
## a room whose staging changes underneath a stale choice, fails loudly instead
## of quietly covering the thing the player is meant to be looking at.
var vsides: Array[String] = []
## 1 if Rumi materialised to Hooshang's right this beat, 0 if left, -1 unknown.
var _rumi_on_right := -1
## Brightest his aura, and his own body glow, got this beat — both sampled while
## he was actually on screen.
var _light_peak := 0.0
var _glow_peak := 0.0
var _glow_report := ""
## Seconds between Rumi finishing his entrance and the next line going up.
var _arrival_msec := 0
var _arrival_gap := -1.0
## What the ledge and staging checks measured, for their failure messages.
var _ledge_report := ""
var _between_report := ""


func _ready() -> void:
	world = load("res://ldtk/Act1World.tscn").instantiate()
	add_child(world)
	await _frames(5)
	_check(_fade_alpha() > 0.9, "opens on a black screen")

	await _run_scene(600)
	_check(_fade_alpha() < 0.01, "fades up from black")
	_check(not world.player.input_locked, "control is returned after the waking scene")
	_check(not world.player.has_dash, "Hooshang starts DASHLESS — the gift has to mean something")
	_check(lines == WAKING, "waking lines, in order  [got %s]" % str(lines))
	_check(faces == WAKING_FACES, "waking portraits: dazed then confused  [got %s]" % str(faces))
	# He wakes near mid-room, well clear of the ceiling — the banner sits at the
	# TOP of the screen, flush with it, not floating with a gap.
	_check(vsides.all(func(v: String) -> bool: return v == "top"),
		"room 1's banner sits flush at the TOP of the screen  [got %s]" % str(vsides))

	var trigger := _find_trigger(world.rooms[0])
	_check(trigger != null, "room 1 has a Rumi trigger")
	_check(trigger != null and trigger.defer_to_cutscene,
		"the trigger defers its beat to the cutscene (no stray one-liner)")

	lines.clear()
	speakers.clear()
	faces.clear()
	emotes.clear()
	sides.clear()
	vsides.clear()
	dash_when_said.clear()
	_watch = trigger
	world.player.global_position = trigger.global_position + Vector2(0, 16)
	# Roomier than the other beats: the three wordless bubbles are on timers
	# rather than button presses, and add a few seconds nothing can skip.
	await _run_scene(2000)

	_check(lines == MEETING, "meeting lines, in order  [got %s]" % str(lines))
	_check(speakers == MEETING_SPEAKERS,
		"Rumi stays silent until Hooshang has run out of things to say  [got %s]"
			% str(speakers))
	_check(faces == MEETING_FACES,
		"meeting portraits, one state per line  [got %s]" % str(faces))
	_check(emotes == MEETING_EMOTES,
		"the wordless beats play as bubbles, in order  [got %s]" % str(emotes))
	_check(_speeds.size() == 1,
		"every line types at the same speed  [saw %s]" % str(_speeds))
	_check(sides == _sides_for(MEETING_SPEAKERS, _rumi_on_right == 1),
		"each face sits on the side that speaker is standing on  [Rumi %s, got %s]" % [
			"right" if _rumi_on_right == 1 else "left", str(sides)])
	_check(vsides.all(func(v: String) -> bool: return v == "top"),
		"room 1's banner stays at the TOP through the meeting too  [got %s]" % str(vsides))
	_check(not world.player.has_dash,
		"room 1 grants NO dash — the first meeting is an introduction, not a gift")
	_check(not world.player.input_locked, "control is returned after the meeting")
	_check(_rumi_alpha(trigger) < 0.01, "Rumi has faded out again")
	_check(_door_armed(), "Rumi leaving arms the story door")
	# Staging: he must arrive at a distance and then close it. He used to
	# materialise exactly on top of Hooshang (the player is standing ON the
	# trigger when it fires), which left the reaching-out beat nothing to cross.
	_check(_gap_on_arrival >= 16.0,
		"Rumi arrives at a distance, not inside Hooshang  [%.0fpx]" % _gap_on_arrival)
	_check(_gap_at_touch > 0.0 and _gap_at_touch < _gap_on_arrival,
		"he closes that distance to reach out  [%.0fpx -> %.0fpx]" % [
			_gap_on_arrival, _gap_at_touch])
	_check_gift("the meeting")

	# --- second encounter, room 2: the dash ---
	lines.clear()
	speakers.clear()
	faces.clear()
	sides.clear()
	vsides.clear()
	dash_when_said.clear()
	_gap_on_arrival = -1.0
	_gap_at_touch = -1.0
	_rumi_on_right = -1
	_mote_first = Vector2.INF
	_mote_last = Vector2.INF
	world._enter_room(world.rooms[1], true)
	await _frames(10)
	var gift_trigger := _find_trigger(world.rooms[1])
	_check(gift_trigger != null, "room 2 has a Rumi trigger")
	_check(gift_trigger != null and gift_trigger.defer_to_cutscene,
		"room 2's trigger defers to the cutscene too")
	_watch = gift_trigger
	world.player.global_position = gift_trigger.global_position + Vector2(0, 16)
	await _run_scene(900)

	_check(lines == GIFT, "the dash lines, in order  [got %s]" % str(lines))
	_check(speakers == ["Rumi", "Rumi"], "both spoken by Rumi  [got %s]" % str(speakers))
	_check(dash_when_said == GIFT_HAS_DASH,
		"the gift lands BETWEEN the two lines — offer, touch, then the key  [got %s]"
			% str(dash_when_said))
	_check(sides == _sides_for(["Rumi", "Rumi"], _rumi_on_right == 1),
		"his face is on his side of the screen here too  [Rumi %s, got %s]" % [
			"right" if _rumi_on_right == 1 else "left", str(sides)])
	_check(vsides.all(func(v: String) -> bool: return v == "top"),
		"room 2's banner sits at the TOP too — he is at floor height here  [got %s]"
			% str(vsides))
	_check(world.player.has_dash, "the SECOND encounter grants the dash")
	_check(not world.player.input_locked, "control is returned after the gift")
	_check(_rumi_alpha(gift_trigger) < 0.01, "Rumi has faded out again")
	_check_gift("the gift")

	# --- third encounter, room 5: the sounding tiles ---
	lines.clear()
	speakers.clear()
	faces.clear()
	sides.clear()
	vsides.clear()
	dash_when_said.clear()
	_gap_on_arrival = -1.0
	_gap_at_touch = -1.0
	_rumi_on_right = -1
	_mote_first = Vector2.INF
	_mote_last = Vector2.INF
	_light_peak = 0.0
	_glow_peak = 0.0
	_arrival_msec = 0
	_arrival_gap = -1.0
	var tile_room := _room_named("Level_4")
	_check(tile_room != null, "the world has room 5 (Level_4)")
	if tile_room != null:
		world._enter_room(tile_room, true)
		await _frames(10)
		var tile_trigger := _find_trigger(tile_room)
		_check(tile_trigger != null, "room 5 has a Rumi trigger")
		_check(tile_trigger != null and tile_trigger.defer_to_cutscene,
			"room 5's trigger defers to the cutscene too")
		_watch = tile_trigger
		# On the trigger, not 16px under it like the other two rooms: this ledge
		# sits only 8px below the trigger, so the usual drop-in spawns him INSIDE
		# the floor tile and every measurement taken off him afterwards is junk.
		world.player.global_position = tile_trigger.global_position
		await _run_scene(900)

		_check(lines == TILES, "the tile lines, in order  [got %s]" % str(lines))
		_check(speakers == TILES_SPEAKERS,
			"he complains into the dark before Rumi answers  [got %s]" % str(speakers))
		_check(faces == TILES_FACES,
			"tile portraits, one state per line  [got %s]" % str(faces))
		_check(sides == _sides_for(TILES_SPEAKERS, _rumi_on_right == 1),
			"each face sits on the side that speaker is standing on  [Rumi %s, got %s]" % [
				"right" if _rumi_on_right == 1 else "left", str(sides)])
		# The one room where he and Rumi are both up near the ceiling, not the
		# floor — a TOP banner would sit right on top of them. This is the
		# concrete case the vside rule exists for.
		_check(vsides.all(func(v: String) -> bool: return v == "bottom"),
			"room 5's banner sits flush at the BOTTOM — he and Rumi are up near the ceiling here  [got %s]"
				% str(vsides))
		# The beat is about crossing what you cannot see. A Rumi who arrives at his
		# usual brightness answers that himself, so this pins the dim entrance —
		# including the breath, which used to swell to a fixed 1.9 and would have
		# hauled him back up to full a second and a half in.
		_check(_light_peak > 0.0 and _light_peak < 1.0,
			"the POOL he casts stays faint, breath and all  [peak %.2f]" % _light_peak)
		# ...but he is still a luminous figure, and the Act is nearly black. The
		# aura used to be the only thing lifting him out of the CanvasModulate, so
		# dimming it for this beat dimmed HIM. His own glow is separate now.
		_check(_glow_peak > 1.0,
			"he glows HIMSELF, faint pool or not  [peak %.2f]" % _glow_peak)
		_check(_glow_lights_only_rumi(tile_trigger),
			"and that glow touches nothing but him  [%s]" % _glow_report)
		# The scene holds on him before anyone speaks. Timed off the real clock,
		# since a "pause" that no longer pauses is invisible in a line list.
		_check(_arrival_gap >= 1.5,
			"the scene holds on his arrival before Hooshang speaks  [%.1fs]" % _arrival_gap)
		# Nothing changes hands here — no mote, because the room is the gift.
		_check(_mote_first == Vector2.INF,
			"no ability is granted at the tiles — the room is the gift")
		_check(not world.player.input_locked, "control is returned after the tiles")
		_check(_rumi_alpha(tile_trigger) < 0.01, "Rumi has faded out again")
		# He has to be standing on real floor at Hooshang's own height. The ledge
		# under the trigger runs out one tile along, where the tiles begin, so an
		# offset sized like the other beats' drops him into the first gap.
		_check(_on_ledge(tile_trigger),
			"he stands across the gap on solid floor  [%s]" % _ledge_report)
		# ...and on the far side of it, or "run across these tiles" is being said
		# by someone standing next to you.
		_check(_tiles_between(tile_trigger),
			"the sounding tiles are BETWEEN them  [%s]" % _between_report)

	await _check_lines_fit()

	if failures.is_empty():
		print("INTRO TEST: ALL PASS")
	else:
		print("INTRO TEST: %d FAILURE(S)" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)


## Every scripted line has to fit the banner it is drawn in.
##
## At this type size a long line wraps to three rows, and the banner was a fixed
## height sized for two — so the third row was simply cut off. Nothing catches
## that except reading the line in game, which is exactly the kind of thing
## nobody does for the fifteenth line of a cutscene. DialogueBox now grows to
## fit; this checks it actually did, through the real say() path rather than a
## copy of the sizing rule.
##
## Font metrics are real under --headless (verified), so this measures the same
## numbers the game will.
func _check_lines_fit() -> void:
	var box: DialogueBox = Dialogue
	var label: Label = box.get_node("TextLabel")
	var font: Font = label.get_theme_font("font")
	var size: int = label.get_theme_font_size("font_size")
	var spacing := float(label.get_theme_constant("line_spacing"))
	var clipped: Array[String] = []
	for text in WAKING + MEETING + GIFT + TILES:
		# With a portrait, which is the narrower and therefore worse case.
		box.say("Hooshang", text, Color(1, 1, 1, 1))
		await get_tree().process_frame
		var width := label.offset_right - label.offset_left
		var wrapped := font.get_multiline_string_size(
			label.text, HORIZONTAL_ALIGNMENT_CENTER, width, size)
		var rows := maxi(int(round(wrapped.y / float(size))), 1)
		var needed: float = wrapped.y + spacing * (rows - 1)
		if needed > label.offset_bottom - label.offset_top:
			clipped.append("%.0f>%.0f '%s'" % [
				needed, label.offset_bottom - label.offset_top, text.substr(0, 32)])
		box.line_finished.emit()
		await get_tree().process_frame
	_check(clipped.is_empty(),
		"every line fits its banner  %s" % ("" if clipped.is_empty() else str(clipped)))


## Expected portrait side per line, given which side Rumi actually turned up on.
func _sides_for(who: Array[String], rumi_right: bool) -> Array[String]:
	var out: Array[String] = []
	for name in who:
		if name == "Rumi":
			out.append("right" if rumi_right else "left")
		else:
			out.append("left")   # Hooshang is by definition the other one
	return out


## Which half of the banner the portrait frame is actually sitting in. Read off
## the live layout rather than off the Side we passed in, so this catches the
## mirroring being wrong as well as the wrong side being asked for.
func _portrait_side() -> String:
	var box: DialogueBox = Dialogue
	if not box.portrait_frame.visible:
		return ""
	var middle: float = DialogueBox.CANVAS_WIDTH * 0.5
	return "right" if box.portrait_frame.offset_left >= middle else "left"


## Which screen edge the banner is CURRENTLY flush against, read off the live
## layout rather than off the vside that was passed in — the same reasoning as
## _portrait_side(): this catches the placement math being wrong, not just the
## wrong choice being asked for. Flush top and flush bottom are unambiguous
## (0.0 and CANVAS_HEIGHT exactly, from a uniform shift with nothing to round);
## anything else is neither and reads as its own failure downstream rather than
## silently passing as one side or the other.
func _vside_name() -> String:
	var box: DialogueBox = Dialogue
	if is_zero_approx(box.banner.offset_top):
		return "top"
	if is_equal_approx(box.banner.offset_bottom, DialogueBox.CANVAS_HEIGHT):
		return "bottom"
	return "neither  [top=%.1f bottom=%.1f]" % [box.banner.offset_top, box.banner.offset_bottom]


## Record each reaction bubble once, by instance — two identical "..." beats in
## one scene are two events, and comparing kinds alone would merge them.
func _sample_emote() -> void:
	var bubble := get_tree().get_first_node_in_group("emote") as EmoteBubble
	if bubble == null or bubble.get_instance_id() == _last_emote_id:
		return
	_last_emote_id = bubble.get_instance_id()
	emotes.append(bubble.kind_name())


## Follow the gift mote for as long as it exists.
func _sample_gift() -> void:
	var mote := _watch.get_node_or_null("Gift") as Node2D
	if mote == null:
		return
	if _mote_first == Vector2.INF:
		_mote_first = mote.global_position
	_mote_last = mote.global_position


## Assert the light actually crossed from Rumi to Hooshang, for `who`'s beat.
func _check_gift(who: String) -> void:
	if _mote_first == Vector2.INF:
		_check(false, "%s: a gift mote leaves Rumi" % who)
		return
	var rumi := _watch.get_node_or_null("Rumi") as Node2D
	var him := world.player.global_position
	_check(_mote_first.distance_to(him) > _mote_last.distance_to(him),
		"%s: the mote ends up closer to Hooshang than it started  [%.0fpx -> %.0fpx]" % [
			who, _mote_first.distance_to(him), _mote_last.distance_to(him)])
	_check(_mote_first.distance_to(_mote_last) >= 8.0,
		"%s: it crosses a visible distance, not a flicker  [%.0fpx]" % [
			who, _mote_first.distance_to(_mote_last)])
	# It has to leave from his body, not his aura: the aura light sits 19px up,
	# which is over his head, and sourcing there lobbed the mote at the ceiling.
	if rumi != null:
		_check(absf(_mote_first.y - rumi.global_position.y) <= 8.0,
			"%s: it leaves Rumi at body height, not above his head  [%.0fpx off]" % [
				who, absf(_mote_first.y - rumi.global_position.y)])


## Let the scene play, recording each new line and pressing on through it.
func _run_scene(max_frames: int) -> void:
	var box: CanvasLayer = Dialogue
	var name_label: Label = box.get_node("NameLabel")
	var text_label: Label = box.get_node("TextLabel")
	var seen := ""
	for i in max_frames:
		await _frames(1)
		_sample_staging()
		if not box.visible:
			continue
		var key := "%s|%s" % [name_label.text, text_label.text]
		if key != seen:
			seen = key
			lines.append(text_label.text)
			speakers.append(name_label.text if name_label.visible else "")
			faces.append(_face_name())
			sides.append(_portrait_side())
			vsides.append(_vside_name())
			dash_when_said.append(world.player.has_dash)
			# The first line after he finishes arriving — how long the scene held
			# on him with nobody talking.
			if _arrival_msec > 0 and _arrival_gap < 0.0:
				_arrival_gap = (Time.get_ticks_msec() - _arrival_msec) / 1000.0
		# First press finishes the typewriter, second dismisses. Has to be a real
		# InputEvent — DialogueBox listens in _unhandled_input, which
		# Input.action_press() does not feed.
		_press_jump()
		await _frames(2)
		_press_jump()
		await _frames(2)


## Record how far Rumi is from Hooshang at the two moments that matter.
func _sample_staging() -> void:
	var speed: float = Dialogue.chars_per_second
	if not _speeds.has(speed):
		_speeds.append(speed)
	_sample_emote()
	if _watch == null:
		return
	_sample_gift()
	var rumi := _watch.get_node_or_null("Rumi") as Node2D
	if rumi == null:
		return
	# His aura, while he is actually on screen — during the fades it is on its way
	# up or down and says nothing about how bright he MEANT to arrive.
	var light := _watch.get_node_or_null("RumiLight") as PointLight2D
	var glow := _watch.get_node_or_null("RumiGlow") as PointLight2D
	if (rumi as CanvasItem).modulate.a > 0.99:
		if light != null:
			_light_peak = maxf(_light_peak, light.energy)
		if glow != null:
			_glow_peak = maxf(_glow_peak, glow.energy)
	var gap: float = absf(rumi.global_position.x - world.player.global_position.x)
	if _gap_on_arrival < 0.0 and (rumi as CanvasItem).modulate.a > 0.99:
		_gap_on_arrival = gap
		# Which side he actually materialised on. Not a constant: it follows the
		# direction Hooshang came from, and when he drops onto a trigger from
		# directly above (as this test does) that is decided by sub-pixel drift.
		# The invariant worth asserting is that his FACE follows his FEET, so it
		# is read from the staging rather than pinned to one side.
		_rumi_on_right = 1 if rumi.global_position.x > world.player.global_position.x else 0
		_arrival_msec = Time.get_ticks_msec()
	# Closest approach, which is the reach-out moment. has_dash can't be the
	# marker any more: room 1's touch deliberately grants nothing.
	if _gap_at_touch < 0.0 or gap < _gap_at_touch:
		if _gap_on_arrival >= 0.0:
			_gap_at_touch = gap


## Which portrait state is on screen, from the texture's filename ("" if none).
func _face_name() -> String:
	var tr: TextureRect = Dialogue.get_node("Portrait")
	if not tr.visible or tr.texture == null:
		return ""
	var path := tr.texture.resource_path
	if not path.contains("hooshang_"):
		return ""
	return path.get_file().get_basename().replace("hooshang_", "")


func _press_jump() -> void:
	var ev := InputEventAction.new()
	ev.action = "jump"
	ev.pressed = true
	Input.parse_input_event(ev)


func _fade_alpha() -> float:
	for c in world.get_node("Act1Beats").get_children():
		for cc in c.get_children():
			if cc is ColorRect:
				return (cc as ColorRect).color.a
	return -1.0


## The room node with this LDtk identifier, or null.
func _room_named(name: String) -> Node2D:
	for room in world.rooms:
		if room.name == name:
			return room
	return null


## Is Rumi standing on the same floor Hooshang is, rather than down in one of the
## gaps the sounding tiles fill?
##
## "Is there ground under him" is not enough on its own to catch this: appear()
## snaps him to WHATEVER floor is below, so a bad offset does not leave him
## hovering — it quietly drops him a tile into the first hole, standing inside
## MusicNote1. Comparing the two floor heights is what makes that a failure.
##
## Both sampled from the physics world rather than the tilemap: the room's holes
## are exactly where grid arithmetic goes subtly wrong.
func _on_ledge(trigger: LdtkRumiTrigger) -> bool:
	var rumi := trigger.get_node_or_null("Rumi") as Node2D
	if rumi == null:
		_ledge_report = "no Rumi sprite"
		return false
	var his := _floor_under(rumi.global_position)
	var ours := _floor_under(world.player.global_position)
	if is_inf(his):
		_ledge_report = "nothing under him at all (x=%.0f)" % rumi.global_position.x
		return false
	_ledge_report = "his floor y=%.0f, Hooshang's y=%.0f" % [his, ours]
	return absf(his - ours) < 8.0


## Is Rumi's self-glow reaching him and NOTHING else in his room?
##
## A light bright enough to make a man luminous under a 0.05 CanvasModulate would
## also blow out the wall behind him, which is why it is cull-masked to a layer
## only his sprite listens on. That is a two-sided arrangement — the light's mask
## and the sprite's — and either half being wrong is invisible except as a room
## that quietly stopped being dark.
func _glow_lights_only_rumi(trigger: LdtkRumiTrigger) -> bool:
	var glow := trigger.get_node_or_null("RumiGlow") as PointLight2D
	if glow == null:
		_glow_report = "no RumiGlow light"
		return false
	if glow.range_item_cull_mask != LdtkRumiTrigger.GLOW_LAYER:
		_glow_report = "glow cull mask is %d, not the glow layer" % glow.range_item_cull_mask
		return false
	var listening: Array[String] = []
	_collect_glow_lit(trigger.get_parent(), listening)
	_glow_report = "%d item(s) on the glow layer: %s" % [listening.size(), str(listening)]
	return listening == ["Rumi"]


## Names of every CanvasItem under `node` that the glow layer can light.
func _collect_glow_lit(node: Node, out: Array[String]) -> void:
	if node is CanvasItem and (node as CanvasItem).light_mask & LdtkRumiTrigger.GLOW_LAYER:
		out.append(node.name)
	for child in node.get_children():
		_collect_glow_lit(child, out)


## Do the sounding tiles lie between Hooshang and Rumi?
##
## This is the whole staging of the beat in one number. Rumi is meant to be the
## far side of a stretch you cannot see, so "run across these tiles" is spoken
## across them — a Rumi standing on the near ledge would be pointing at the floor
## by his own feet.
func _tiles_between(trigger: LdtkRumiTrigger) -> bool:
	var rumi := trigger.get_node_or_null("Rumi") as Node2D
	if rumi == null:
		_between_report = "no Rumi sprite"
		return false
	var him := world.player.global_position.x
	var her := rumi.global_position.x
	var lo := minf(him, her)
	var hi := maxf(him, her)
	var between := 0
	for tile in get_tree().get_nodes_in_group("note_tile"):
		if tile.get_parent() != trigger.get_parent():
			continue  # another room's tiles — every room is loaded at once
		var x: float = (tile as Node2D).global_position.x
		if x > lo and x < hi:
			between += 1
	_between_report = "%d tiles in the %.0fpx between them" % [between, hi - lo]
	return between >= 3


## World y of the first solid surface below `from`, or INF.
func _floor_under(from: Vector2) -> float:
	var query := PhysicsRayQueryParameters2D.create(from, from + Vector2(0.0, 64.0))
	query.collision_mask = 1  # world
	var hit := world.get_world_2d().direct_space_state.intersect_ray(query)
	return hit.position.y if hit else INF


func _rumi_alpha(trigger: Node) -> float:
	var rumi := trigger.get_node_or_null("Rumi") as CanvasItem
	return rumi.modulate.a if rumi != null else -1.0


func _door_armed() -> bool:
	for d in get_tree().get_nodes_in_group("story_door"):
		if d is LdtkDoor and world.rooms[0].is_ancestor_of(d):
			return bool(d._armed)
	return false


func _find_trigger(n: Node) -> LdtkRumiTrigger:
	if n is LdtkRumiTrigger:
		return n
	for c in n.get_children():
		var f := _find_trigger(c)
		if f != null:
			return f
	return null


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _check(cond: bool, name: String) -> void:
	print(("  PASS  " if cond else "  FAIL  ") + name)
	if not cond:
		failures.append(name)
