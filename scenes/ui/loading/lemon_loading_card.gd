class_name LemonLoadingCard
extends CanvasLayer
## Full-resolution watercolor UI; the game remains on its own 320x180 surface.

signal reading_finished

## Delay before the upper-left phrase begins fading in.
@export var first_delay := 0.15
## Delay before the lower-right instruction appears.
@export var second_delay := 1.2
## Delay before the smaller last thought appears.
@export var third_delay := 2.15
## How long each phrase takes to emerge from the paper.
@export var reveal_time := 0.5
## Minimum time on screen, including time to read the final phrase.
@export var reading_time := 3.75
## Fade back to the game after loading and reading both finish.
@export var dismiss_time := 0.25

@onready var first: Label = $Root/First
@onready var second: Label = $Root/Second
@onready var third: Label = $Root/Third
@onready var root: Control = $Root

var elapsed := 0.0
var readable := false
var _closing := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_elapsed(0.0)


func _process(delta: float) -> void:
	if not _closing:
		# Hitstop in the world must not slow the lettering's UI clock.
		set_elapsed(elapsed + delta / maxf(Engine.time_scale, 0.001))


func set_elapsed(seconds: float) -> void:
	elapsed = seconds
	first.modulate.a = _reveal(first_delay)
	second.modulate.a = _reveal(maxf(second_delay, first_delay + reveal_time))
	third.modulate.a = _reveal(maxf(third_delay, second_delay + reveal_time))
	if not readable and elapsed >= maxf(reading_time, third_delay + reveal_time):
		readable = true
		reading_finished.emit()


func _reveal(start: float) -> float:
	return smoothstep(0.0, 1.0, clampf((elapsed - start) / maxf(reveal_time, 0.001), 0.0, 1.0))


func dismiss() -> void:
	_closing = true
	var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_ignore_time_scale(true)
	tween.tween_property(root, "modulate:a", 0.0, dismiss_time)
	await tween.finished


func _input(event: InputEvent) -> void:
	if event is InputEventKey or event is InputEventJoypadButton or event is InputEventJoypadMotion \
			or event is InputEventMouse or event is InputEventScreenTouch or event is InputEventScreenDrag:
		get_viewport().set_input_as_handled()
