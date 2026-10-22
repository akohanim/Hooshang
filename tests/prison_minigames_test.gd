extends Node
## The prison hub's TV/PC prop and its two arcade games, HOOSHANG 64 and SUPER
## SIMORGH (THE OTHER SIDE has mirror_game_test). Each check is a defect that
## shipped, measured the way it was found:
##   - the TV picture drew game pixels 13 and 14 window pixels wide at x9
##   - text drawn off the 5x7 font's own grid (sizes 8 and 9)
##   HOOSHANG 64
##   - respawning at the checkpoint walked an enemy into him in 1.15s
##   - the stair well needed a run-up jump to climb out of
##   - after the flag he walked away 8px above the grass
##   - the title's footer printed over the ground and the mascot
##   - a game over threw him out of the TV
##   - every sound ended on a click
##   SUPER SIMORGH
##   - nothing said Up runs and Left/Right turns
##   - being consumed threw him out of the PC
##   - the santur and the drone restarted, with a gap, at every loop
##   - the santur ignored MUSIC: OFF
##   - jump and bump stopped mid-ring, a click at the end of every jump
## Games are ticked by hand (set_physics_process off) so a 60s run takes no
## real time; a press is made, ticked once, then held across a frame boundary
## so Input stops reporting it as just pressed.

const DT := 1.0 / 60.0
var failures := 0


func check(ok: bool, label: String) -> void:
	print("  PASS " if ok else "  FAIL ", label)
	if not ok: failures += 1


func _ready() -> void:
	SaveGame.unbind()
	_tv_picture()
	_font_grid()
	await _hooshang_64()
	await _simorgh()
	print("PRISON MINIGAMES: ", failures, " failures")
	get_tree().quit(1 if failures else 0)


func _release_all() -> void:
	for a in ["move_left", "move_right", "move_up", "move_down", "jump", "dash"]:
		Input.action_release(a)


func _tick(game: Node, seconds: float) -> void:
	for i in roundi(seconds / DT): game._physics_process(DT)


## One tick with `action` newly pressed, then it stays held. Input keeps
## reporting a press as "just pressed" until the frame counter has moved on
## twice (one await resumes before it ticks), even once it is released.
func _press(game: Node, action: String) -> void:
	Input.action_press(action)
	game._physics_process(DT)
	await get_tree().process_frame
	await get_tree().process_frame


# ---------------------------------------------------------------- the TV --

func _tv_picture() -> void:
	var whole_everywhere := true
	var centred := true
	for k in range(1, 13):
		var r := RetroTV.picture_rect(k)
		var px := r.size * k / Vector2(RetroGame.W, RetroGame.H)
		if not (is_equal_approx(px.x, roundf(px.x)) and is_equal_approx(px.x, px.y) and px.x >= 1.0):
			whole_everywhere = false
			print("    x%d: a game pixel is %s window pixels" % [k, px])
		var at := r.position * k
		if not (is_equal_approx(at.x, roundf(at.x)) and is_equal_approx(at.y, roundf(at.y))) \
				or not Rect2(Vector2.ZERO, Vector2(Screen.GAME_SIZE)).encloses(r):
			centred = false
	check(whole_everywhere, "TV picture: every game pixel is the same whole number of window pixels at every stretch x1-x12")
	check(centred, "TV picture: on a whole window pixel and inside the 320x180 frame")
	check(is_equal_approx(RetroTV.picture_rect(9).size.x * 9 / RetroGame.W, 13.0), "TV picture at x9 (2880x1800): 13-pixel game pixels, not 13 and 14 by turns")
	check(RetroTV.picture_rect(4) == Rect2(40, 0, 240, 180), "TV picture at x4 (1280x720) is the same 240x180 it always was")


## Every draw_string in the machines and their games is at the 5x7 font's own
## size; bigger text is drawn through an integer draw_set_transform scale.
func _font_grid() -> void:
	var off := []
	var re := RegEx.create_from_string("draw_string\\([^\\n]*HORIZONTAL_ALIGNMENT_LEFT, -1, ([^,]+),")
	for path in ["res://scenes/props/prison/retro_tv.gd", "res://scenes/minigame/retro_game.gd",
			"res://scenes/minigame/simorgh_game.gd", "res://scenes/minigame/mirror_game.gd"]:
		for m in re.search_all(FileAccess.get_file_as_string(path)):
			if m.get_string(1).strip_edges() != "7": off.append("%s: %s" % [path.get_file(), m.get_string(1)])
	check(off.is_empty(), "every string is drawn at the pixel font's own size 7 %s" % [off])


# ---------------------------------------------------------- HOOSHANG 64 --

func _hooshang_64() -> void:
	var g := RetroGame.new()
	add_child(g)
	g.set_physics_process(false)
	g.active = true
	var wins := [0]
	g.finished.connect(func(): wins[0] += 1)

	# Back at the checkpoint, touching nothing.
	g._respawn(92 * RetroGame.T)
	g.mode = RetroGame.Mode.PLAY
	g.checkpoint_x = 92 * RetroGame.T
	var nearest := INF
	for e in g.enemies: if e.pos.x >= 92 * RetroGame.T: nearest = minf(nearest, e.pos.x - 92 * RetroGame.T)
	check(nearest >= RetroGame.SAFE_RESPAWN, "checkpoint respawn: nearest enemy ahead starts %dpx away (was 32)" % nearest)
	_tick(g, 5.0)
	check(g.mode == RetroGame.Mode.PLAY, "checkpoint respawn: still standing 5s later with no input (was killed after 1.15s)")

	# The notch between the end staircases: one held jump, from anywhere in it.
	check(g.tile(156, 10) == 0 and g.tile(156, 11) != 0 and g.tile(157, 10) == 0 and g.tile(157, 11) != 0,
		"the gap between the end staircases is four blocks deep")
	var stuck := []
	for x in range(156 * 8, 157 * 8 + 1, 2):
		for dir in ["move_right", "move_left"]:
			g._respawn(float(x))
			g.enemies.clear()
			g.pos.y = 11 * RetroGame.T - RetroGame.PH
			g.mode = RetroGame.Mode.PLAY
			_tick(g, 0.2)
			Input.action_press(dir)
			await _press(g, "jump")
			_tick(g, 1.2)
			_release_all()
			var in_notch := g.pos.x + RetroGame.PW > 156 * 8 and g.pos.x < 158 * 8 and g.pos.y + RetroGame.PH > 7 * 8
			if in_notch: stuck.append([x, dir])
	check(stuck.is_empty(), "every standing jump out of the notch gets out (stuck: %s)" % [stuck])

	# The flag, and the walk away from it.
	g._respawn(170 * RetroGame.T)
	g.enemies.clear()
	g.mode = RetroGame.Mode.PLAY
	g.pos = Vector2(176 * RetroGame.T - RetroGame.PW + 2.5, 40)
	g.vel = Vector2(60, 0)
	g._physics_process(DT)
	check(g.mode == RetroGame.Mode.CLEAR, "touching the pole clears the course")
	var floating := 0.0
	var walked := 0.0
	var x0 := g.pos.x
	var off_screen := ""
	while g.mode == RetroGame.Mode.CLEAR:
		g._physics_process(DT)
		if g.mode != RetroGame.Mode.CLEAR: break
		# (the first 0.6s of the walk is stepping off the block and the drop)
		if g.mode_t > RetroGame.CLEAR_WALK_FROM + 0.6:
			var c := int(floor((g.pos.x + RetroGame.PW * 0.5) / RetroGame.T))
			var r := int(floor((g.pos.y + RetroGame.PH) / RetroGame.T))
			if not (g.on_ground and g.tile(c, r) in RetroGame.SOLID): floating += DT
		walked = g.pos.x - x0
		var on_screen := g.pos.x - g.cam_x
		if on_screen < 0 or on_screen > RetroGame.W - RetroGame.PW: off_screen = "(off screen at x %.0f)" % on_screen
	check(floating == 0.0, "after the flag he walks on the ground (%.2fs in the air, was the whole walk at 8px up)" % floating)
	check(walked > 60.0 and off_screen == "", "and walks well clear of the pole without leaving the screen %s" % off_screen)
	check(wins[0] == 1, "a cleared course finishes the game once")

	# Game over: back to the title, not out of the TV.
	g._reset_run()
	g.mode = RetroGame.Mode.PLAY
	g.lives = 1
	g._die()
	_tick(g, 2.1)
	check(g.mode == RetroGame.Mode.GAME_OVER, "the last life lost is GAME OVER")
	_tick(g, 3.1)
	check(g.mode == RetroGame.Mode.TITLE and wins[0] == 1, "GAME OVER goes back to the title and does not end the session")
	_tick(g, 0.4)
	await _press(g, "jump")
	_release_all()
	check(g.mode == RetroGame.Mode.PLAY and g.lives == 3, "and Jump starts a fresh game from there")

	# Title layout.
	var ground := 13 * RetroGame.T
	var foot_w := RetroGame.FONT.get_string_size(g.title_footer(), HORIZONTAL_ALIGNMENT_LEFT, -1, 7).x
	var footer := Rect2((RetroGame.W - foot_w) * 0.5, RetroGame.TITLE_FOOTER_Y - 7, foot_w, 7)
	check(RetroGame.TITLE_KID.end.y == ground, "the title's little Hooshang stands on the ground (was 7px into it)")
	check(not footer.intersects(RetroGame.TITLE_KID) and footer.position.y >= ground and footer.end.y <= RetroGame.H,
		"the title footer sits on the dirt clear of him")

	# Every cue ends at silence.
	var loud := []
	for name in g._sounds:
		var data: PackedByteArray = g._sounds[name].data
		var last := data[data.size() - 1]
		if last > 127: last -= 256
		if absi(last) > 1: loud.append("%s ends at %d/127" % [name, last])
	check(loud.is_empty(), "every HOOSHANG 64 sound ends at silence (each stopped at 28/127) %s" % [loud])
	g.queue_free()
	await get_tree().process_frame


# --------------------------------------------------------- SUPER SIMORGH --

func _simorgh() -> void:
	var g := SimorghGame.new()
	add_child(g)
	g.set_physics_process(false)
	var was_music := Settings.music_enabled
	Settings.music_enabled = false
	g.activate()
	check(not g._music.playing, "MUSIC: OFF keeps the santur silent")
	g.deactivate()
	Settings.music_enabled = true
	g.activate()
	check(g._music.playing, "MUSIC: ON plays it")
	Settings.music_enabled = was_music

	for p: AudioStreamPlayer in [g._music, g._drone]:
		var wav := p.stream as AudioStreamWAV
		check(wav.loop_mode == AudioStreamWAV.LOOP_FORWARD and wav.loop_begin == 0
			and wav.loop_end == roundi(wav.get_length() * wav.mix_rate),
			"%s loops in the stream, end to start (was restarted on finished)" % ["music" if p == g._music else "drone"])

	var lines := g.title_controls()
	var says_turn := false
	var fits := true
	for line in lines:
		if line.contains("UP") and line.contains("TURN"): says_turn = true
		if SimorghGame.FONT.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 7).x > SimorghGame.W - 4: fits = false
	check(says_turn, "the title says Up runs and Left/Right turns")
	check(fits, "and both control lines fit the screen")

	var wins := [0]
	g.finished.connect(func(): wins[0] += 1)
	_tick(g, 0.5)
	await _press(g, "jump")
	_release_all()
	check(g.mode == SimorghGame.Mode.INTRO, "Jump on the title starts the run")
	_tick(g, SimorghGame.INTRO_TIME + 0.1)
	check(g.mode == SimorghGame.Mode.PLAY and g.needs_go_prompt(), "the chase opens with the hold-Up prompt")
	Input.action_press("move_up")
	_tick(g, 1.0)
	_release_all()
	check(not g.needs_go_prompt(), "and it goes once he is running")
	while g.mode == SimorghGame.Mode.PLAY: g._physics_process(DT)
	check(g.mode == SimorghGame.Mode.CAUGHT, "standing still, he is consumed")
	_tick(g, SimorghGame.SKIP_END + 0.1)
	await _press(g, "jump")
	_release_all()
	check(g.mode == SimorghGame.Mode.TITLE and wins[0] == 0,
		"consumed: Jump goes back to the title, still in the PC (it used to end the session)")
	_tick(g, 0.5)
	await _press(g, "jump")
	_release_all()
	check(g.mode == SimorghGame.Mode.INTRO, "and straight into another run")
	_tick(g, SimorghGame.INTRO_TIME + 0.1)
	while g.mode == SimorghGame.Mode.PLAY: g._physics_process(DT)
	_tick(g, 6.1)
	check(g.mode == SimorghGame.Mode.TITLE and wins[0] == 0, "left alone, the CONSUMED card also ends on the title")
	g._start_run()
	_tick(g, SimorghGame.INTRO_TIME + 0.1)
	g.pos.x = g.door_x - 0.5
	g._physics_process(DT)
	check(g.mode == SimorghGame.Mode.ESCAPED, "reaching the light escapes")
	_tick(g, 6.1)
	check(wins[0] == 1, "and escaping is what finishes the game")
	g.deactivate()
	g.queue_free()
	await get_tree().process_frame

	# The one-shots, as tools/gen_simorgh_audio.py writes them (the source
	# WAVs; the import compresses them).
	var clicks := []
	for name in ["coin", "jump", "bump", "hit", "portal", "valley", "stinger", "shriek", "whisper", "heartbeat"]:
		var tail := _wav_tail("res://assets/minigame/simorgh/%s.wav" % name, 44)
		if tail > 0.01: clicks.append("%s ends at %.3f" % [name, tail])
	check(clicks.is_empty(), "every SUPER SIMORGH cue fades out (jump stopped at 0.108, bump 0.087) %s" % [clicks])


## The loudest of a 16-bit mono WAV's last `n` samples, 0..1.
func _wav_tail(path: String, n: int) -> float:
	var bytes := FileAccess.get_file_as_bytes(path)
	var at := 12
	while at + 8 <= bytes.size():
		var size := bytes.decode_u32(at + 4)
		if bytes.slice(at, at + 4).get_string_from_ascii() == "data":
			var end := at + 8 + size
			var loud := 0.0
			for k in range(end - 2 * n, end, 2): loud = maxf(loud, absf(bytes.decode_s16(k) / 32768.0))
			return loud
		at += 8 + size + (size & 1)
	return 1.0
