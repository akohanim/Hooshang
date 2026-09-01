extends Node
## Celeste-style dialogue VOICE BLIPS: systems/voice_blips.gd (the VoiceBlips
## autoload) synthesizes short syllables, banked per speaker+portrait-state and
## per tier (passing / emphasized / ending), and DialogueBox retriggers them as
## its typewriter reveals each character — see the VOICE note in
## scenes/ui/dialogue_box.gd.
##
## Everything here is a thing that breaks SILENTLY, the same way the talking
## portrait rig does (portrait_anim_test.gd): a manifest that fails to load, a
## blip that fires during a pause or between pages, an "emphasized" pick that
## slips out twice in a row — none of them raise an error, none of them stop a
## run, and all of them are only audible to somebody actually listening to a
## line play.
##
## Reveal is driven BY HAND (box._process(delta) called directly, no real
## frame waits) once a page has actually started — the same trick
## thought_tiles_test.gd and portrait_anim_test.gd use, and for the same
## reason: idle-process delta has no fixed relationship to wall-clock frames
## in a headless run, so waiting on real frames for a whole line to reveal
## would be both slow and a source of flakiness this test has no need for.
##
## Run:  godot --headless res://tests/voice_blip_test.tscn

const ANNOYED := preload("res://assets/portraits/hooshang_annoyed.png")
const VULNERABLE := preload("res://assets/portraits/hooshang_vulnerable.png")

var failures: Array[String] = []
var _blips: Array[Dictionary] = []


func _ready() -> void:
	VoiceBlips.blipped.connect(_on_blipped)
	var box: DialogueBox = Dialogue

	# --- the manifest loads off res:// at all ---------------------------------
	_check(not VoiceBlips._manifest.is_empty(),
		"the voice manifest loads off res://  [%d keys]" % VoiceBlips._manifest.size())
	_check(VoiceBlips._manifest.has("hooshang_annoyed"),
		"...and holds a Hooshang state")
	_check(VoiceBlips._manifest.has("rumi_wistful"),
		"...and a Rumi state")
	var pools: Dictionary = VoiceBlips._manifest.get("hooshang_annoyed", {})
	_check(int(pools.get("passing", 0)) > 0 and int(pools.get("emphasized", 0)) > 0
			and int(pools.get("ending", 0)) > 0,
		"...with all three tiers populated  [%s]" % pools)

	# --- a line WITH a portrait voices while revealing ------------------------
	await _say_line(box, "Hooshang", "A short line here now, spoken aloud.",
		Color(1, 1, 1, 1), ANNOYED)
	_blips.clear()
	_reveal_all(box)
	_check(_blips.size() > 0,
		"revealing a line with a portrait fires voice blips  [%d]" % _blips.size())
	var wrong_key := false
	for b in _blips:
		if b.key != "hooshang_annoyed":
			wrong_key = true
	_check(not wrong_key,
		"...every blip comes from the speaking state's own pool  [%s]"
			% [_blips.map(func(b): return b.key)])
	_check(_blips[-1].tier == "ending",
		"...and the page finishing plays one ENDING-tier blip last  [%s]" % _blips[-1].tier)
	await _close(box)

	# --- system text (no portrait) is silent ----------------------------------
	await _say_line(box, "", "Press X to dash.", Color(0, 0, 0, 0), null)
	_blips.clear()
	_reveal_all(box)
	_check(_blips.is_empty(),
		"system text with no portrait fires no voice blips at all  [%d]" % _blips.size())
	await _close(box)

	# --- switching state changes whose pool is used ---------------------------
	await _say_line(box, "Hooshang", "First, annoyed.", Color(1, 1, 1, 1), ANNOYED)
	_blips.clear()
	_reveal_all(box)
	var first_keys := {}
	for b in _blips:
		first_keys[b.key] = true
	await _close(box)

	await _say_line(box, "Hooshang", "Then, vulnerable.", Color(1, 1, 1, 1), VULNERABLE)
	_blips.clear()
	_reveal_all(box)
	var second_keys := {}
	for b in _blips:
		second_keys[b.key] = true
	await _close(box)
	_check(first_keys.keys() == ["hooshang_annoyed"] and second_keys.keys() == ["hooshang_vulnerable"],
		"a different portrait state uses a different voice pool  [%s then %s]"
			% [first_keys.keys(), second_keys.keys()])

	# --- nothing fires while paused mid-line ----------------------------------
	await _say_line(box, "Hooshang", "Held here, a beat, then more.", Color(1, 1, 1, 1), ANNOYED)
	box._pause_left = 0.3
	_blips.clear()
	for i in 5:  # 5*0.05s = 0.25s, still inside the 0.3s hold every step
		box._process(0.05)
	_check(_blips.is_empty(),
		"no voice blips fire while the reveal is paused mid-line  [%d]" % _blips.size())
	box._pause_left = 0.0
	_reveal_all(box)
	await _close(box)

	# --- nothing fires between pages, waiting on a press ----------------------
	await _say_line(box, "Hooshang", "Waiting for a press.", Color(1, 1, 1, 1), ANNOYED)
	_reveal_all(box)
	_check(not box._revealing, "sanity: the page actually finished revealing")
	_blips.clear()
	for i in 5:
		box._process(1.0 / 60.0)
	_check(_blips.is_empty(),
		"no voice blips fire while a finished page waits on a press  [%d]" % _blips.size())
	await _close(box)

	# --- "emphasized" never fires twice in a row -------------------------------
	#
	# Not a probabilistic check: _voice_new_chars' _last_tier_emphasized guard
	# forbids the adjacency unconditionally, whatever randf() returns. A long
	# line just gives the guard enough picks for the check to mean something.
	await _say_line(box, "Hooshang",
		"A considerably longer line, so that plenty of syllables get a chance to play as this reveals across many characters.",
		Color(1, 1, 1, 1), ANNOYED)
	_blips.clear()
	_reveal_all(box)
	var back_to_back := false
	for i in range(1, _blips.size()):
		if _blips[i].tier == "emphasized" and _blips[i - 1].tier == "emphasized":
			back_to_back = true
	var emphasized_count := 0
	for b in _blips:
		if b.tier == "emphasized":
			emphasized_count += 1
	_check(emphasized_count > 0, "sanity: the long line actually rolled some emphasized picks")
	_check(not back_to_back,
		"...and never two emphasized blips in a row  [%d emphasized of %d]"
			% [emphasized_count, _blips.size()])
	await _close(box)

	# --- a pool never repeats the same clip twice in a row ---------------------
	#
	# Uses a REAL key (rumi_warm_open) with its pool temporarily forced down to
	# 2 entries, rather than a made-up one — partly so the repeat-avoidance
	# check is deterministic (see blip()'s "one retry, deterministic direction"
	# comment: with exactly 2 entries a single retry can never fail to land on
	# the other one), and partly because "warm_open" is the one real state name
	# with an underscore IN it, which exercises key.split(..., 1)'s maxsplit
	# actually mattering — a made-up key like "__test_key__" doesn't have that
	# same shape and, tried first, only proved the test's fake key was wrong,
	# not anything about production code.
	var real_pools: Dictionary = VoiceBlips._manifest["rumi_warm_open"]
	VoiceBlips._manifest["rumi_warm_open"] = {"passing": 2}
	VoiceBlips._last_index.erase("rumi_warm_open/passing")
	_blips.clear()
	for i in 40:
		VoiceBlips.blip("rumi_warm_open", "passing")
	var repeat := false
	for i in range(1, _blips.size()):
		if _blips[i].path == _blips[i - 1].path:
			repeat = true
	_check(_blips.size() == 40 and not repeat,
		"a 2-clip pool never plays the same clip twice in a row  [%d plays, repeat=%s]"
			% [_blips.size(), repeat])
	VoiceBlips._manifest["rumi_warm_open"] = real_pools
	VoiceBlips._last_index.erase("rumi_warm_open/passing")

	if failures.is_empty():
		print("VOICE BLIP TEST: ALL PASS")
	else:
		print("VOICE BLIP TEST: %d FAILURE(S)" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)


func _on_blipped(key: String, tier: String, clip_path: String) -> void:
	_blips.append({"key": key, "tier": tier, "path": clip_path})


## Start a line and wait out its float-in, the same margin
## portrait_anim_test.gd's _say() uses, then make sure the reveal has actually
## started before the caller drives box._process() by hand — say()'s own
## internal SceneTreeTimer can resolve a frame or two after this wait, same
## race that test documents.
func _say_line(box: DialogueBox, speaker: String, text: String, tint: Color,
		face: Texture2D, side: int = DialogueBox.Side.LEFT) -> void:
	box.say(speaker, text, tint, face, side, DialogueBox.VSide.TOP)
	await _frames(int(maxf(box.entrance_time, box.portrait_entrance_time) * 60.0) + 3)
	var guard := 0
	while not box._revealing and guard < 30:
		await _frames(1)
		guard += 1


## Drive the reveal to completion (or a page's pause hold and back out of it)
## with a fixed synthetic delta — no real awaits inside the loop, so nothing
## else's _process can interleave with these calls.
func _reveal_all(box: DialogueBox, max_steps := 4000) -> void:
	var steps := 0
	while box._revealing and steps < max_steps:
		box._process(1.0 / 60.0)
		steps += 1


## Same fire-and-close pattern dialogue_placement_test.gd and
## portrait_anim_test.gd use: loops rather than emitting once, since a line
## can paginate into more than one page.
func _close(box: DialogueBox) -> void:
	while box._active:
		box.line_finished.emit()
		await _frames(3)
	await _frames(int(box.entrance_time * 60.0) + 3)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _check(cond: bool, name: String) -> void:
	print(("  PASS  " if cond else "  FAIL  ") + name)
	if not cond:
		failures.append(name)
