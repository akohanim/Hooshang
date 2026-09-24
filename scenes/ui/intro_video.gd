class_name IntroVideo
extends CanvasLayer
## The opening film, played once when a run BEGINS and never again.
##
## Hold the dialogue-skip button to leave the film early. CONTINUE and level
## select still bypass it entirely; NEW GAME offers the film with a skip prompt.
##
## FORMAT. The stream is Ogg Theora, because that is the only container Godot's
## VideoStreamPlayer reads — it does not play MP4/H.264, and it fails SILENTLY,
## showing a blank node rather than complaining. tools/convert_intro_video.sh is
## how assets/video/intro.ogv is produced from the authored file.
##
## Lives on the window's own surface at layer 130 — above the main menu (110),
## the pause menu (100) and Game's level fade (128) — and not inside Screen's
## 320x180 game viewport, which would resample 720p footage down to a postage
## stamp. Same reasoning as every other UI scene here; see systems/screen.gd.

## How long the fade out at the end takes.
@export var fade_time := 0.6
@export var skip_hold_time := 1.0

@onready var skip_prompt: Control = $SkipPrompt
@onready var skip_label: Label = $SkipPrompt/Label
@onready var skip_fill: ColorRect = $SkipPrompt/Track/Fill
var _skip_held := 0.0
var _skip_needs_release := false

## Fired when the film is over — played out, or never started because the stream
## is missing, or deliberately skipped. Always exactly once, so a caller can await it and know it will be
## resumed whatever happens.
signal done()

@onready var video: VideoStreamPlayer = $Video

var _over := false
## True once the film has played out and it is waiting to be dismissed.
var _waiting := false


## Play the intro over everything and return when it is done.
##
## Static, taking the tree, so a caller does not have to know where this lives or
## what to parent it to: `await IntroVideo.play_for(get_tree())` is the whole API.
## It attaches to the ROOT rather than to the caller, because the caller is the
## main menu and the menu disables itself on the way out — a node parented to a
## disabled node stops processing, and the film would freeze on frame one.
static func play_for(tree: SceneTree) -> void:
	var scene: PackedScene = load("res://scenes/ui/IntroVideo.tscn")
	if scene == null:
		return
	var intro: IntroVideo = scene.instantiate()
	tree.root.add_child(intro)
	await intro.done
	intro.queue_free()


func _ready() -> void:
	# ALWAYS: whatever else is going on, the film has to keep running.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_skip_needs_release = Input.is_action_pressed("skip_dialogue")
	_update_skip_prompt()
	if video.stream == null:
		# Missing or unconvertible stream. Finish immediately rather than sitting
		# on a black rectangle forever — the intro is not worth being the reason
		# a new game cannot start.
		push_warning("IntroVideo: no stream — skipping the opening film.")
		_finish()
		return
	video.finished.connect(_hold_on_title)
	video.play()


## The film has played out. Hold there on its final frame until the player says
## go — the run does NOT start on its own.
##
## No prompt is drawn over it: the film's own last frame already says "press any
## button". A second one from the engine would be the same instruction twice, in
## a different typeface, on top of art that was made to carry it.
##
## Nothing is done to keep that frame up: a VideoStreamPlayer that has finished
## keeps its last decoded frame in the texture and keeps drawing it (measured —
## the alternative was copying it into a TextureRect, which turned out to be
## solving a problem that does not exist). It is only ever cleared by stop(),
## which is why _finish() below stops it AFTER the fade rather than before.
func _hold_on_title() -> void:
	if _over:
		return
	_waiting = true
	skip_prompt.hide()


func _process(delta: float) -> void:
	if _over or _waiting:
		return
	_update_skip_prompt()
	if not Input.is_action_pressed("skip_dialogue"):
		_skip_needs_release = false
		_skip_held = 0.0
	elif not _skip_needs_release:
		_skip_held += delta
	skip_fill.anchor_right = clampf(_skip_held / skip_hold_time, 0.0, 1.0)
	if _skip_held >= skip_hold_time:
		_finish()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_skip_held = 0.0
		_skip_needs_release = true


func _update_skip_prompt() -> void:
	var button := "X / □" if InputDevice.is_controller() else "X"
	if not InputDevice.is_controller():
		for event in InputMap.action_get_events("skip_dialogue"):
			if event is InputEventKey:
				button = OS.get_keycode_string(event.physical_keycode if event.physical_keycode else event.keycode)
				break
	skip_label.text = "Hold %s to skip intro" % button


## Consume input throughout playback and the exit fade so it cannot reach the
## menu underneath. Ordinary taps only dismiss the completed film's title card.
func _input(event: InputEvent) -> void:
	# Typed, not inferred: `event.pressed` on an untyped InputEvent is a Variant,
	# and `:=` refuses to guess a bool from it.
	var pressed: bool = (event is InputEventKey and event.pressed and not event.echo) \
		or (event is InputEventJoypadButton and event.pressed) \
		or (event is InputEventMouseButton and event.pressed)
	# Motion is consumed too, but never counts as the press: a stick resting off
	# centre, or a mouse crossing the window, would otherwise dismiss the title
	# card before the player had looked at it.
	if event is InputEventKey or event is InputEventJoypadButton or event is InputEventMouseButton \
			or event is InputEventMouseMotion or event is InputEventJoypadMotion:
		get_viewport().set_input_as_handled()
	if pressed and _waiting and not _over:
		_finish()


## One way out, however it ended. Guarded because `finished` and the missing
## stream path can both reach here, and `done` firing twice would resume the
## caller twice — starting two new games on top of each other.
func _finish() -> void:
	if _over:
		return
	_over = true
	_waiting = false
	skip_prompt.hide()
	var t := create_tween()
	t.tween_property($Background, "modulate:a", 0.0, fade_time)
	t.parallel().tween_property(video, "modulate:a", 0.0, fade_time)
	t.parallel().tween_property(video, "volume", 0.0, fade_time)
	await t.finished
	# Stopped only now. stop() clears the held last frame, so calling it before
	# the fade would blank the title card and fade out a black rectangle.
	video.stop()
	done.emit()
