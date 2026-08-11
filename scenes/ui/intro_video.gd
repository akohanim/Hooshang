class_name IntroVideo
extends CanvasLayer
## The opening film, played once when a run BEGINS and never again.
##
## It CANNOT be skipped — see _input below.
##
## Story setup belongs to starting a story. A player who picks CONTINUE has
## already seen it and is coming back to play, so replaying it there would be a
## 47-second toll on every session — which is how a good intro becomes the thing
## people remember disliking. The two rules work together: it is unskippable
## precisely BECAUSE it is asked for once and never again. Wired to the two NEW
## GAME paths in main_menu.gd and to nothing else — CONTINUE, LOAD, level select
## and both debug pickers get past it by never asking for it at all.
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

## Fired when the film is over — played out, or never started because the stream
## is missing. Always exactly once, so a caller can await it and know it will be
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
	if video.stream == null:
		# Missing or unconvertible stream. Finish immediately rather than sitting
		# on a black rectangle forever — the intro is not worth being the reason
		# a new game cannot start. The one case that is NOT unskippable, because
		# there is nothing to watch.
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


## Two different jobs, either side of the film ending.
##
## WHILE IT PLAYS it is NOT SKIPPABLE, on purpose: 47 seconds is the only place
## the premise of the game is stated, and a player who taps past it starts Act I
## not knowing the building is his own head — the whole first conversation with
## Rumi then lands as nonsense. It is asked for on a NEW run and nowhere else, so
## nobody is ever made to sit through it twice, which is the only thing that
## makes an unskippable cutscene defensible.
##
## ONCE IT HAS ENDED the first press is what starts the run.
##
## Input is swallowed in BOTH states, never ignored. Without that the presses
## land on whatever is behind the film — the main menu is still in the tree with
## its rows live — so mashing a button during the film would be quietly
## navigating a menu nobody can see, and arriving in the world with a different
## row chosen. Consuming it is what makes "unskippable" mean nothing happens.
func _input(event: InputEvent) -> void:
	if _over:
		return
	# Typed, not inferred: `event.pressed` on an untyped InputEvent is a Variant,
	# and `:=` refuses to guess a bool from it.
	var pressed: bool = (event is InputEventKey and event.pressed and not event.echo) \
		or (event is InputEventJoypadButton and event.pressed) \
		or (event is InputEventMouseButton and event.pressed)
	# Motion is consumed too, but never counts as the press: a stick resting off
	# centre, or a mouse crossing the window, would otherwise dismiss the title
	# card before the player had looked at it.
	if pressed or event is InputEventMouseMotion or event is InputEventJoypadMotion:
		get_viewport().set_input_as_handled()
	if pressed and _waiting:
		_finish()


## One way out, however it ended. Guarded because `finished` and the missing
## stream path can both reach here, and `done` firing twice would resume the
## caller twice — starting two new games on top of each other.
func _finish() -> void:
	if _over:
		return
	_over = true
	_waiting = false
	var t := create_tween()
	t.tween_property($Background, "modulate:a", 0.0, fade_time)
	t.parallel().tween_property(video, "modulate:a", 0.0, fade_time)
	await t.finished
	# Stopped only now. stop() clears the held last frame, so calling it before
	# the fade would blank the title card and fade out a black rectangle.
	video.stop()
	done.emit()
