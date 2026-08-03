class_name DialogueBox
extends CanvasLayer
## Celeste-style dialogue box: a dark banner across the top of the screen with a
## framed portrait on the LEFT and large centred typewriter text.
## Usage (from any cutscene code):
##     await Dialogue.say("Rumi", "Some line.", RUMI_GOLD)            # tinted stand-in
##     await Dialogue.say("Hooshang", "...I fell.", Color.WHITE, tex)  # real portrait
##     await Dialogue.say("", "Press X to dash.")                      # system, no portrait
## First confirm press (jump / ui_accept) completes the reveal instantly,
## second press closes the box. `say` returns when the box closes.
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
## FUTURE: multi-line conversations = await say() in sequence. Rumi still uses a
## tinted stand-in; give him a portrait set and pass it the same way as Hooshang.

signal line_finished

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
## Left edge of the text block, in the box's own space: clear of the portrait
## frame, or near the banner edge when there is no portrait.
const PORTRAIT_TEXT_LEFT := 256.0
const FULL_TEXT_LEFT := 48.0

## Banner sizing. The text block never shrinks below MIN_TEXT_HEIGHT, which is
## the height the box was fixed at and what one- and two-row lines still get, so
## the overwhelming majority of lines look exactly as they did.
const MIN_TEXT_HEIGHT := 146.0
## Gap under the text, and the arrow's own box.
const BANNER_PAD := 8.0
const ARROW_HEIGHT := 44.0

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
@onready var name_label: Label = $NameLabel
@onready var text_label: Label = $TextLabel
@onready var arrow: Label = $Arrow
@onready var portrait: TextureRect = $Portrait
@onready var portrait_frame: ColorRect = $PortraitFrame
@onready var portrait_back: ColorRect = $PortraitBack
## The scene's built-in stand-in, kept so a tinted speaker can go back to it
## after a line that supplied real art.
@onready var _default_portrait: Texture2D = $Portrait.texture


func _ready() -> void:
	visible = false
	_apply_font()


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
		portrait_texture: Texture2D = null) -> void:
	name_label.text = speaker
	name_label.visible = speaker != ""
	var show_portrait := portrait_tint.a > 0.0 or portrait_texture != null
	portrait.visible = show_portrait
	portrait_frame.visible = show_portrait
	portrait_back.visible = show_portrait
	# With no portrait the text owns the whole banner, so it reads centred rather
	# than hanging off to the right of an empty frame.
	var left := PORTRAIT_TEXT_LEFT if show_portrait else FULL_TEXT_LEFT
	text_label.offset_left = left
	name_label.offset_left = left
	if show_portrait:
		if portrait_texture != null:
			portrait.texture = portrait_texture
			portrait.modulate = Color.WHITE   # real art: never tint it
		else:
			portrait.texture = _default_portrait
			portrait.modulate = portrait_tint
	# The mark is a timing instruction, not words: strip it, and remember the
	# index it sat at so the reveal knows where to hold. Its position in the raw
	# string IS its index in the stripped one, since everything before it is
	# untouched.
	_pause_at = text.find(PAUSE_MARK)
	text_label.text = text.replace(PAUSE_MARK, "") if _pause_at >= 0 else text
	_fit_banner()
	_pause_left = 0.0
	text_label.visible_characters = 0
	arrow.visible = false
	_reveal_accum = 0.0
	_revealing = true
	_active = true
	visible = true
	await line_finished
	visible = false
	_active = false


## Grow the banner to fit the line just set, if the line needs it.
##
## The box hides between lines (say() ends with visible = false), so a per-line
## size is never seen as a morph — the banner simply comes back the right size.
##
## Needed because the type is large enough that a long line wraps to three rows,
## and the box was a fixed 146px: "Who are you? I've worked in this office
## fifteen years. I've never once seen you at an all hands." measures 181px and
## had its last row cut off. Shrinking the font was the alternative and is the
## wrong trade — the size is the thing that makes this read like Celeste.
func _fit_banner() -> void:
	var font := text_label.get_theme_font("font")
	if font == null:
		return
	var size := text_label.get_theme_font_size("font_size")
	# offset_right/left rather than `size.x`: the left edge was just moved for
	# this line's portrait, and the rect does not catch up until layout runs.
	var width := text_label.offset_right - text_label.offset_left
	var wrapped := font.get_multiline_string_size(
		text_label.text, HORIZONTAL_ALIGNMENT_CENTER, width, size)
	var rows := maxi(int(round(wrapped.y / float(size))), 1)
	var needed: float = wrapped.y \
		+ float(text_label.get_theme_constant("line_spacing")) * (rows - 1)
	text_label.offset_bottom = text_label.offset_top \
		+ maxf(needed + BANNER_PAD, MIN_TEXT_HEIGHT)
	banner.offset_bottom = text_label.offset_bottom + BANNER_PAD
	arrow.offset_bottom = banner.offset_bottom - BANNER_PAD
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
