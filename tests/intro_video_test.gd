extends Node
## The opening film plays on a NEW run and on nothing else.
##
## Three failures this is here to catch, all silent:
##
##   1. THE FORMAT. Godot's VideoStreamPlayer reads Ogg Theora and nothing else.
##      Hand it an MP4 and it does not complain — it sits there with a null
##      stream showing black, which in play is indistinguishable from "the intro
##      is broken" and in code is indistinguishable from nothing. So the stream
##      is asserted to exist and to actually be Theora.
##
##   2. THE ROUTING. "Plays once at the start" is a rule about which menu rows
##      touch it, and menu rows get refactored. A CONTINUE that grew an intro
##      would put a 47-second toll on every session, and nobody would file that
##      as a bug — they would just stop playing.
##
##   3. THE SKIP. It is deliberately unskippable DURING playback, and then
##      deliberately waits for a press once it ends. Both halves matter: the
##      first is a choice a later
##      change is very likely to "fix" out of sympathy for the player. It is
##      only defensible because it is asked for exactly once, so if the routing
##      above ever breaks, this rule has to break with it — hence both here.
##
## Run:  godot --headless res://tests/intro_video_test.tscn

const MENU := "res://scenes/ui/MainMenu.tscn"
const INTRO := "res://scenes/ui/IntroVideo.tscn"

var failures: Array[String] = []
var menu: Node


func _ready() -> void:
	# Never the real save folder: a test must not be able to eat a run.
	SaveGame.dir = "user://_test_intro_saves"
	_wipe()

	# --- 1. the stream is there, and is a format Godot can actually play ------
	var intro: CanvasLayer = load(INTRO).instantiate()
	add_child(intro)
	await _frames(2)
	var stream: VideoStream = (intro.get_node("Video") as VideoStreamPlayer).stream
	_check(stream != null, "the intro has a stream at all")
	_check(stream != null and stream is VideoStreamTheora,
		"and it is Ogg Theora, the one container Godot plays  [%s]"
			% ("null" if stream == null else stream.get_class()))
	_check(intro.layer > 110,
		"it draws over the main menu  [layer %d]" % intro.layer)
	intro.free()

	# --- 2. a NEW run plays it ----------------------------------------------
	await _open_menu()
	_press("NEW GAME")
	await _frames(4)
	_press("SLOT 1")            # empty here, so no overwrite guard
	await _frames(8)
	_check(_intro_in_tree() != null, "starting a new run plays the film")

	# It must NOT be skippable. Mash the buttons a player would reach for and
	# assert the film is still running afterwards — this is the whole rule, and
	# it is the kind of thing a later "let me out of this" change quietly undoes.
	var playing := _intro_in_tree()
	if playing != null:
		for code in [KEY_ENTER, KEY_SPACE, KEY_ESCAPE, KEY_SHIFT]:
			var k := InputEventKey.new()
			k.keycode = code
			k.pressed = true
			Input.parse_input_event(k)
			await _frames(2)
		var pad := InputEventJoypadButton.new()
		pad.button_index = JOY_BUTTON_A
		pad.pressed = true
		Input.parse_input_event(pad)
		await _frames(2)
		_check(_intro_in_tree() != null,
			"mashing enter/space/escape/shift/pad does NOT skip the film")
		_check((playing.get_node("Video") as VideoStreamPlayer).is_playing(),
			"and it is still playing, not merely still on screen")
		_check(playing.get_node_or_null("Prompt") == null,
			"no engine-drawn prompt over the film — its last frame carries that")
		# Those presses must not have leaked to the menu behind it either: the
		# main menu is still in the tree with live rows, so an unconsumed press
		# would have been navigating a screen nobody can see.
		_check(Screen.current == null,
			"and nothing behind it acted on the presses  [%s]" % Screen.current)

		# The film plays out. It must then HOLD on its last frame — the run does
		# not begin on its own — so this stands in for the video reaching its end.
		playing._hold_on_title()
		await _hold(1.2)
		_check(_intro_in_tree() != null,
			"when it ends it holds on the title card instead of starting the run")
		_check(Screen.current == null,
			"and the world is still not loaded  [%s]" % Screen.current)
		# NOW a press starts the run.
		var go := InputEventKey.new()
		go.keycode = KEY_ENTER
		go.pressed = true
		Input.parse_input_event(go)
		await _hold(1.6)
		_check(_intro_in_tree() == null, "a press dismisses the title card")
		_check(Screen.current != null,
			"and the run starts  [%s]" % Screen.current)

	# --- 3. a CONTINUED run does not ----------------------------------------
	# A slot written by hand, so this does not depend on the run above having
	# reached a room and autosaved.
	_write_slot(0)
	Screen.clear()
	await _open_menu()
	var rows := _labels()
	_check(rows.has("CONTINUE"), "a written slot offers CONTINUE  [%s]" % str(rows))
	_press("CONTINUE")
	await _frames(10)
	_check(_intro_in_tree() == null,
		"continuing a run does NOT play the film")
	_check(Screen.current != null, "and it loads the world  [%s]" % Screen.current)

	_wipe()
	if failures.is_empty():
		print("INTRO VIDEO TEST: ALL PASS")
	else:
		print("INTRO VIDEO TEST: %d FAILURE(S)" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)


func _open_menu() -> void:
	if is_instance_valid(menu):
		menu.free()
	menu = load(MENU).instantiate()
	get_tree().root.add_child(menu)
	await _hold(0.4)


func _labels() -> Array:
	var out := []
	for r in menu._rows:
		out.append(str(r["text"]))
	return out


func _press(label: String) -> void:
	for i in menu._rows.size():
		if str(menu._rows[i]["text"]) == label:
			menu.selected = i
			menu.choose()
			return
	_check(false, "menu has a row called '%s'  [%s]" % [label, str(_labels())])


## The film, if one is up. Found by class rather than by path, since it attaches
## itself to the root rather than to whoever asked for it.
func _intro_in_tree() -> Node:
	for child in get_tree().root.get_children():
		if child is IntroVideo:
			return child
	return null


func _write_slot(i: int) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SaveGame.dir))
	var f := FileAccess.open(SaveGame.slot_path(i), FileAccess.WRITE)
	f.store_string(JSON.stringify({
		"schema": 1,
		"world": "res://ldtk/Act1World.tscn",
		"world_state": {"room": "Level_3", "has_dash": true},
	}))
	f.close()


func _wipe() -> void:
	var path := ProjectSettings.globalize_path(SaveGame.dir)
	var d := DirAccess.open(path)
	if d == null:
		return
	for name in d.get_files():
		d.remove(name)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _hold(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _check(cond: bool, name: String) -> void:
	print(("  PASS  " if cond else "  FAIL  ") + name)
	if not cond:
		failures.append(name)
