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
## Weight added to the UI font. Godot's default font ships in one weight; a
## little synthetic emboldening is what gives the Celeste-ish solid look.
@export_range(0.0, 1.0) var font_weight := 0.28
## Left edge of the text block, in the box's own space: clear of the portrait
## frame, or near the banner edge when there is no portrait.
const PORTRAIT_TEXT_LEFT := 256.0
const FULL_TEXT_LEFT := 48.0

## Extra pixels between glyphs, in the box's own 1280x720 space. Celeste's type
## is noticeably tracked-out; without this it reads cramped at this size.
@export var letter_spacing := 2

var _active := false
var _revealing := false
var _reveal_accum := 0.0

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
	text_label.text = text
	text_label.visible_characters = 0
	arrow.visible = false
	_reveal_accum = 0.0
	_revealing = true
	_active = true
	visible = true
	await line_finished
	visible = false
	_active = false


func _process(delta: float) -> void:
	if not _revealing:
		return
	_reveal_accum += chars_per_second * delta
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
			# First press: finish the reveal instantly.
			text_label.visible_characters = -1
			_revealing = false
			arrow.visible = true
		else:
			# Second press: dismiss.
			line_finished.emit()
