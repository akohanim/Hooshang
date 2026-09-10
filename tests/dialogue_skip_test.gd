extends Node
## Hold "skip_dialogue" (X) for skip_hold_time seconds to skip a WHOLE
## dialogue conversation — scenes/ui/dialogue_box.gd's _tick_skip_hold and
## _skip_armed — and the "Hold X to skip" reminder that appears after
## hint_delay seconds (_tick_skip_hint).
##
## THIS IS NOT A PAGE-BY-PAGE FAST-FORWARD. The line on screen when the hold
## crosses the threshold closes itself out with its own ordinary close
## animation (a smooth transition, not a hard cut), and every line AFTER it
## in the same conversation never opens at all — say() returns before
## touching a single node. Covers the shape of bug a hold-timer feature
## actually breaks in: firing too early, not firing at all, not surviving
## the gap between two lines of one conversation, and — the one that would
## be invisible in play until a player literally walked into a cutscene with
## a finger already resting on the key — firing on a hold that has nothing
## to do with the dialogue that just opened.
##
## Reveal timing is driven BY HAND (box._process(delta), synthetic 1/60
## deltas) the same way voice_blip_test.gd does, for the same reason: idle
## delta has no fixed relationship to wall-clock frames in a headless run.
## Anything that waits on say()'s own entrance/close animation is the
## exception — those are PHYSICS SceneTreeTimers, so those waits use real
## physics frames instead, same as intro_test.gd.
##
## Run:  godot --headless res://tests/dialogue_skip_test.tscn

var failures: Array[String] = []
var _closed_count := 0


func _ready() -> void:
	var box: DialogueBox = Dialogue
	box.dialogue_closed.connect(func(): _closed_count += 1)
	# Frozen to a crawl so the NATURAL typewriter reveal can never coincide
	# with — and be mistaken for — a skip completing it: every "not
	# revealing" this test observes has to be _tick_skip_hold's doing, not
	# ordinary pagination/timing arithmetic happening to land on the same
	# page length at the same moment.
	box.chars_per_second = 0.1
	const LONG_LINE := "This is a considerably long line of dialogue, written specifically so that it takes several real seconds for the ordinary typewriter reveal to finish on its own."

	# --- released before the threshold: nothing happens -----------------------
	await _say_line(box, "Hooshang", LONG_LINE)
	Input.action_press("skip_dialogue")
	_tick(box, box.skip_hold_time - 0.2)
	_check(box._revealing, "holding short of the threshold does not skip yet")
	Input.action_release("skip_dialogue")
	_tick(box, 1.0)
	_check(box._revealing,
		"...and releasing before the threshold does not carry over either")
	await _close(box)

	# --- a release resets the accumulated hold, even mid-threshold ------------
	await _say_line(box, "Hooshang", LONG_LINE)
	Input.action_press("skip_dialogue")
	_tick(box, box.skip_hold_time - 0.2)
	Input.action_release("skip_dialogue")
	_tick(box, 1.0 / 60.0)  # let _tick_skip_hold actually observe the release
	Input.action_press("skip_dialogue")
	_tick(box, box.skip_hold_time - 0.2)  # two short holds, neither alone enough
	_check(box._revealing,
		"two short holds separated by a release never add up to one long one")
	Input.action_release("skip_dialogue")
	await _close(box)

	# --- crossing the threshold closes the CURRENT line, smoothly, on its own -
	await _say_line(box, "Hooshang", LONG_LINE)
	var closed_before := _closed_count
	Input.action_press("skip_dialogue")
	_tick(box, box.skip_hold_time + 0.05)
	_check(not box._revealing,
		"crossing the hold threshold finishes the current page's reveal instantly")
	_check(box.text_label.visible_characters == -1,
		"...with the [fade] wrapper dropped, same as a natural finish")
	_check(not box._active,
		"...and the line starts closing itself the SAME tick — no next page shown, no button needed")
	# The close-out itself is a real (physics-timed) animation, not a hard
	# cut — give it real frames to actually run rather than asserting
	# `visible == false` the instant _active drops.
	var guard := 0
	while box.visible and guard < 60:
		await get_tree().physics_frame
		guard += 1
	_check(not box.visible and _closed_count == closed_before + 1,
		"...and shortly after, the box has genuinely closed (dialogue_closed fired)  [%d frames]" % guard)

	# --- and holding through it: the NEXT line in the conversation never opens at all
	#
	# Not "opens, then gets skipped" — never touches a single node. If the
	# hold had to restart from zero here — the bug this whole test exists to
	# catch — this would open and start revealing normally.
	var was_visible := box.visible
	await box.say("Hooshang", "And a second line, right after the first.")
	_check(not box._active,
		"a second line in the same conversation never activates while skip is still armed")
	_check(box.visible == was_visible,
		"...the box's visibility never changes — it truly never opened")
	Input.action_release("skip_dialogue")

	# --- a stale hold from BEFORE any dialogue cannot zap the first line ------
	#
	# The exact scenario a player could hit by accident: resting a finger on
	# X (dash's own key, inert during dialogue but not before it opens) while
	# just walking around, then walking into a trigger. This matters MORE now
	# than it would for a page-by-page skip: a stale hold slipping past this
	# guard would suppress a whole conversation the player never saw open.
	Input.action_press("skip_dialogue")
	_check(not box._active, "sanity: no line is up yet while the stale hold accrues")
	_tick(box, box.skip_hold_time + box.SKIP_HOLD_GAP + 1.0)  # well past both
	await _say_line(box, "Hooshang", LONG_LINE)
	_check(box._revealing,
		"a hold that predates the dialogue by more than SKIP_HOLD_GAP does not skip the first line")
	Input.action_release("skip_dialogue")
	await _close(box)

	# --- the "Hold X to skip" reminder appears after hint_delay, not before ---
	await _say_line(box, "Hooshang", LONG_LINE)
	_check(not box.skip_hint.visible, "the skip hint is not shown the moment a line opens")
	_tick(box, box.hint_delay - 0.2)
	_check(not box.skip_hint.visible, "...nor just short of hint_delay")
	_tick(box, 0.3)
	_check(box.skip_hint.visible,
		"...but appears once the line has been up for hint_delay seconds")
	await _close(box)
	_check(not box.skip_hint.visible, "...and disappears once the line closes")

	# --- and does not carry over to the next line ------------------------------
	await _say_line(box, "Hooshang", "A second, unrelated line.")
	_check(not box.skip_hint.visible,
		"a fresh line does not inherit the previous line's already-shown hint")
	await _close(box)

	if failures.is_empty():
		print("DIALOGUE SKIP TEST: ALL PASS")
	else:
		print("DIALOGUE SKIP TEST: %d FAILURE(S)" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)


## Drive box._process() with fixed 1/60 steps for `seconds` of synthetic
## time — the same "by hand, no real awaits" trick voice_blip_test.gd's
## _reveal_all uses, so a held button's accumulated time is exact rather
## than at the mercy of headless idle-frame timing.
func _tick(box: DialogueBox, seconds: float) -> void:
	var steps := int(ceil(seconds * 60.0))
	for i in steps:
		box._process(1.0 / 60.0)


func _say_line(box: DialogueBox, speaker: String, text: String) -> void:
	box.say(speaker, text, Color(1, 1, 1, 1))
	await _frames(int(maxf(box.entrance_time, box.portrait_entrance_time) * 60.0) + 3)
	var guard := 0
	while not box._revealing and guard < 30:
		await _frames(1)
		guard += 1


## Drains any still-open pages by hand, THEN keeps waiting on real physics
## frames until `visible` actually drops — not just until `_active` does.
## Skip-armed closing (see say()'s own `break`) can set `_active = false` the
## instant the hold crosses the threshold, well before the real close-out
## timer it then starts has actually elapsed; treating `_active == false` as
## "fully closed" races that timer exactly the way an idle/physics frame
## mismatch used to (see _frames' own note).
func _close(box: DialogueBox) -> void:
	while box._active:
		box.line_finished.emit()
		await _frames(3)
	var guard := 0
	while box.visible and guard < 60:
		await _frames(1)
		guard += 1


## PHYSICS frames, not idle — say()'s own entrance/close waits are physics
## SceneTreeTimers (see its own note on why), and idle process_frame signals
## have no fixed relationship to those, headless or otherwise (intro_test.gd
## documents the same reasoning). Waiting on the wrong clock let one say()
## call's close-out still be mid-flight — physically overlapping the NEXT
## call's fresh _active/_revealing state — when this helper had already
## declared the box free to reuse.
func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _check(cond: bool, name: String) -> void:
	print(("  PASS  " if cond else "  FAIL  ") + name)
	if not cond:
		failures.append(name)
