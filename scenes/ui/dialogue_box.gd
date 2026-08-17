class_name DialogueBox
extends CanvasLayer
## Celeste-style dialogue box: a dark banner across the top of the screen with a
## framed portrait on the LEFT and large centred typewriter text, closed top and
## bottom by a Persian khatam border (tools/gen_persian_trim.py).
##
## The border is TILED, not stretched, so it does not care how wide the banner
## is. It does care how TALL: the bands hang off the banner's two edges, so
## TRIM_HEIGHT, the name label's y, and _fit_banner's arithmetic are one set of
## numbers. Retune them together.
## Usage (from any cutscene code):
##     await Dialogue.say("Rumi", "Some line.", RUMI_GOLD)            # tinted stand-in
##     await Dialogue.say("Hooshang", "...I fell.", Color.WHITE, tex)  # real portrait
##     await Dialogue.say("", "Press X to dash.")                      # system, no portrait
## First confirm press (jump / ui_accept) completes the reveal instantly,
## second press closes the box. `say` returns when the box closes.
##
## VERTICAL PLACEMENT. The banner sits flush against whichever screen edge
## `vside` names (DialogueBox.VSide.TOP or .BOTTOM) — never floating with a gap,
## and never anywhere else. It defaults to TOP; pass BOTTOM for a room where the
## action the player needs to see is near the top of the screen. Choose it per
## LINE by looking at where the player and Rumi actually are when it plays, not
## once per room — a scene can move between the two as the characters do.
##
## TYPOGRAPHY — why this scene is laid out in 1280x720 and scaled by 0.25.
## The game renders in a 320x180 design space, so a font here could only ever be
## ~7px tall, which is what made the old box look like a chunky pixel banner
## instead of Celeste's clean type. The window scales CANVAS ITEMS (see
## project.godot: stretch/mode = canvas_items), so this CanvasLayer's own 0.25
## scale cancels exactly one quarter of that: children are authored at 4x the
## game's design size, glyphs rasterise at 4x the pixel size, and the whole box
## still scales with the window like everything else. 0.25 is a constant, not a
## window-dependent number, because both the stretch and the target scale grow
## with the window at the same rate (320*4 = 1280, 180*4 = 720).
##
## PORTRAIT FILTERING. The Portrait node overrides `texture_filter` to
## LINEAR_WITH_MIPMAPS, against the project default of Nearest. That default is
## right for the world — the whole 320x180 viewport is pixel art — and wrong
## here, because the portraits are PAINTINGS shipped at 512px and drawn into a
## 172px frame at a 1280x720 window. Point-sampling a painting at a third of its
## size turns the halftone dots in its background into moire, and the frame is
## 344px at 1440p and 516 fullscreen on 4K, so there is no one source size that
## would let Nearest be correct at all of them. The portraits are imported with
## mipmaps to match (see tools/import_portraits.py).
##
## FUTURE: multi-line conversations = await say() in sequence. Rumi still uses a
## tinted stand-in; give him a portrait set and pass it the same way as Hooshang.

signal line_finished

## Which end of the banner the portrait sits at. A speaker's face belongs on the
## side of the screen they are actually standing on, so a conversation reads as
## happening between two places rather than out of one corner.
##
## Passed around as plain `int`, not as `Side`: GDScript's analyser treats the
## enum named from inside this class and the same enum named as
## `DialogueBox.Side` from outside it as different types, and rejects the call.
enum Side { LEFT, RIGHT }

## Which edge of the SCREEN the banner sits flush against. A director's choice
## per line, same footing as Side: place it wherever the scene's action is NOT,
## so the box never covers the characters it is captioning. TOP is the default —
## most rooms put the player and Rumi on or near the floor, which is the bottom
## of the screen, leaving the top clear.
enum VSide { TOP, BOTTOM }

## The banner's own width and height, in its 1280x720 authoring space. The RIGHT
## layout is the authored LEFT one mirrored about CANVAS_WIDTH, so nudging the
## portrait frame in DialogueBox.tscn moves both sides and they cannot drift
## apart. BOTTOM placement uses CANVAS_HEIGHT the same way — see _place_vside.
const CANVAS_WIDTH := 1280.0
const CANVAS_HEIGHT := 720.0

## Reveal speed of the typewriter effect, in characters per second.
@export var chars_per_second := 40.0
## A beat inside a line — "(a breath)" in a script. Put PAUSE_MARK where it
## falls and the typewriter holds there for this long; the mark itself is never
## drawn. Stage directions get PLAYED rather than printed, which is the same
## rule "(looking around)" follows in scripts/act1_beats.gd, and the alternative
## here was a second dialogue box — a button press, which is a much bigger beat
## than a breath. One mark per line.
@export var pause_time := 0.5
const PAUSE_MARK := "[p]"
## Weight added to the UI font. Godot's default font ships in one weight; a
## little synthetic emboldening is what gives the Celeste-ish solid look.
@export_range(0.0, 1.0) var font_weight := 0.28
## Left edge of the text block when there is no portrait to clear. With one, the
## text sits where DialogueBox.tscn puts it — see _place().
const FULL_TEXT_LEFT := 48.0

## Most rows of text the banner is ever allowed to be. A line that needs more is
## broken into PAGES and shown one press at a time — see _paginate.
##
## The banner used to grow to fit whatever it was given, and Rumi's longest line
## in the Act I ending grew it to six rows: two thirds of the screen, over the
## room the scene is set in, with the character it is about standing behind it.
## The rule "long lines are fine, the box grows" only holds while the box stays a
## banner, and past about three rows it stops being one.
##
## Paging rather than a smaller font, which is the same trade _fit_banner already
## refused: the type size is what makes this read like Celeste.
@export_range(1, 8) var max_lines := 3

## Banner sizing. The text block never shrinks below MIN_TEXT_HEIGHT, which is
## the height the box was fixed at and what one- and two-row lines still get, so
## the overwhelming majority of lines look exactly as they did.
const MIN_TEXT_HEIGHT := 146.0
## Gap under the text, and the arrow's own box.
const BANNER_PAD := 8.0
const ARROW_HEIGHT := 44.0
## Height of one Persian border band, matching assets/ui/persian_trim.png. The
## art and this have to agree: the texture is TILED, not stretched, so a mismatch
## clips the band rather than resizing it.
const TRIM_HEIGHT := 16.0

## Extra pixels between glyphs, in the box's own 1280x720 space. Celeste's type
## is noticeably tracked-out; without this it reads cramped at this size.
@export var letter_spacing := 2

var _active := false
var _revealing := false
var _reveal_accum := 0.0
## Character index the reveal holds at, or -1 for none / already spent.
var _pause_at := -1
var _pause_left := 0.0

@onready var banner: ColorRect = $Banner
## The Persian border bands. TrimTop hugs the banner's leading edge and never
## moves; TrimBottom is repositioned by _fit_banner, because the banner's height
## is whatever this line needs.
@onready var trim_top: TextureRect = $TrimTop
@onready var trim_bottom: TextureRect = $TrimBottom
@onready var name_label: Label = $NameLabel
@onready var text_label: Label = $TextLabel
@onready var arrow: Label = $Arrow
@onready var portrait: TextureRect = $Portrait
@onready var portrait_frame: ColorRect = $PortraitFrame
@onready var portrait_back: ColorRect = $PortraitBack
## The scene's built-in stand-in, kept so a tinted speaker can go back to it
## after a line that supplied real art.
@onready var _default_portrait: Texture2D = $Portrait.texture

## Each mirrored Control's authored horizontal span, as (offset_left,
## offset_right). Captured once, because _place() overwrites these.
var _authored := {}
## Each vertical Control's AUTHORED (TOP-anchored, flush-at-0) span, as
## (offset_top, offset_bottom). Captured once from the pristine .tscn state and
## restored before every line, so a BOTTOM line never leaves a TOP line starting
## from the wrong baseline — see _reset_vertical(). Arrow is not here: its
## position is always fully recomputed from `banner`, never authored.
var _authored_v := {}


func _ready() -> void:
	visible = false
	for node in _mirrored():
		_authored[node] = Vector2(node.offset_left, node.offset_right)
	for node in [banner, trim_top, trim_bottom, portrait_frame, portrait_back, portrait, name_label, text_label]:
		_authored_v[node] = Vector2(node.offset_top, node.offset_bottom)
	_apply_font()


## Everything whose horizontal position flips with the speaker's side. The
## arrow flips too: it belongs at the far end of the text block, and with the
## portrait on the right that end is the left.
func _mirrored() -> Array[Control]:
	return [portrait_frame, portrait_back, portrait, name_label, text_label, arrow]


## Lay the banner out for `side`, or hand the whole width to the text when there
## is no portrait to make room for.
func _place(side: int, show_portrait: bool) -> void:
	for node in _mirrored():
		var span: Vector2 = _authored[node]
		if side == Side.LEFT:
			node.offset_left = span.x
			node.offset_right = span.y
		else:
			node.offset_left = CANVAS_WIDTH - span.y
			node.offset_right = CANVAS_WIDTH - span.x
	# The name reads as a label ON the portrait, so it hugs whichever side the
	# face is on.
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if side == Side.LEFT \
		else HORIZONTAL_ALIGNMENT_RIGHT
	if show_portrait:
		return
	# No portrait: the text owns the whole banner, so it reads centred rather
	# than hanging off to one side of an empty frame.
	for node in [name_label, text_label]:
		node.offset_left = FULL_TEXT_LEFT
		node.offset_right = CANVAS_WIDTH - FULL_TEXT_LEFT


## Put every vertical Control back at its pristine, TOP-anchored (flush-at-0)
## position. Called before every line so _fit_banner always grows from the same
## clean baseline — without this, a BOTTOM line followed by a TOP line would
## start the TOP line's growth from wherever the BOTTOM line had shifted things
## to, and the box would drift off its edge.
func _reset_vertical() -> void:
	for node in _authored_v:
		var span: Vector2 = _authored_v[node]
		node.offset_top = span.x
		node.offset_bottom = span.y


## Slide the whole banner down to sit flush against the BOTTOM of the screen,
## after _fit_banner has grown it to this line's actual height.
##
## Not a mirror. Every element keeps its position RELATIVE TO THE BANNER — the
## border bands stay hugging the banner's own two edges, and the arrow stays just
## inside the trailing one (the "end" of the box, where "press to continue"
## belongs). Flipping the box vertically instead would put the arrow above the
## name and stand the ornament on its head. A uniform downward shift by
## (CANVAS_HEIGHT - banner.offset_bottom) is all that is needed: at that point
## banner.offset_top is 0 (the TOP-anchored baseline _reset_vertical restored),
## so the shift lands the block's bottom edge exactly on CANVAS_HEIGHT.
func _place_vside(vside: int) -> void:
	if vside != VSide.BOTTOM:
		return
	var shift := CANVAS_HEIGHT - banner.offset_bottom
	for node in [banner, trim_top, trim_bottom, portrait_frame, portrait_back,
			portrait, name_label, text_label, arrow]:
		node.offset_top += shift
		node.offset_bottom += shift


## Emboldened, tracked-out variant of the default font, applied to both labels.
## Built in code rather than saved as a .tres because it needs ThemeDB's fallback
## font as its base, which a scene file cannot reference.
func _apply_font() -> void:
	var fv := FontVariation.new()
	fv.base_font = ThemeDB.fallback_font
	fv.variation_embolden = font_weight
	fv.spacing_glyph = letter_spacing
	text_label.add_theme_font_override("font", fv)
	name_label.add_theme_font_override("font", fv)


## Show one line and wait until the player has read + dismissed it.
##
## portrait_tint alpha 0 = system text (no portrait shown). `portrait_texture`
## supplies a real portrait; without one the speaker gets the tinted stand-in
## baked into the scene, which is still how Rumi is drawn.
func say(speaker: String, text: String, portrait_tint := Color(0, 0, 0, 0),
		portrait_texture: Texture2D = null, side: int = Side.LEFT,
		vside: int = VSide.TOP) -> void:
	name_label.text = speaker
	name_label.visible = speaker != ""
	var show_portrait := portrait_tint.a > 0.0 or portrait_texture != null
	portrait.visible = show_portrait
	portrait_frame.visible = show_portrait
	portrait_back.visible = show_portrait
	_place(side, show_portrait)
	_reset_vertical()
	if show_portrait:
		if portrait_texture != null:
			portrait.texture = portrait_texture
			portrait.modulate = Color.WHITE   # real art: never tint it
		else:
			portrait.texture = _default_portrait
			portrait.modulate = portrait_tint
	var pages := _paginate(text)
	# Sized ONCE for the whole speech, not per page. The box stays up between
	# pages, so a per-page height would be seen as the banner growing and
	# shrinking mid-sentence — the one thing _fit_banner gets away with only
	# because it normally happens while the box is hidden.
	_fit_banner(_rows_in(pages[0]) if pages.size() == 1 else max_lines)
	_place_vside(vside)
	_active = true
	visible = true
	for page in pages:
		_begin_page(page)
		await line_finished
	visible = false
	_active = false


## Set one page going: strip its breath mark, note where it sat, and start the
## typewriter from nothing.
##
## The mark is a timing instruction, not words. Its position in the raw string IS
## its index in the stripped one, since everything before it is untouched — and
## it is looked up PER PAGE, so a breath keeps the words it was written between
## however the speech happens to break.
func _begin_page(raw: String) -> void:
	_pause_at = raw.find(PAUSE_MARK)
	text_label.text = raw.replace(PAUSE_MARK, "") if _pause_at >= 0 else raw
	_pause_left = 0.0
	text_label.visible_characters = 0
	arrow.visible = false
	_reveal_accum = 0.0
	_revealing = true


## Break a line into pages of at most `max_lines` rows.
##
## AT SENTENCE BOUNDARIES wherever it can. Packing words greedily is simpler and
## reads badly: the first attempt broke Rumi's last line as "...the ones that
## grew" / "toward the light.", which is a page turn in the middle of a clause.
## Whole sentences are packed instead, and only a sentence too tall for a page on
## its own falls back to breaking on words (see _atoms).
##
## Measured against the SPOKEN text — the breath mark is carried along so it stays
## with its words, but never counted, since it is not drawn.
func _paginate(text: String) -> Array[String]:
	if max_lines <= 0 or text_label.get_theme_font("font") == null:
		return [text]
	if _rows_in(text) <= max_lines:
		return [text]
	var pages: Array[String] = []
	var current := ""
	for atom in _atoms(text):
		var candidate: String = atom if current == "" else current + " " + atom
		if current != "" and _rows_in(candidate) > max_lines:
			pages.append(current)
			current = atom
		else:
			current = candidate
	if current != "":
		pages.append(current)
	return pages


## The largest pieces a page may be built out of: whole sentences, except that a
## sentence too tall for a page on its own is pre-broken into word runs that fit.
##
## A single word too long for a whole page cannot happen with this type at this
## width, but the `run != ""` guard means it would come out on an over-long page
## of its own rather than looping forever looking for a break.
func _atoms(text: String) -> Array[String]:
	var out: Array[String] = []
	for sentence in _sentences(text):
		if _rows_in(sentence) <= max_lines:
			out.append(sentence)
			continue
		var run := ""
		for word in sentence.split(" ", false):
			var candidate: String = word if run == "" else run + " " + word
			if run != "" and _rows_in(candidate) > max_lines:
				out.append(run)
				run = word
			else:
				run = candidate
		if run != "":
			out.append(run)
	return out


## Split on sentence endings, keeping the punctuation with the sentence it ends.
##
## AN ELLIPSIS IS NOT AN ENDING. "Meaning... the more I think it" is one
## sentence with a hesitation in it, and treating the dots as a full stop would
## offer a page break in the middle of a held breath — the exact place a scene
## least wants one. Any run of two or more dots is therefore skipped over.
func _sentences(text: String) -> Array[String]:
	var out: Array[String] = []
	var start := 0
	var i := 0
	while i < text.length():
		if not text[i] in ".?!":
			i += 1
			continue
		var stop := i
		while stop + 1 < text.length() and text[stop + 1] in ".?!":
			stop += 1
		var run := text.substr(i, stop - i + 1)
		# A real ending is followed by a space or by nothing at all — otherwise it
		# is a decimal point or an abbreviation, and no break belongs there.
		if run.count(".") < 2 and (stop + 1 >= text.length() or text[stop + 1] == " "):
			out.append(text.substr(start, stop - start + 1).strip_edges())
			start = stop + 1
		i = stop + 1
	if start < text.length():
		var tail := text.substr(start).strip_edges()
		if tail != "":
			out.append(tail)
	return out


## How many rows `raw` wraps to in the text block, with the breath mark ignored.
func _rows_in(raw: String) -> int:
	var font := text_label.get_theme_font("font")
	if font == null:
		return 1
	var size := text_label.get_theme_font_size("font_size")
	# offset_right/left rather than `size.x`: the left edge was just moved for
	# this line's portrait, and the rect does not catch up until layout runs.
	var width := text_label.offset_right - text_label.offset_left
	var wrapped := font.get_multiline_string_size(
		raw.replace(PAUSE_MARK, ""), HORIZONTAL_ALIGNMENT_CENTER, width, size)
	return maxi(int(round(wrapped.y / float(size))), 1)


## Size the banner to `rows` of text, never more than max_lines.
##
## The box hides between LINES (say() ends with visible = false), so a per-line
## size is never seen as a morph — the banner simply comes back the right size.
## It does NOT hide between pages of one line, which is why the caller passes a
## row count for the whole speech instead of this measuring what is on screen.
##
## Needed because the type is large enough that a long line wraps to three rows,
## and the box was a fixed 146px: the opening scene's longest line ran well past
## that and had its last row cut off. Shrinking the font was the alternative and
## is the wrong trade — the size is the thing that makes this read like Celeste.
##
## Deliberately not naming the line any more. It used to quote the one that
## overflowed, and that line has since been rewritten twice — a comment pinned to
## dialogue goes stale every time someone edits the script, which is exactly the
## kind of rot that makes the next reader distrust the reasoning around it.
func _fit_banner(rows: int) -> void:
	var font := text_label.get_theme_font("font")
	if font == null:
		return
	var size := text_label.get_theme_font_size("font_size")
	rows = clampi(rows, 1, max_lines)
	# The font's own line height, not `size`. A 40px font draws taller than 40px
	# once ascent and descent are counted, and sizing off the point size cuts the
	# bottom row off — which is the exact bug _fit_banner was written to fix.
	var needed: float = font.get_height(size) * rows \
		+ float(text_label.get_theme_constant("line_spacing")) * (rows - 1)
	text_label.offset_bottom = text_label.offset_top \
		+ maxf(needed + BANNER_PAD, MIN_TEXT_HEIGHT)
	# The banner carries a band on its trailing edge as well as its leading one,
	# so it owes TRIM_HEIGHT of height that is not text. Everything below is
	# measured off the band rather than off the banner, or the arrow draws on
	# top of the ornament.
	banner.offset_bottom = text_label.offset_bottom + BANNER_PAD + TRIM_HEIGHT
	trim_bottom.offset_bottom = banner.offset_bottom
	trim_bottom.offset_top = banner.offset_bottom - TRIM_HEIGHT
	arrow.offset_bottom = trim_bottom.offset_top - 2.0
	arrow.offset_top = arrow.offset_bottom - ARROW_HEIGHT


func _process(delta: float) -> void:
	if not _revealing:
		return
	if _pause_left > 0.0:
		_pause_left -= delta
		return
	_reveal_accum += chars_per_second * delta
	if _pause_at >= 0 and int(_reveal_accum) >= _pause_at:
		# Land exactly on the mark rather than wherever this frame's delta
		# overshot to, so the hold reads the same at any frame rate.
		_reveal_accum = float(_pause_at)
		_pause_left = pause_time
		_pause_at = -1  # one beat per line, and it has now been spent
		text_label.visible_characters = int(_reveal_accum)
		return
	text_label.visible_characters = int(_reveal_accum)
	if text_label.visible_characters >= text_label.text.length():
		text_label.visible_characters = -1  # -1 = show everything
		_revealing = false
		arrow.visible = true  # "press to advance" cue


func _unhandled_input(event: InputEvent) -> void:
	if not _active:
		return
	if event.is_action_pressed("jump") or event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		if _revealing:
			# First press: finish the reveal instantly. Skipping ahead skips the
			# breath too — holding a reader at a dramatic beat they have just
			# asked to skip past is the wrong way round.
			text_label.visible_characters = -1
			_revealing = false
			_pause_at = -1
			_pause_left = 0.0
			arrow.visible = true
		else:
			# Second press: dismiss.
			line_finished.emit()
