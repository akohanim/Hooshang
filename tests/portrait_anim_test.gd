extends Node
## The talking-portrait rig: Hooshang's dialogue face blinks, and moves his mouth
## for exactly as long as words are appearing.
##
## Everything here is a thing that breaks SILENTLY. A rig that fails to load, an
## overlay anchored to the wrong corner or left behind when the banner mirrors,
## a mouth that keeps chewing after the line has finished — none of them raise an
## error, none of them stop a run, and all of them are only visible to somebody
## sitting and watching a cutscene, which is the one thing nobody does while
## working on the level geometry the cutscene is set in.
##
##   - the manifest loads AT ALL (it is data on res://, not a scene reference —
##     the failure mode is every face silently going back to a still painting)
##   - a rigged face turns both overlays on; an unrigged one (Rumi, the tinted
##     stand-in, the un-rigged waking shot) leaves them off and holds still
##   - the overlays land ON the face they belong to: the mouth in the lower half
##     of the portrait, the eyes in the upper half, both inside its rect
##   - and they stay there when _place() mirrors the banner for a right-hand
##     speaker, which is what anchoring them to the portrait buys
##   - the mouth moves while revealing, closes the instant the line finishes,
##     and holds closed through a "[p]" breath
##   - the eyes blink on their own, with no typing going on at all
##
## Run:  godot --headless res://tests/portrait_anim_test.tscn

## A face the generator rigs, and one it deliberately does not (see the comment
## on `hooshang_dazed` in tools/gen_portrait_frames.py).
const RIGGED := preload("res://assets/portraits/hooshang_skeptical.png")
const UNRIGGED := preload("res://assets/portraits/hooshang_dazed.png")

var failures: Array[String] = []


func _ready() -> void:
	var box: DialogueBox = Dialogue

	# --- the rigs load --------------------------------------------------------
	_check(not box._rigs.is_empty(),
		"the frame manifest loads off res:// at all  [%d rigs]" % box._rigs.size())
	_check(box._rigs.has("hooshang_skeptical"),
		"...and holds the face this test drives")
	_check(not box._rigs.has("hooshang_dazed"),
		"...and NOT the waking shot, which is deliberately unrigged")

	# --- a rigged face brings both overlays up --------------------------------
	await _say(box, "A line with a rigged face.", DialogueBox.Side.LEFT, RIGGED)
	_check(box.portrait_mouth.visible, "a rigged face shows its mouth overlay")
	_check(box.portrait_eyes.visible, "...and its eyes overlay")

	# Both must sit on the face, not merely somewhere on the banner. Anchors are
	# fractions of the portrait, so a rect read in the wrong order or divided by
	# the wrong size puts a mouth on his forehead and nothing errors.
	var face := box.portrait.get_global_rect()
	var mouth := box.portrait_mouth.get_global_rect()
	var eyes := box.portrait_eyes.get_global_rect()
	_check(face.encloses(mouth), "the mouth overlay lies inside the portrait  [%s in %s]"
		% [mouth, face])
	_check(face.encloses(eyes), "the eyes overlay lies inside the portrait  [%s in %s]"
		% [eyes, face])
	_check(mouth.get_center().y > face.get_center().y,
		"the mouth is in the LOWER half of the face  [%.1f vs %.1f]"
			% [mouth.get_center().y, face.get_center().y])
	# Against the mouth rather than against the middle of the frame: these
	# paintings are bust-framed, so the eye line lands within a pixel or two of
	# the portrait's centre and a halves test passes or fails on rounding.
	_check(eyes.get_center().y < mouth.get_center().y,
		"the eyes sit above the mouth  [%.1f vs %.1f]"
			% [eyes.get_center().y, mouth.get_center().y])

	# --- an unrigged face holds still ----------------------------------------
	await _close(box)
	await _say(box, "A line with an unrigged face.", DialogueBox.Side.LEFT, UNRIGGED)
	_check(not box.portrait_mouth.visible and not box.portrait_eyes.visible,
		"an unrigged face shows no overlays and simply holds still")
	await _close(box)
	# The tinted stand-in is the same path, and is how Rumi is still drawn.
	await _say(box, "Rumi, tinted.", DialogueBox.Side.LEFT, null)
	_check(not box.portrait_mouth.visible and not box.portrait_eyes.visible,
		"...and so does the tinted stand-in")

	# --- mirroring carries the overlays with the face -------------------------
	await _close(box)
	await _say(box, "Speaking from the right.", DialogueBox.Side.RIGHT, RIGGED)
	face = box.portrait.get_global_rect()
	mouth = box.portrait_mouth.get_global_rect()
	_check(face.get_center().x > DialogueBox.CANVAS_WIDTH * 0.5,
		"Side.RIGHT put the portrait on the right  [%.1f]" % face.get_center().x)
	_check(face.encloses(mouth),
		"...and the mouth overlay travelled with it  [%s in %s]" % [mouth, face])

	# --- the mouth is driven by the typewriter, not by a timer of its own -----
	#
	# Stepped by hand rather than by waiting on real frames: the behaviour under
	# test is "which frame for which state", and a wall-clock version of this
	# would be both slow and flaky.
	box._revealing = true
	box._pause_left = 0.0
	var seen := {}
	for i in 60:
		box._animate_portrait(0.05)
		seen[_frame_of(box.portrait_mouth)] = true
	_check(not seen.has(0),
		"while revealing, the mouth never rests on the closed frame  [saw %s]" % [seen.keys()])
	_check(seen.size() > 1,
		"...and it actually moves between positions  [saw %s]" % [seen.keys()])

	box._pause_left = 0.5   # a "[p]" breath, mid-line
	box._animate_portrait(0.05)
	_check(_frame_of(box.portrait_mouth) == 0,
		"a breath closes the mouth  [frame %d]" % _frame_of(box.portrait_mouth))

	box._pause_left = 0.0
	box._revealing = false  # line finished, waiting on a press
	box._animate_portrait(0.05)
	_check(_frame_of(box.portrait_mouth) == 0,
		"and the mouth closes the instant the line finishes  [frame %d]"
			% _frame_of(box.portrait_mouth))

	# --- the eyes blink on their own, with nothing being said -----------------
	var shut := int(box._rig["eyes"]["frames"]) - 1
	var blinked := false
	var reopened := false
	for i in 400:
		box._animate_portrait(0.02)
		var f := _frame_of(box.portrait_eyes)
		if f == shut:
			blinked = true
		elif blinked and f == 0:
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


## Which frame of its strip an overlay is showing.
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
