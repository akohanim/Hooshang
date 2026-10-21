class_name RetroGame
extends Node2D
## "HOOSHANG 64" — the game on the old TV in the prison hub (RetroTV).
##
## A complete little retro side-scroller drawn at 160x120 inside the TV's own
## SubViewport: little Hooshang runs, jumps (higher the longer jump is held),
## runs faster with dash held, bumps star blocks for coins, stomps dust bunnies,
## and reaches the goal flag. Original art (tools/gen_retro_tv.py) and
## synthesised square-wave blips; it borrows the FEEL of an old console
## platformer, nothing else.
##
## While `active` is false it sits on its title screen — that is what the TV
## shows from across the room. RetroTV turns it on and listens for `exit_requested`
## (pause pressed) and `finished` (course clear or game over).

signal exit_requested
signal finished

const W := 160
const H := 120
const T := 8
const ROWS := 15
const COLS := 190
const SHEET := preload("res://assets/minigame/retro_sheet.png")
const FONT := preload("res://assets/fonts/pixel5x7.fnt")
const SKY := Color8(96, 152, 248)

# Tiles: 0 air, 1 ground, 2 brick, 3 star block, 5 used block, 9/10 chimney top,
# 11/12 chimney body, 13 hard block.
const SOLID := [1, 2, 3, 5, 9, 10, 11, 12, 13]

# Player tuning, px and px/s.
const GRAVITY_HELD := 700.0
const GRAVITY := 1400.0
const JUMP_SPEED := 255.0
const WALK := 62.0
const RUN := 105.0
const ACCEL := 330.0
const DECEL := 420.0
const MAX_FALL := 300.0
const PW := 8.0
const PH := 14.0

enum Mode { TITLE, PLAY, DYING, CLEAR, GAME_OVER }

var active := false
var mode := Mode.TITLE
var tiles: PackedByteArray
var coins_at := {}          # Vector2i -> true
var enemies: Array = []     # {pos, vel, alive, squash, start}
var popups: Array = []      # {pos, t, kind}
var bumps := {}             # Vector2i -> time left
var pos := Vector2.ZERO
var vel := Vector2.ZERO
var on_ground := false
var facing := 1
var cam_x := 0.0
var lives := 3
var coins := 0
var score := 0
var time_left := 300.0
var checkpoint_x := 24.0
var mode_t := 0.0
var anim_t := 0.0
var coyote := 0.0
var jump_buffer := 0.0
var _player: AudioStreamPlayer
var _sounds := {}
var _flag_col := 0


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.volume_db = -14.0
	add_child(_player)
	_make_sounds()
	_build_level()
	_reset_run()


# -------------------------------------------------------------- the level --

func _put(c: int, r: int, v: int) -> void:
	if c >= 0 and c < COLS and r >= 0 and r < ROWS: tiles[r * COLS + c] = v


func tile(c: int, r: int) -> int:
	if c < 0 or c >= COLS: return 13
	if r < 0: return 0
	if r >= ROWS: return 0
	return tiles[r * COLS + c]


func _build_level() -> void:
	tiles = PackedByteArray(); tiles.resize(ROWS * COLS)
	coins_at.clear()
	var pits := [[31, 32], [63, 65], [105, 107], [142, 144]]
	for c in COLS:
		var pit := false
		for p in pits: pit = pit or (c >= p[0] and c <= p[1])
		if not pit:
			_put(c, 13, 1); _put(c, 14, 1)
	# Star blocks and bricks.
	for c in [12, 50, 78, 98, 125]: _put(c, 9, 3)
	for c in [14, 15, 16]: _put(c, 9, 2 if c != 15 else 3)
	_put(15, 5, 3)
	for c in range(70, 77): _put(c, 9, 2 if c % 2 == 0 else 3)
	for c in range(72, 75): _put(c, 5, 2)
	_put(73, 5, 3)
	for c in range(112, 118): _put(c, 8, 2)
	_put(114, 8, 3)
	# Chimneys: column, height.
	for spec in [[22, 2], [40, 3], [53, 4], [90, 2], [132, 3]]:
		var c: int = spec[0]
		for k in spec[1]:
			var r: int = 12 - k
			_put(c, r, 11); _put(c + 1, r, 12)
		_put(c, 12 - spec[1], 9); _put(c + 1, 12 - spec[1], 10)
	# A staircase up to the goal, a gap, and the flag.
	for k in 6:
		for h in k + 1: _put(150 + k, 12 - h, 13)
	for k in 6:
		for h in 6 - k: _put(158 + k, 12 - h, 13)
	_flag_col = 176
	_put(_flag_col, 12, 13)
	# Coins.
	for c in [26, 27, 28, 35, 36, 64, 65, 106, 143]: coins_at[Vector2i(c, 8)] = true
	for c in range(84, 89): coins_at[Vector2i(c, 6)] = true
	for c in range(118, 122): coins_at[Vector2i(c, 10)] = true


func _spawn_enemies() -> void:
	enemies.clear()
	for c in [28, 36, 46, 48, 58, 80, 83, 96, 110, 122, 136, 147]:
		enemies.append({"pos": Vector2(c * T, 13 * T - 10), "vel": Vector2(-22, 0), "alive": true, "squash": 0.0, "awake": false})


func _reset_run() -> void:
	lives = 3; coins = 0; score = 0
	_build_level()
	_respawn(24.0)


func _respawn(x: float) -> void:
	pos = Vector2(x, 13 * T - PH)
	vel = Vector2.ZERO
	facing = 1
	time_left = 300.0
	popups.clear(); bumps.clear()
	_spawn_enemies()
	cam_x = clampf(pos.x - 60.0, 0.0, COLS * T - W)


# ------------------------------------------------------------- lifecycle --

func activate() -> void:
	active = true
	mode = Mode.TITLE
	mode_t = 0.0


func deactivate() -> void:
	active = false
	mode = Mode.TITLE
	_reset_run()


func _start_play() -> void:
	_reset_run()
	checkpoint_x = 24.0
	mode = Mode.PLAY
	mode_t = 0.0
	_play(&"coin")


# --------------------------------------------------------------- update --

func _physics_process(delta: float) -> void:
	anim_t += delta
	mode_t += delta
	for k in bumps.keys():
		bumps[k] -= delta
		if bumps[k] <= 0.0: bumps.erase(k)
	for p in popups: p.t += delta
	popups = popups.filter(func(p): return p.t < 0.6)
	if active and Input.is_action_just_pressed("pause"):
		exit_requested.emit()
		return
	match mode:
		Mode.TITLE:
			if active and (Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("move_up")) and mode_t > 0.3:
				_start_play()
		Mode.PLAY:
			_tick_play(delta)
		Mode.DYING:
			vel.y = minf(vel.y + GRAVITY * delta, MAX_FALL)
			pos.y += vel.y * delta
			if mode_t > 2.0:
				lives -= 1
				if lives <= 0:
					mode = Mode.GAME_OVER; mode_t = 0.0
				else:
					_respawn(checkpoint_x); mode = Mode.PLAY; mode_t = 0.0
		Mode.CLEAR:
			if pos.y < 12 * T - PH:
				pos.y = minf(pos.y + 60.0 * delta, 12 * T - PH)
			elif mode_t > 1.2:
				pos.x += 40.0 * delta
			if mode_t > 1.0 and time_left > 0.0:
				var d := minf(time_left, 120.0 * delta)
				time_left -= d; score += int(d * 10.0)
			if mode_t > 4.5:
				finished.emit()
				mode = Mode.TITLE; mode_t = 0.0
		Mode.GAME_OVER:
			if mode_t > 3.0:
				finished.emit()
				mode = Mode.TITLE; mode_t = 0.0
	queue_redraw()


func _tick_play(delta: float) -> void:
	time_left -= delta
	if time_left <= 0.0:
		_die(); return
	var input := 0.0
	if Input.is_action_pressed("move_left"): input -= 1.0
	if Input.is_action_pressed("move_right"): input += 1.0
	var top := RUN if Input.is_action_pressed("dash") else WALK
	if input != 0.0:
		facing = int(signf(input))
		var rate := ACCEL if signf(vel.x) == signf(input) or vel.x == 0.0 else DECEL * 1.6
		vel.x = move_toward(vel.x, input * top, rate * delta)
	else:
		vel.x = move_toward(vel.x, 0.0, DECEL * delta)
	coyote = 0.08 if on_ground else maxf(coyote - delta, 0.0)
	jump_buffer = 0.1 if Input.is_action_just_pressed("jump") else maxf(jump_buffer - delta, 0.0)
	if jump_buffer > 0.0 and coyote > 0.0:
		vel.y = -JUMP_SPEED - absf(vel.x) * 0.25
		jump_buffer = 0.0; coyote = 0.0; on_ground = false
		_play(&"jump")
	var g := GRAVITY_HELD if vel.y < 0.0 and Input.is_action_pressed("jump") else GRAVITY
	vel.y = minf(vel.y + g * delta, MAX_FALL)
	_move_x(vel.x * delta)
	_move_y(vel.y * delta)
	pos.x = maxf(pos.x, cam_x)  # the old screen-edge wall
	# Coins.
	for c in range(int(pos.x / T), int((pos.x + PW) / T) + 1):
		for r in range(int(pos.y / T), int((pos.y + PH) / T) + 1):
			if coins_at.has(Vector2i(c, r)):
				coins_at.erase(Vector2i(c, r)); _coin(Vector2(c * T, r * T))
	if pos.x > 92 * T: checkpoint_x = maxf(checkpoint_x, 92 * T)
	if pos.y > H + 16: _die(); return
	_tick_enemies(delta)
	if pos.x + PW >= _flag_col * T + 3:
		mode = Mode.CLEAR; mode_t = 0.0
		score += 5000; vel = Vector2.ZERO
		pos.x = _flag_col * T + 4 - PW
		_play(&"clear")
	cam_x = clampf(maxf(cam_x, pos.x - 70.0), 0.0, COLS * T - W)


func _move_x(dx: float) -> void:
	pos.x += dx
	var r0 := int(floor(pos.y / T)); var r1 := int(floor((pos.y + PH - 0.01) / T))
	if dx > 0.0:
		var c := int(floor((pos.x + PW) / T))
		for r in range(r0, r1 + 1):
			if tile(c, r) in SOLID:
				pos.x = c * T - PW; vel.x = 0.0; return
	elif dx < 0.0:
		var c := int(floor(pos.x / T))
		for r in range(r0, r1 + 1):
			if tile(c, r) in SOLID:
				pos.x = (c + 1) * T; vel.x = 0.0; return


func _move_y(dy: float) -> void:
	pos.y += dy
	on_ground = false
	var c0 := int(floor(pos.x / T)); var c1 := int(floor((pos.x + PW - 0.01) / T))
	if dy > 0.0:
		var r := int(floor((pos.y + PH) / T))
		for c in range(c0, c1 + 1):
			if tile(c, r) in SOLID:
				pos.y = r * T - PH; vel.y = 0.0; on_ground = true; return
	elif dy < 0.0:
		var r := int(floor(pos.y / T))
		# Bump the block nearest his middle, the way it feels on the old ones.
		var mid := int(floor((pos.x + PW * 0.5) / T))
		var hit := -999
		for c in [mid, c0, c1]:
			if tile(c, r) in SOLID: hit = c; break
		if hit != -999:
			pos.y = (r + 1) * T; vel.y = 0.0
			_bump(hit, r)


func _bump(c: int, r: int) -> void:
	var t := tile(c, r)
	if t == 3:
		_put(c, r, 5)
		_coin(Vector2(c * T, (r - 1) * T))
		bumps[Vector2i(c, r)] = 0.15
	elif t == 2:
		bumps[Vector2i(c, r)] = 0.15
		_play(&"bump")
		# Anything standing on a bumped block gets knocked out.
		for e in enemies:
			if e.alive and absf(e.pos.x + 5 - (c * T + 4)) < 8 and absf(e.pos.y + 10 - r * T) < 3:
				e.alive = false; e.squash = 0.5; score += 100
	else:
		_play(&"bump")


func _coin(at: Vector2) -> void:
	coins += 1; score += 200
	if coins >= 100: coins -= 100; lives += 1
	popups.append({"pos": at, "t": 0.0, "kind": "coin"})
	_play(&"coin")


func _tick_enemies(delta: float) -> void:
	for e in enemies:
		if not e.alive:
			e.squash -= delta
			continue
		if not e.awake:
			if e.pos.x < cam_x + W + 16: e.awake = true
			else: continue
		e.vel.y = minf(e.vel.y + GRAVITY * delta, MAX_FALL)
		var nx: float = e.pos.x + e.vel.x * delta
		var probe: float = nx if e.vel.x < 0.0 else nx + 10.0
		var rmid := int(floor((e.pos.y + 5.0) / T))
		if tile(int(floor(probe / T)), rmid) in SOLID: e.vel.x = -e.vel.x
		else: e.pos.x = nx
		e.pos.y += e.vel.y * delta
		var rb := int(floor((e.pos.y + 10.0) / T))
		if tile(int(floor((e.pos.x + 5.0) / T)), rb) in SOLID:
			e.pos.y = rb * T - 10.0; e.vel.y = 0.0
		if e.pos.y > H + 20: e.alive = false; e.squash = 0.0
		# Contact with Hooshang.
		var me := Rect2(pos, Vector2(PW, PH)); var it := Rect2(e.pos + Vector2(1, 2), Vector2(8, 8))
		if me.intersects(it):
			if vel.y > 0.0 and pos.y + PH - it.position.y < 9.0:
				e.alive = false; e.squash = 0.5; score += 100
				vel.y = -JUMP_SPEED * 0.6
				popups.append({"pos": e.pos, "t": 0.0, "kind": "100"})
				_play(&"stomp")
			else:
				_die(); return


func _die() -> void:
	if mode != Mode.PLAY: return
	mode = Mode.DYING; mode_t = 0.0
	vel = Vector2(0, -260.0)
	_play(&"die")


# ----------------------------------------------------------------- draw --

func _draw() -> void:
	draw_rect(Rect2(0, 0, W, H), SKY)
	var cx := roundf(cam_x)
	_draw_scenery(cx)
	var c0 := int(cx / T)
	for r in ROWS:
		for c in range(c0, c0 + W / T + 2):
			var t := tile(c, r)
			if t == 0: continue
			var src := t
			if t == 1 and tile(c, r - 1) != 1: src = 0  # ground top
			elif t == 1: src = 1
			elif t == 3: src = 4 if int(anim_t * 3.0) % 3 == 2 else 3
			var lift := -2.0 if bumps.has(Vector2i(c, r)) else 0.0
			draw_texture_rect_region(SHEET, Rect2(c * T - cx, r * T + lift, T, T), Rect2(src * T, 0, T, T))
	for k in coins_at:
		var f := int(anim_t * 6.0) % 4
		var src_x: int = [48, 56, 64, 56][f]
		draw_texture_rect_region(SHEET, Rect2(k.x * T - cx, k.y * T, T, T), Rect2(src_x, 0, T, T))
	_draw_flag(cx)
	for e in enemies:
		if not e.alive and e.squash <= 0.0: continue
		if not e.awake and e.alive: continue
		var frame := 2 if not e.alive else int(anim_t * 5.0) % 2
		draw_texture_rect_region(SHEET, Rect2(roundf(e.pos.x) - cx - 1, roundf(e.pos.y) - 2, 12, 12), Rect2(frame * 12, 32, 12, 12))
	for p in popups:
		var y: float = p.pos.y - p.t * 30.0
		if p.kind == "coin":
			draw_texture_rect_region(SHEET, Rect2(p.pos.x - cx, y, T, T), Rect2(48, 0, T, T))
		else:
			draw_string(FONT, Vector2(p.pos.x - cx, y), "100", HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color.WHITE)
	if mode in [Mode.PLAY, Mode.DYING, Mode.CLEAR]:
		var frame := 0
		if mode == Mode.DYING: frame = 4
		elif mode == Mode.CLEAR: frame = 5 if pos.y >= 12 * T - PH and mode_t > 4.0 else 3
		elif not on_ground: frame = 3
		elif absf(vel.x) > 5.0: frame = 1 + int(anim_t * (10.0 if absf(vel.x) > 80.0 else 7.0)) % 2
		draw_set_transform(Vector2(roundf(pos.x) - cx + PW * 0.5, roundf(pos.y) + PH - 16), 0.0, Vector2(facing if frame != 4 else 1, 1))
		draw_texture_rect_region(SHEET, Rect2(-6, 0, 12, 16), Rect2(frame * 12, 16, 12, 16))
		draw_set_transform(Vector2.ZERO)
	_draw_hud()
	match mode:
		Mode.TITLE: _draw_title()
		Mode.GAME_OVER: _banner("GAME OVER")
		Mode.CLEAR:
			if mode_t > 1.0: _banner("COURSE CLEAR!")


func _draw_scenery(cx: float) -> void:
	# Far hills and clouds, half-speed parallax, pixel-crisp circles.
	for i in range(-1, 12):
		var hx := fposmod(i * 70.0 - cx * 0.5, 840.0) - 60.0
		draw_circle(Vector2(hx, 104), 22.0, Color8(56, 168, 88), true, -1.0, false)
		draw_circle(Vector2(hx + 30, 104), 14.0, Color8(40, 136, 72), true, -1.0, false)
		var cx2 := fposmod(i * 90.0 + 20.0 - cx * 0.3, 1080.0) - 60.0
		var cy := 18.0 + float(i % 3) * 10.0
		for k in 3:
			draw_circle(Vector2(cx2 + k * 7, cy - (3.0 if k == 1 else 0.0)), 6.0, Color(1, 1, 1), true, -1.0, false)


func _draw_flag(cx: float) -> void:
	var x := _flag_col * T - cx + 3
	draw_rect(Rect2(x, 2 * T, 2, 10 * T), Color8(200, 200, 208))
	draw_circle(Vector2(x + 1, 2 * T - 1), 2.0, Color8(252, 200, 56), true, -1.0, false)
	var fy := 2 * T + 2.0
	if mode == Mode.CLEAR: fy = minf(2 * T + 2.0 + mode_t * 50.0, 11 * T)
	draw_rect(Rect2(x - 10, fy, 10, 7), Color8(48, 168, 152))
	draw_rect(Rect2(x - 7, fy + 2, 3, 3), Color.WHITE)


func _draw_hud() -> void:
	var c := Color(1, 1, 1)
	# Little Hooshang's head for lives, a coin for coins, then score and time.
	draw_texture_rect_region(SHEET, Rect2(3, 2, 10, 7), Rect2(1, 16, 10, 7))
	draw_string(FONT, Vector2(14, 9), "x%d" % lives, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, c)
	draw_texture_rect_region(SHEET, Rect2(36, 2, T, T), Rect2(48, 0, T, T))
	draw_string(FONT, Vector2(45, 9), "x%02d" % coins, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, c)
	draw_string(FONT, Vector2(76, 9), "%06d" % score, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, c)
	draw_string(FONT, Vector2(126, 9), "T%03d" % int(ceil(time_left)), HORIZONTAL_ALIGNMENT_LEFT, -1, 7, c)


func _draw_title() -> void:
	draw_rect(Rect2(18, 26, 124, 44), Color8(216, 48, 40))
	draw_rect(Rect2(20, 28, 120, 40), Color8(152, 28, 28))
	draw_rect(Rect2(18, 26, 124, 2), Color8(252, 200, 56))
	draw_rect(Rect2(18, 68, 124, 2), Color8(252, 200, 56))
	_text_center("HOOSHANG", 44, Color8(252, 252, 248), 2)
	_text_center("- 64 -", 62, Color8(252, 200, 56), 1)
	if int(mode_t * 2.0) % 2 == 0:
		_text_center("PRESS JUMP" if active else "INSERT KID", 88, Color.WHITE, 1)
	_text_center("(C) 1996  ESC TO LEAVE" if active else "", 108, Color8(200, 220, 255), 1)
	draw_texture_rect_region(SHEET, Rect2(74, 98 - 16 + 13, 12, 16), Rect2(12 * (int(anim_t * 4.0) % 2), 16, 12, 16))


func _banner(text: String) -> void:
	draw_rect(Rect2(0, 50, W, 18), Color(0, 0, 0, 0.6))
	_text_center(text, 63, Color.WHITE, 1)


func _text_center(text: String, y: float, color: Color, scale: int) -> void:
	var size := FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 7) * scale
	draw_set_transform(Vector2(roundf((W - size.x) * 0.5), y), 0.0, Vector2(scale, scale))
	draw_string(FONT, Vector2.ZERO, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, color)
	draw_set_transform(Vector2.ZERO)


# ---------------------------------------------------------------- sound --

func _play(name: StringName) -> void:
	if not active or not _sounds.has(name): return
	_player.stream = _sounds[name]
	_player.play()


## Square-wave blips, built once: [frequency Hz, seconds] steps per cue.
func _make_sounds() -> void:
	var cues := {
		&"jump": [[330, 0.03], [440, 0.03], [587, 0.05]],
		&"coin": [[988, 0.06], [1319, 0.18]],
		&"stomp": [[220, 0.04], [147, 0.06]],
		&"bump": [[110, 0.06]],
		&"die": [[494, 0.1], [440, 0.1], [392, 0.1], [262, 0.3]],
		&"clear": [[523, 0.1], [659, 0.1], [784, 0.1], [1047, 0.35]],
	}
	for name in cues:
		var rate := 22050
		var data := PackedByteArray()
		for step in cues[name]:
			var n := int(rate * float(step[1]))
			var period := maxf(rate / float(step[0]), 2.0)
			for i in n:
				var fade := 1.0 - float(i) / n * 0.6
				var v := (1.0 if fmod(i, period) < period * 0.5 else -1.0) * fade
				data.append(int(128 + v * 70) & 0xff)
		var wav := AudioStreamWAV.new()
		wav.format = AudioStreamWAV.FORMAT_8_BITS
		wav.mix_rate = rate
		wav.stereo = false
		# 8-bit WAV data is signed in Godot.
		for i in data.size(): data[i] = (data[i] - 128) & 0xff
		wav.data = data
		_sounds[name] = wav
