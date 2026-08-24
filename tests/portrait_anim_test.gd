extends Node
## The talking-portrait rig: Hooshang's dialogue face blinks, and moves his mouth
## for exactly as long as words are appearing.
##
## Everything here is a thing that breaks SILENTLY. A manifest that fails to
## load, a face left on the wrong frame, a mouth that keeps chewing after the
## line has finished — none of them raise an error, none of them stop a run, and
## all of them are only visible to somebody sitting and watching a cutscene,
## which is the one thing nobody does while working on the level geometry the
## cutscene is set in.
##
## HOOSHANG'S FACES ARE NOW LOOPS, not overlays. A loop is a sheet of whole
## faces generated from the portrait (assets/portraits/loops/), and the box
## DRIVES it rather than playing it — which is the only reason it can still obey
## the two rules that made the old overlay rig read as speech:
##
##   - the manifest loads AT ALL (it is data on res://, not a scene reference —
##     the failure mode is every face silently going back to a still painting)
##   - a looped face puts a window onto its sheet in the portrait, and leaves the
##     older mouth/eye overlays OFF, because those are warped from the painting
##     the loop replaced and would be drawn over the wrong face
##   - a face with NO portrait at all holds still, exactly as every portrait did
##     before any of this existed (Rumi was drawn that way until he got sheets
##     of his own; this now covers the no-face path rather than his)
##   - RUMI'S faces are loops too, and his blink is found where HIS eyes are —
##     he wears a turban and sits lower in frame than Hooshang, so the indexer's
##     default eye band would miss it and report no blink at all, silently
##   - the loop survives _place() mirroring the banner for a right-hand speaker
##   - speech frames advance while revealing, and NEVER land on the rest frame,
##     which means silence
##   - a "[p]" breath and the end of the line both return it to rest at once
##   - the eyes blink on their own clock with no typing going on, and the blink
##     frame is kept out of the speech cycle so the two cannot fight over a frame
##
## Run:  godot --headless res://tests/portrait_anim_test.tscn

## A face with a loop. Every one of Hooshang's six has one now — including the
## waking shot, which used to be deliberately unrigged because it was a 3/4 view
## the old warps could not follow, and is front-facing art today.
const LOOPED := preload("res://assets/portraits/hooshang_skeptical.png")
const WAKING := preload("res://assets/portraits/hooshang_dazed.png")
## Rumi's, whose sheets are built a different way — only the mouth and the eyes
## are composited onto the still, so his frames differ from it nowhere else.
const RUMI := preload("res://assets/portraits/rumi_serene.png")

var failures: Array[String] = []


func _ready() -> void:
	var box: DialogueBox = Dialogue

	# --- the manifests load ---------------------------------------------------
	_check(not box._loops.is_empty(),
		"the loop manifest loads off res:// at all  [%d loops]" % box._loops.size())
	_check(box._loops.has("hooshang_skeptical"),
		"...and holds the face this test drives")
	_check(box._loops.has("hooshang_dazed"),
		"...and the waking shot, which has a loop now that it faces front")

	# --- a looped face drives the portrait itself -----------------------------
	await _say(box, "A line with a looped face.", DialogueBox.Side.LEFT, LOOPED)
	_check(not box._loop.is_empty(), "a looped face arms its loop")
	_check(box.portrait_loop.visible and box.portrait_loop.texture is AtlasTexture,
		"...by drawing a window onto the sheet over the face")
	_check(box.portrait.texture != null
			and box.portrait.texture.resource_path.ends_with("hooshang_skeptical.png"),
		"...while the still underneath still NAMES the face  [%s]"
			% box.portrait.texture.resource_path)
	_check(not box.portrait_mouth.visible and not box.portrait_eyes.visible,
		"...and leaves the older overlays off, so nothing is drawn over it")

	# The window must stay ON the sheet. A frame index multiplied by the wrong
	# width walks off the end and shows nothing, silently.
	var atlas := box.portrait_loop.texture as AtlasTexture
	_check(atlas.atlas != null and atlas.region.end.x <= atlas.atlas.get_width()
			and atlas.region.size.x > 0.0,
		"the window lies inside the sheet  [%s in %d wide]"
			% [atlas.region, atlas.atlas.get_width() if atlas.atlas else -1])

	# As ints: JSON numbers arrive as floats, so `talk.has(3)` is false against a
	# 3.0 and every membership test here would quietly invert.
	var talk := _ints(box._loop["talk"])
	var rest := int(box._loop.get("rest", 0))
	_check(not talk.has(rest),
		"the rest frame is not a speech frame  [rest %d, talk %s]" % [rest, talk])
	if box._loop.has("blink"):
		_check(not talk.has(int(box._loop["blink"])),
			"and neither is the blink  [blink %d, talk %s]" % [box._loop["blink"], talk])

	# --- a face with no loop holds still --------------------------------------
	await _close(box)
	# No texture at all. Rumi used to be drawn this way; he has his own sheets
	# now, so this covers the no-face path rather than his.
	await _say(box, "Rumi, tinted.", DialogueBox.Side.LEFT, null)
	_check(box._loop.is_empty() and not box.portrait_loop.visible
			and not box.portrait_eyes.visible,
		"a face with no portrait at all animates nothing and simply holds still")

	# --- Rumi's faces are loops too -------------------------------------------
	#
	# Worth its own case because his sheets are built differently and his blink
	# is found differently. The indexer's default eye band is HOOSHANG's — bare
	# headed, y 40-68 — and Rumi wears a turban and sits lower, at y 98-124. Read
	# in the wrong band his blink is simply not found, and the failure is silent:
	# the face still talks, still rests, and never once shuts its eyes.
	await _close(box)
	await _say(box, "A line from Rumi.", DialogueBox.Side.RIGHT, RUMI)
	_check(not box._loop.is_empty(), "Rumi's face arms a loop of its own")
	_check(box.portrait.texture != null
			and box.portrait.texture.resource_path.ends_with("rumi_serene.png"),
		"...and the still underneath still names him  [%s]"
			% box.portrait.texture.resource_path)
	_check(box._loop.has("blink"),
		"...and his blink was FOUND, in the band his eyes are actually in")
	var rumi_talk := _ints(box._loop["talk"])
	_check(not rumi_talk.has(int(box._loop["blink"])),
		"...and kept out of the speech cycle  [blink %d, talk %s]"
			% [box._loop["blink"], rumi_talk])
	# Not vacuous: a sheet whose frames were all identical would satisfy every
	# check above. Only the mouth and the eyes are meant to differ from the
	# still, so a speech frame has to differ from the rest frame SOMEWHERE.
	var sheet: AtlasTexture = box.portrait_loop.texture
	var img := sheet.atlas.get_image()
	var w := int(sheet.region.size.x)
	var rest_px := img.get_region(Rect2i(0, 0, w, img.get_height()))
	var talk_px := img.get_region(Rect2i(rumi_talk[0] * w, 0, w, img.get_height()))
	var diff := 0
	for y in range(0, rest_px.get_height(), 2):
		for x in range(0, w, 2):
			if rest_px.get_pixel(x, y) != talk_px.get_pixel(x, y):
				diff += 1
	_check(diff > 40,
		"...and a speech frame really differs from the rest frame  [%d px]" % diff)

	# --- mirroring carries the loop with the face -----------------------------
	await _close(box)
	await _say(box, "Speaking from the right.", DialogueBox.Side.RIGHT, LOOPED)
	var face := box.portrait.get_global_rect()
	_check(face.get_center().x > DialogueBox.CANVAS_WIDTH * 0.5,
		"Side.RIGHT put the portrait on the right  [%.1f]" % face.get_center().x)
	_check(not box._loop.is_empty() and box.portrait_loop.visible
			and box.portrait.get_global_rect().encloses(box.portrait_loop.get_global_rect()),
		"...and the loop frame came with it, still over the face")

	# --- the mouth is driven by the typewriter, not by a timer of its own -----
	#
	# Stepped by hand rather than by waiting on real frames: the behaviour under
	# test is "which frame for which state", and a wall-clock version of this
	# would be both slow and flaky. The blink clock is pushed out of the way
	# first, so what is measured here is the speech cycle and only that.
	talk = _ints(box._loop["talk"])
	rest = int(box._loop.get("rest", 0))
	box._revealing = true
	box._pause_left = 0.0
	box._blink_t = -1.0
	box._blink_left = 999.0
	var seen := {}
	for i in 60:
		box._animate_loop(0.05)
		seen[_frame_of(box.portrait_loop)] = true
	_check(not seen.has(rest),
		"while revealing, the face never rests on the silent frame  [saw %s]" % [seen.keys()])
	_check(seen.size() > 1,
		"...and it actually moves between positions  [saw %s]" % [seen.keys()])
	var stray := []
	for f in seen:
		if not talk.has(f):
			stray.append(f)
	_check(stray.is_empty(),
		"...and only ever shows speech frames  [strays %s, talk %s]" % [stray, talk])

	box._pause_left = 0.5   # a "[p]" breath, mid-line
	box._animate_loop(0.05)
	_check(_frame_of(box.portrait_loop) == rest,
		"a breath returns the face to rest  [frame %d, rest %d]"
			% [_frame_of(box.portrait_loop), rest])

	box._pause_left = 0.0
	box._revealing = false  # line finished, waiting on a press
	box._animate_loop(0.05)
	_check(_frame_of(box.portrait_loop) == rest,
		"and it rests the instant the line finishes  [frame %d, rest %d]"
			% [_frame_of(box.portrait_loop), rest])

	# --- the eyes blink on their own, with nothing being said -----------------
	if box._loop.has("blink"):
		var shut := int(box._loop["blink"])
		box._blink_t = -1.0
		box._blink_left = 0.05
		var blinked := false
		var reopened := false
		for i in 800:
			box._animate_loop(0.02)
			var f := _frame_of(box.portrait_loop)
			if f == shut:
				blinked = true
			elif blinked and f == rest:
				reopened = true
				break
		_check(blinked, "the eyes blink shut on their own, with no typing going on")
		_check(reopened, "...and open again afterwards, rather than staying shut")
	await _close(box)

	if failures.is_empty():
		print("PORTRAIT ANIM TEST: ALL PASS")
	else:
		print("PORTRAIT ANIM TEST: %d FAILURE(S)" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)


## A manifest frame list as ints. JSON has one number type and it is float.
func _ints(a: Array) -> Array:
	var out := []
	for v in a:
		out.append(int(v))
	return out


## Which frame of its sheet a TextureRect is showing.
func _frame_of(node: TextureRect) -> int:
	var atlas := node.texture as AtlasTexture
	if atlas == null or atlas.region.size.x <= 0.0:
		return -1
	return int(round(atlas.region.position.x / atlas.region.size.x))


## Show a line and let a frame of layout land, without waiting on a real button
## press — the same fire-and-close pattern dialogue_placement_test.gd uses.
func _say(box: DialogueBox, text: String, side: int, face: Texture2D) -> void:
	box.say("Hooshang", text, Color(1, 1, 1, 1), face, side, DialogueBox.VSide.TOP)
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
