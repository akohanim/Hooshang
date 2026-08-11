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
##   - the accent trim and the arrow stay anchored to the BANNER's own edges
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
	_check(is_zero_approx(box.accent.offset_top),
		"TOP: the accent trim hugs the banner's OWN top edge  [%.1f]" % box.accent.offset_top)
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
	# to the opposite screen edge — the accent still marks where the box's own
	# reading order starts (name label sits just under it), the arrow still
	# marks where it ends ("press to continue" belongs at the box's own bottom,
	# not wherever that lands on screen).
	_check(is_equal_approx(box.accent.offset_top, box.banner.offset_top),
		"BOTTOM: the accent trim still hugs the banner's OWN top edge  [accent=%.1f banner=%.1f]"
			% [box.accent.offset_top, box.banner.offset_top])
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

	if failures.is_empty():
		print("DIALOGUE PLACEMENT TEST: ALL PASS")
	else:
		print("DIALOGUE PLACEMENT TEST: %d FAILURE(S)" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)


## Show a line and let one frame of layout land, without waiting on a real
## button press — the same fire-and-close pattern tests/screen_test.gd uses.
func _say(box: DialogueBox, text: String, side: int, vside: int,
		tint := Color(1, 1, 1, 1)) -> void:
	box.say("Hooshang", text, tint, null, side, vside)
	await _frames(3)


func _close(box: DialogueBox) -> void:
	box.line_finished.emit()
	await _frames(2)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _check(cond: bool, name: String) -> void:
	print(("  PASS  " if cond else "  FAIL  ") + name)
	if not cond:
		failures.append(name)
