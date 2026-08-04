class_name EmoteBubble
extends Node2D
## A reaction over a character's head — the "!" and "..." beats.
##
## WORLD-SPACE, not UI, and that is the whole point of it. This is drawn inside
## the 320x180 game viewport alongside the sprites, so it rasterises on their
## pixel grid and belongs to the character; the dialogue banner is the opposite
## case (window resolution, real type — see systems/screen.gd).
##
## The split is a writing rule as much as a rendering one. A line is something
## you READ; a reaction is something you watch him DO. A banner that opens,
## types out "...", and waits for a button press turns a beat of silence into
## admin. Pure punctuation goes here instead — see Act1Beats.EMOTE_LINES.
##
## The node's origin is the TAIL TIP, so putting one at head height points it at
## the character and hangs the bubble above them.

signal finished

enum Kind { EXCLAIM, ELLIPSIS }

const ART := {
	Kind.EXCLAIM: preload("res://assets/emote_exclaim.png"),
	Kind.ELLIPSIS: preload("res://assets/emote_ellipsis.png"),
}

## How far below its resting place the bubble starts, and how long it takes to
## snap up. Position rather than scale: transforms are pixel-snapped
## (project.godot 2d/snap/snap_2d_transforms_to_pixel) so this stays crisp,
## whereas tweening scale on 18px art through fractional values under nearest
## filtering shimmers.
@export var pop_from := 4.0
@export var pop_time := 0.18
## How long it sits fully readable before going. A full second: these carry a
## story beat on their own, and they cannot be dismissed with a button the way
## a dialogue line can, so they have to hold long enough to land unaided.
@export var hold_time := 1.0
## Fade out, and the small drift up that goes with it.
@export var fade_time := 0.2
@export var fade_rise := 3.0

var kind: Kind = Kind.EXCLAIM

@onready var _sprite: Sprite2D = $Sprite


func _ready() -> void:
	add_to_group("emote")


## Show one reaction and return when it has gone.
func play(k: Kind) -> void:
	kind = k
	_sprite.texture = ART[k]
	var rest := position.y
	position.y = rest + pop_from
	modulate.a = 0.0

	var t := create_tween()
	t.set_parallel()
	t.tween_property(self, "position:y", rest, pop_time) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "modulate:a", 1.0, pop_time * 0.5)
	t.chain().tween_interval(hold_time)
	t.chain().set_parallel()
	t.tween_property(self, "modulate:a", 0.0, fade_time)
	t.tween_property(self, "position:y", rest - fade_rise, fade_time) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await t.finished
	finished.emit()


## What this bubble is saying, in the same notation the script uses.
func kind_name() -> String:
	return "!" if kind == Kind.EXCLAIM else "..."
