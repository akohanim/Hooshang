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
	"...I fell. I remember falling.",
	"This doesn't feel like my cubicle...",
]
const MEETING: Array[String] = [
	"Hello?",
	"I've worked in this office nine years. I've never once seen you at an all hands.",
	"Are you going to say something, or just stand there glowing at me.",
	"I think I hit my head harder than I thought.",
	"You have knocked on this door your whole life from the inside.",
]
## Hooshang's face per line, in order. The mapping is a directing choice, not
## something the code can infer, so it is pinned here.
const WAKING_FACES: Array[String] = ["dazed", "confused"]
const MEETING_FACES: Array[String] = ["hesitant", "skeptical", "annoyed", "vulnerable", "", ""]

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
	_watch = trigger
	world.player.global_position = trigger.global_position + Vector2(0, 16)
	await _run_scene(900)

	_check(lines == MEETING, "meeting lines, in order  [got %s]" % str(lines))
	_check(speakers == ["Hooshang", "Hooshang", "Hooshang", "Hooshang", "Rumi"],
		"Rumi stays silent until his one line  [got %s]" % str(speakers))
	_check(faces == MEETING_FACES.slice(0, faces.size()),
		"meeting portraits: hesitant, skeptical, annoyed, vulnerable  [got %s]" % str(faces))
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

	if failures.is_empty():
		print("INTRO TEST: ALL PASS")
	else:
		print("INTRO TEST: %d FAILURE(S)" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)


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
