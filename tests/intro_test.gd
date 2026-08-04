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
	"Who are you? I've worked in this office fifteen years. I've never once seen you at an all hands.",
	"Are you going to say something, or just stand there glowing at me...",
	"I think I hit my head harder than I thought...",
	"You stand at the beginning of your most important journey, Hooshang jaan",
	"A journey? I just wanted to make it to my car.",
	"Do not turn away now. The way out is the way through, and the way through is inward.",
	"You have knocked on this door your whole life, from the inside.",
	"Walk toward the light. You need not see the whole road, only the next step of it.",
	"One step. Okay. One step I can probably do.",
]
const MEETING_SPEAKERS: Array[String] = [
	"Hooshang", "Hooshang", "Hooshang", "Hooshang",
	"Rumi",
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
const MEETING_FACES: Array[String] = [
	"hesitant", "skeptical", "annoyed", "vulnerable",
	"",
	"skeptical",
	"", "", "",
	"hesitant",
]

const GIFT: Array[String] = [
	"Some gaps won't yield to a jump. Press the SHIFT key to dash.",
]

var failures: Array[String] = []
var world: LdtkWorld
var lines: Array[String] = []
var speakers: Array[String] = []
var faces: Array[String] = []
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

	var trigger := _find_trigger(world.rooms[0])
	_check(trigger != null, "room 1 has a Rumi trigger")
	_check(trigger != null and trigger.defer_to_cutscene,
		"the trigger defers its beat to the cutscene (no stray one-liner)")

	lines.clear()
	speakers.clear()
	faces.clear()
	emotes.clear()
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
	_gap_on_arrival = -1.0
	_gap_at_touch = -1.0
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

	_check(lines == GIFT, "the dash line, alone  [got %s]" % str(lines))
	_check(speakers == ["Rumi"], "spoken by Rumi  [got %s]" % str(speakers))
	_check(world.player.has_dash, "the SECOND encounter grants the dash")
	_check(not world.player.input_locked, "control is returned after the gift")
	_check(_rumi_alpha(gift_trigger) < 0.01, "Rumi has faded out again")
	_check_gift("the gift")
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
	for text in WAKING + MEETING + GIFT:
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
	var gap: float = absf(rumi.global_position.x - world.player.global_position.x)
	if _gap_on_arrival < 0.0 and (rumi as CanvasItem).modulate.a > 0.99:
		_gap_on_arrival = gap
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
