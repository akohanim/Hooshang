class_name DialogueBox
extends CanvasLayer
## Reusable Celeste-style dialogue box: a banner across the top of the screen
## with a framed character portrait on the right and typewriter text.
## Usage (from any cutscene code):
##     await dialogue.say("Rumi", "Some line.", Color(1, 0.82, 0.42))  # portrait
##     await dialogue.say("", "Press X to dash.")                       # system, no portrait
## First confirm press (jump / ui_accept) completes the reveal instantly,
## second press closes the box. `say` returns when the box closes.
##
## FUTURE: multi-line conversations = await say() in sequence. Per-character
## portraits/voices hook in here; the portrait is tinted per speaker for now.

signal line_finished

## Reveal speed of the typewriter effect, in characters per second.
@export var chars_per_second := 40.0

var _active := false
var _revealing := false
var _reveal_accum := 0.0

@onready var name_label: Label = $NameLabel
@onready var text_label: Label = $TextLabel
@onready var arrow: Label = $Arrow
@onready var portrait: TextureRect = $Portrait
@onready var portrait_frame: ColorRect = $PortraitFrame


func _ready() -> void:
	visible = false


## Show one line and wait until the player has read + dismissed it.
## portrait_tint alpha 0 = system text (no portrait shown).
func say(speaker: String, text: String, portrait_tint := Color(0, 0, 0, 0)) -> void:
	name_label.text = speaker
	name_label.visible = speaker != ""
	var show_portrait := portrait_tint.a > 0.0
	portrait.visible = show_portrait
	portrait_frame.visible = show_portrait
	if show_portrait:
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
