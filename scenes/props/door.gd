class_name Door
extends Node2D
## A door that swings OUTWARD (away from the viewer) on cue. In this side view
## that reads as the leaf foreshortening — it flattens toward its hinge edge
## until it's a thin sliver, revealing the opening. The frame stays put; the
## leaf (+ knob) is parented to a Hinge on the hinge side and its x-scale
## collapses. Call open() once, e.g. when the player reaches the doorway.

signal opened

## How thin the leaf gets when fully open (x-scale). ~0 = edge-on/flattened.
@export var open_scale_x := 0.06
## Swing duration in seconds.
@export var open_time := 0.5

var is_open := false

@onready var hinge: Node2D = $Hinge


func open() -> void:
	if is_open:
		return
	is_open = true
	var t := create_tween()
	t.tween_property(hinge, "scale:x", open_scale_x, open_time) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.finished.connect(func(): opened.emit())
