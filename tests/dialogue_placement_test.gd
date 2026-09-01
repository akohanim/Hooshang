extends Node
## DialogueBox's vertical placement MECHANISM, in isolation from any scene.
##
## intro_test.gd pins which side each of Act1Beats' rooms actually chooses; this
## pins that the choice, once made, is drawn correctly — the thing under it that
## could break without any scene's dialogue content changing at all:
##
##   - TOP sits flush at the screen's top edge, BOTTOM flush at its bottom —
##     never floating with a gap, never anywhere in between
##   - a BOTTOM banner grows UPWARD as the line gets longer, staying flush at
##     the bottom, rather than growing off the bottom of the screen
##   - switching from BOTTOM back to TOP does not leave the previous line's
##     shift behind — the one bug this design had to be built to specifically
##     avoid (see DialogueBox._reset_vertical)
##   - both Persian border bands and the arrow stay anchored to the BANNER's
##     own edges, including as it grows
##     (start of the box, end of the box) rather than swapping screen edges,
##     so "press to continue" always reads at the visual bottom of the box
##   - horizontal (Side) and vertical (VSide) placement are independent — one
##     changing must not perturb the other
##
## Run:  godot --headless res://tests/dialogue_placement_test.tscn

var failures: Array[String] = []


func _ready() -> void:
	var box: DialogueBox = Dialogue

	# --- TOP: flush at the screen's top edge ---------------------------------
	await _say(box, "A short line.", DialogueBox.Side.LEFT, DialogueBox.VSide.TOP)
	_check(is_zero_approx(box.banner.offset_top),
		"TOP: banner is flush with the screen's top edge  [top=%.1f]" % box.banner.offset_top)
	_check(box.banner.offset_bottom < DialogueBox.CANVAS_HEIGHT,
		"TOP: and does not reach all the way to the bottom  [bottom=%.1f]"
			% box.banner.offset_bottom)
	_check(is_zero_approx(box.trim_top.offset_top),
		"TOP: the border band hugs the banner's OWN top edge  [%.1f]" % box.trim_top.offset_top)
	_check(is_equal_approx(box.trim_bottom.offset_bottom, box.banner.offset_bottom),
		"TOP: and the other band hugs its bottom edge  [trim=%.1f banner=%.1f]"
			% [box.trim_bottom.offset_bottom, box.banner.offset_bottom])
	_check(is_zero_approx(box.portrait_frame.offset_top),
		"TOP: the portrait frame is flush with the banner's top too  [%.1f]"
			% box.portrait_frame.offset_top)
	var top_short_height := box.banner.offset_bottom
	await _close(box)

	# --- BOTTOM: flush at the screen's bottom edge ----------------------------
	await _say(box, "A short line.", DialogueBox.Side.LEFT, DialogueBox.VSide.BOTTOM)
	_check(is_equal_approx(box.banner.offset_bottom, DialogueBox.CANVAS_HEIGHT),
		"BOTTOM: banner is flush with the screen's bottom edge  [bottom=%.1f, screen=%.1f]"
			% [box.banner.offset_bottom, DialogueBox.CANVAS_HEIGHT])
	_check(box.banner.offset_top > 0.0,
		"BOTTOM: and does not reach all the way to the top  [top=%.1f]" % box.banner.offset_top)
	# Same line, same font, same growth math as the TOP case above — the banner
	# should come out the exact same HEIGHT, just anchored to the other edge.
	var bottom_short_height := box.banner.offset_bottom - box.banner.offset_top
	_check(is_equal_approx(bottom_short_height, top_short_height),
		"BOTTOM: an identical line makes an identical-height banner  [%.1f vs %.1f]"
			% [bottom_short_height, top_short_height])
	# The trim and the arrow are positioned RELATIVE TO THE BANNER, not mirrored
	# to the opposite screen edge — the leading band still marks where the box's own
	# reading order starts (name label sits just under it), the arrow still
	# marks where it ends ("press to continue" belongs at the box's own bottom,
	# not wherever that lands on screen).
	_check(is_equal_approx(box.trim_top.offset_top, box.banner.offset_top),
		"BOTTOM: the border band still hugs the banner's OWN top edge  [trim=%.1f banner=%.1f]"
			% [box.trim_top.offset_top, box.banner.offset_top])
	_check(is_equal_approx(box.trim_bottom.offset_bottom, box.banner.offset_bottom),
		"BOTTOM: and the other still hugs its bottom edge  [trim=%.1f banner=%.1f]"
			% [box.trim_bottom.offset_bottom, box.banner.offset_bottom])
	_check(box.arrow.offset_bottom > box.banner.offset_top
			and box.arrow.offset_bottom <= box.banner.offset_bottom,
		"BOTTOM: the arrow sits near the banner's OWN bottom edge, press-to-continue  [arrow=%.1f banner %.1f-%.1f]"
			% [box.arrow.offset_bottom, box.banner.offset_top, box.banner.offset_bottom])
	await _close(box)

	# --- BOTTOM growth is UPWARD, not off the bottom of the screen -----------
	var long_line := "A line long enough that it wraps onto several rows of type, " \
		+ "so the banner has to grow well past its minimum height to hold it all."
	await _say(box, long_line, DialogueBox.Side.LEFT, DialogueBox.VSide.BOTTOM)
	_check(is_equal_approx(box.banner.offset_bottom, DialogueBox.CANVAS_HEIGHT),
		"BOTTOM+long: still flush at the bottom  [%.1f]" % box.banner.offset_bottom)
	_check(box.banner.offset_top < DialogueBox.CANVAS_HEIGHT - bottom_short_height,
		"BOTTOM+long: grew UPWARD — its top moved up, not its bottom off-screen  [top=%.1f, short-line top was %.1f]"
			% [box.banner.offset_top, DialogueBox.CANVAS_HEIGHT - bottom_short_height])
	# The bottom band is POSITIONED by _fit_banner, not shifted wholesale like
	# everything else, so a banner that grows is exactly where it can be left
	# behind — sitting across the middle of the text instead of closing the box.
	_check(is_equal_approx(box.trim_bottom.offset_bottom, box.banner.offset_bottom),
		"BOTTOM+long: the bottom band followed the banner as it grew  [trim=%.1f banner=%.1f]"
			% [box.trim_bottom.offset_bottom, box.banner.offset_bottom])
	_check(box.arrow.offset_bottom <= box.trim_bottom.offset_top,
		"BOTTOM+long: the arrow clears the band rather than drawing over it  [arrow=%.1f band=%.1f]"
			% [box.arrow.offset_bottom, box.trim_bottom.offset_top])
	await _close(box)

	# --- switching back to TOP leaves nothing behind --------------------------
	# The one failure mode this design exists to prevent: without resetting to a
	# clean baseline before every line, a TOP line right after a BOTTOM one would
	# start growing from wherever the BOTTOM line's shift left things, and the
	# box would come out floating with a gap instead of flush.
	await _say(box, "Back on top.", DialogueBox.Side.LEFT, DialogueBox.VSide.TOP)
	_check(is_zero_approx(box.banner.offset_top),
		"TOP after BOTTOM: flush at the top again, with nothing left over  [top=%.1f]"
			% box.banner.offset_top)
	await _close(box)

	# --- horizontal and vertical placement do not interfere -------------------
	await _say(box, "On the right, at the bottom.", DialogueBox.Side.RIGHT, DialogueBox.VSide.BOTTOM,
		Color(1, 1, 1, 1))
	var middle := DialogueBox.CANVAS_WIDTH * 0.5
	_check(box.portrait_frame.offset_left >= middle,
		"Side.RIGHT still puts the portrait on the right  [left=%.1f, middle=%.1f]"
			% [box.portrait_frame.offset_left, middle])
	_check(is_equal_approx(box.banner.offset_bottom, DialogueBox.CANVAS_HEIGHT),
		"...while VSide.BOTTOM still holds the banner flush at the bottom  [%.1f]"
			% box.banner.offset_bottom)
	await _close(box)

	# --- interrupting a still-CLOSING line doesn't flash its old text --------
	#
	# Every _say() above fires and closes cleanly, one full cycle at a time —
	# none of them exercise what happens when a NEW line starts while an
	# OLDER one's close animation is still mid-flight. _kill_anim_tweens()
	# stops that old tween from fighting the new one, but used to leave
	# text_label's scale wherever the kill happened to land (anywhere from 1,
	# a fresh interrupt, down to 0, an almost-finished close) rather than
	# snapped to 0 — and nothing clears text_label's TEXT until _begin_page()
	# runs, well after the new entrance. The old line's full text sat at that
	# frozen, partial scale for the whole new entrance: a flash of the wrong,
	# garbled-looking text the instant the box opened.
	await _say(box, "The interrupted line.", DialogueBox.Side.LEFT, DialogueBox.VSide.TOP)
	box.line_finished.emit()  # dismiss it — this starts its close animation
	await _frames(3)          # let that close tween actually get moving
	# Fired WITHOUT awaiting the close above, on purpose — this is the race.
	box.say("Hooshang", "The interrupting line.", Color(1, 1, 1, 1), null,
		DialogueBox.Side.LEFT, DialogueBox.VSide.TOP)
	_check(is_zero_approx(box.get_node("TextLabel").scale.y),
		"a line that interrupts a still-closing one starts text_label fully hidden  [scale.y=%.3f]"
			% box.get_node("TextLabel").scale.y)
	await _frames(int(maxf(box.entrance_time, box.portrait_entrance_time) * 60.0) + 3)
	await _close(box)

	if failures.is_empty():
		print("DIALOGUE PLACEMENT TEST: ALL PASS")
	else:
		print("DIALOGUE PLACEMENT TEST: %d FAILURE(S)" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)


## Show a line and let one frame of layout land, without waiting on a real
## button press — the same fire-and-close pattern tests/screen_test.gd uses.
##
## Waits out the float-IN first. say() now holds the line off until its own
## entrance animation finishes (up to portrait_entrance_time) before it is
## listening for a dismiss at all — _fit_banner/_place_vside have already set
## every offset this test checks by the time say() is called, so the numbers
## below are correct from frame one, but emitting line_finished before the
## entrance has actually reached its "await line_finished" leaves nothing
## listening and the next call hangs forever waiting on a signal that already
## fired into the void.
func _say(box: DialogueBox, text: String, side: int, vside: int,
		tint := Color(1, 1, 1, 1)) -> void:
	box.say("Hooshang", text, tint, null, side, vside)
	await _frames(int(maxf(box.entrance_time, box.portrait_entrance_time) * 60.0) + 3)
	# The bug that shipped: text_label's CLOSE tween scales it to zero height
	# and nothing ever tweened it back, so every line after the first was
	# typing into a node still scaled to nothing — text_label.text held the
	# right string the whole time, which is exactly why checking offsets and
	# text content (everything else in this file) never caught it. This is
	# the one check here that looks at what a player actually SEES rather
	# than the layout math behind it, and it runs on every call — the second,
	# third, fourth... _say() in this file is the regression case, not the
	# first.
	_check(is_equal_approx(box.get_node("TextLabel").scale.y, 1.0),
		"the text is actually visible, not scaled to zero from a previous line's close  [scale.y=%.3f]"
			% box.get_node("TextLabel").scale.y)


## Loops rather than emitting once: a line long enough to paginate needs one
## line_finished per PAGE, not per say() call, and emitting into a box that
## is not currently listening (between pages, or before it is) is a safe
## no-op — so this just keeps trying until _active actually drops, which is
## say()'s own signal that every page is done and its close has begun.
func _close(box: DialogueBox) -> void:
	while box._active:
		box.line_finished.emit()
		await _frames(3)
	# ...and out: say() does not set visible = false until its own close
	# animation (entrance_time) has played.
	await _frames(int(box.entrance_time * 60.0) + 3)


## PHYSICS frames, not idle/process ones. say()'s float-in/close now runs on
## Tween.TWEEN_PROCESS_PHYSICS and process_in_physics SceneTreeTimers
## specifically because idle process has no fixed relationship to wall-clock
## time in a headless run — measured, a 0.32s wait took 30 idle frames to
## clear once, 19 another time. Physics ticks are fixed-step, which is the
## only way "N frames" is a number this file can reason about at all.
func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _check(cond: bool, name: String) -> void:
	print(("  PASS  " if cond else "  FAIL  ") + name)
	if not cond:
		failures.append(name)
