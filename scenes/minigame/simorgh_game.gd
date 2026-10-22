class_name SimorghGame
extends Node2D
## "SUPER SIMORGH" — the game on the old PC in the prison hub (a RetroTV set
## up with the PC art; see PrisonWorld._add_minigames). It looks like a bright,
## psychedelic first-person platformer through a Persian tiled corridor — run,
## jump the pits and stairs, gather the little lights. It OPENS in third
## person: the camera faces Hooshang, breathing, in the bright corridor, and
## far behind him DARKSHANG flickers in — a cloud, then Hooshang's own shape,
## and back — the colour already draining round him. Hooshang turns to look,
## turns to run, and the camera swings round him and into his eyes: from
## there it is first person, and he is behind you.
##
## One minute, no more. He follows down the corridor, swelling and changing
## shape (a cloud, then Hooshang's own silhouette, and back), and the dark
## spreads ahead of him: black veins through the tiles, the colour draining
## out of everything, the sky dying to an eclipse, the fog closing in, the
## mihrab niches opening into eyes, his tendrils creeping in from the edges of
## the screen as he gains. Reach the light at the end of the corridor and you
## escape — for now. Fall behind, or let the minute run out, and he consumes
## you. Lights push him back a little; a star block's burst pushes him further.
## Falling into a pit costs you a second in the dark, and he does not wait.
##
## The picture is ALL shader (simorgh.gdshader); this script owns the course (a
## heightfield grid, uploaded as a texture), the physics, the chase and the
## scares. Same contract as RetroGame: 160x120, `activate()`/`deactivate()`,
## `exit_requested` (pause) and `finished` (escaped). Being consumed goes back
## to the title rather than out of the PC, so another run is one press of Jump.
## While idle it shows the bright title — with a frame of something else now
## and then.
##
## It is not a side-scroller, and the controls have to say so: Up runs down
## the corridor and Left/Right TURN. Read as Mario, holding Right spins him to
## face the wall while Darkshang closes; the title says it, and the run itself
## says "hold Up" until he has made a start.
##
## Sound: tools/gen_simorgh_audio.py (santur music; heartbeat, drone, whisper,
## stinger and shriek for him).

signal exit_requested
signal finished

const W := 160
const H := 120
const MW := 160             # course grid, cells (simorgh.gdshader's MAP)
const MH := 8               # lanes 1-5 are the corridor; 0, 6, 7 are wall
const FONT := preload("res://assets/fonts/pixel5x7.fnt")
const SHADER := preload("res://scenes/minigame/simorgh.gdshader")
const DARKSHANG_SHEET := preload("res://assets/characters/darkshang/darkshang.png")
const HOOSHANG_SHEET := preload("res://assets/minigame/simorgh/hooshang_sheet.png")
const AUDIO := "res://assets/minigame/simorgh/"

# Materials, as simorgh.gdshader's surface() reads them.
enum { M_ABYSS, M_KASHI, M_NICHE, M_BANNAI, M_GROUND, M_STAR, M_USED, M_BRICK, M_PIPE, M_HARD, M_PAVILION, M_DOOR }

# The run.
const RUN_TIME := 60.0      # one minute, then he has you whatever happens
const INTRO_TIME := 4.8     # the third-person opening; the chase starts after it
const START_X := 14.5       # where he stands: room behind him for Darkshang to appear in
const COURSE_SEED := 9277
const COURSE_LENGTH := 115  # cells of obstacles before the light
const LEVEL := 3            # how hard the builders make pits and stairs
const START_GAP := 8.0      # how far behind you he is when the chase starts
const SPEED_FROM := 2.7     # his pace when he arrives, cells/s (you walk 3.0)
const SPEED_TO := 4.3       # ...and at the end of the minute (you run 4.6)
const LEASH := 6.0          # past this gap he closes faster: he stays close
const LIGHT_PUSH := 1.2     # a light pushes him back this many cells
const BURST_PUSH := 3.0     # a star block's burst
const FALL_TIME := 1.0      # seconds in the dark after falling into a pit
const SKIP_END := 3.6       # Jump skips the CONSUMED card after this long
const STARTED := 1.5        # cells down the corridor before the "hold Up" prompt goes

const WALL_H := 3.0
const PIT_H := -6.0
# Body and feel, in cells and cells/s.
const EYE := 0.55
const BODY := 0.7
const RADIUS := 0.2
const STEP := 0.06
const WALK := 3.0
const RUN := 4.6
const ACCEL := 22.0
const AIR_ACCEL := 9.0
const TURN_SPEED := 2.5
const GRAVITY := 20.0
const GRAVITY_HELD := 11.0  # while rising with jump held: the Mario hold
const JUMP := 6.3
const JUMP_RUN_BONUS := 0.12
const MAX_FALL := 14.0
const COYOTE := 0.1
const BUFFER := 0.12
const MAX_SPRITES := 12

enum Mode { TITLE, INTRO, PLAY, FALLING, CAUGHT, ESCAPED }

var active := false
var mode := Mode.TITLE
var mode_t := 0.0
var clock := 0.0
var run_t := 0.0
# The course: ground height, floating block bottom/top, materials, per cell.
var hg := PackedFloat32Array()
var sb := PackedFloat32Array()
var st := PackedFloat32Array()
var gm := PackedByteArray()
var sm := PackedByteArray()
var coin_list: Array[Vector3] = []
var pops: Array = []               # {x, y, z, t, kind, vx, vy, vz}
var door_x := 0.0
# The player.
var pos := Vector2(2.5, 3.5)
var feet := 0.0
var vel := Vector2.ZERO
var vz := 0.0
var angle := 0.0
var on_ground := true
var coyote := 0.0
var buffer := 0.0
var view_z := EYE
var walk_phase := 0.0
var safe_pos := Vector2(2.5, 3.5)
var safe_feet := 0.0
var lights := 0
# Him.
var arrived := false
var dark_x := -100.0
var darkness := 0.0
var prox := 0.0
var morph := 0.0
var scare_t := 0.0
var flicker_t := 0.0
var look_cooldown := 0.0
var heart_t := 0.0
var glitch_t := 0.0
# The camera, which is Hooshang's eyes except in the opening.
var view_pos := Vector2(2.5, 3.5)
var view_angle := 0.0
# Hooshang as seen in the opening: which way he faces, and whether he is shown.
var hoo_face := 0.0
var hoo_shown := false
var hoo_cell := Vector2i.ZERO
var hoo_flip := false
var flash := 0.0
var flash_color := Color(1.0, 0.25, 0.3)
var _rng := RandomNumberGenerator.new()
var _fx := RandomNumberGenerator.new()
var _map_img: Image
var _map_tex: ImageTexture
var _mat: ShaderMaterial
var _hud: Hud
var _music: AudioStreamPlayer
var _drone: AudioStreamPlayer
var _heart: AudioStreamPlayer
var _sfx: AudioStreamPlayer
var _voice: AudioStreamPlayer
var _sounds := {}


class Hud extends Node2D:
	var game: SimorghGame
	func _draw() -> void:
		game._draw_hud(self)


func _ready() -> void:
	_map_img = Image.create(MW, MH, false, Image.FORMAT_RGBA8)
	_map_tex = ImageTexture.create_from_image(_map_img)
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_mat.set_shader_parameter("map_tex", _map_tex)
	_mat.set_shader_parameter("ds_tex", DARKSHANG_SHEET)
	_mat.set_shader_parameter("hoo_tex", HOOSHANG_SHEET)
	var view := ColorRect.new()
	view.size = Vector2(W, H)
	view.material = _mat
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(view)
	_hud = Hud.new()
	_hud.game = self
	add_child(_hud)
	_music = _player(-9.0)
	_drone = _player(-40.0)
	_heart = _player(-20.0)
	_sfx = _player(-6.0)
	_voice = _player(-4.0)
	for n in ["music", "coin", "jump", "bump", "hit", "portal", "valley",
			"heartbeat", "drone", "whisper", "stinger", "shriek"]:
		var path: String = AUDIO + n + ".wav"
		if ResourceLoader.exists(path): _sounds[n] = load(path)
	_music.stream = _looped(_sounds.get("music"))
	_drone.stream = _looped(_sounds.get("drone"))
	_heart.stream = _sounds.get("heartbeat")
	_fx.randomize()
	_to_title()


## The santur and the drone are written as seamless loops (gen_simorgh_audio.py
## mixes them circularly), so they loop in the stream. Restarting them on
## `finished` left a gap at every seam — six times in the music over a run.
func _looped(stream: AudioStream) -> AudioStream:
	var wav := stream as AudioStreamWAV
	if wav == null: return stream
	wav = wav.duplicate()
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = roundi(wav.get_length() * wav.mix_rate)
	return wav


## The santur is music, so the pause menu's MUSIC: OFF silences it too. The
## drone, the heartbeat and the rest are him, and stay.
func _start_music() -> void:
	if active and _music.stream and Settings.music_enabled and not _music.playing:
		_music.play()


func _player(db: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.volume_db = db
	add_child(p)
	return p


# ------------------------------------------------------------- lifecycle --

func activate() -> void:
	active = true
	_to_title()


func deactivate() -> void:
	active = false
	for p in [_music, _drone, _heart, _sfx, _voice]: p.stop()
	_to_title()


func _to_title() -> void:
	mode = Mode.TITLE
	mode_t = 0.0
	flash = 0.0
	arrived = false
	dark_x = -100.0
	darkness = 0.0
	prox = 0.0
	scare_t = 0.0
	flicker_t = 0.0
	glitch_t = 6.0
	_drone.stop()
	_heart.stop()
	_music.pitch_scale = 1.0
	_music.volume_db = -9.0
	_start_music()
	_build_course()


func _start_run() -> void:
	_build_course()
	pos = Vector2(START_X, 3.5)
	feet = 0.0
	vel = Vector2.ZERO
	vz = 0.0
	angle = 0.0
	on_ground = true
	safe_pos = pos
	safe_feet = 0.0
	run_t = 0.0
	lights = 0
	arrived = false
	dark_x = -100.0
	look_cooldown = 0.0
	darkness = 0.0
	prox = 0.0
	hoo_face = 0.0
	mode = Mode.INTRO
	mode_t = 0.0
	_sfx_play("coin")


## The opening, in third person. The camera faces Hooshang; behind him the
## corridor runs back into the dark, and that is where Darkshang comes from.
func _tick_intro(delta: float, go: bool) -> void:
	var t := mode_t
	if go and t > 0.8:
		t = INTRO_TIME
	# he appears, far back, in a stutter of the lights
	if t >= 1.2 and not arrived:
		arrived = true
		flicker_t = 0.35
		_voice_play("whisper")
		if _drone.stream: _drone.play()
	if arrived:
		dark_x = lerpf(pos.x - 11.5, pos.x - START_GAP, smoothstep(1.2, INTRO_TIME, t))
		var gap := pos.x - dark_x
		prox = clampf(1.0 - (gap - 1.5) / 9.0, 0.0, 1.0) * 0.6
		darkness = 0.22 * smoothstep(1.2, INTRO_TIME, t)
		morph = clampf(0.5 + 0.5 * sin(clock * 1.3), 0.0, 1.0)
		_tick_mood(delta)
	# Hooshang: faces us, hears him and turns to look, turns back to run
	hoo_face = PI if t >= 2.2 and t < 3.2 else 0.0
	if t < 3.2:
		view_pos = Vector2(pos.x + 2.7 - 0.15 * t, pos.y + 0.25 * sin(t * 0.7))
		view_z = 0.8
		hoo_shown = true
	else:
		# swing round him and in, ending behind his eyes facing down the corridor
		var k := smoothstep(3.2, INTRO_TIME, t)
		var phi := k * PI
		var r := 2.22 * (1.0 - k)
		view_pos = pos + Vector2(cos(phi) * r, sin(phi) * r * 0.55)
		view_z = lerpf(0.8, EYE, k)
		hoo_shown = r > 0.45
	view_angle = (pos - view_pos).angle() if view_pos.distance_to(pos) > 0.05 else 0.0
	# which drawing of him the camera sees
	var facing := Vector2.from_angle(hoo_face)
	var to_cam := (view_pos - pos).normalized()
	var frame := int(clock * 5.0) % 4
	var d := facing.dot(to_cam)
	if d > 0.5:
		hoo_cell = Vector2i(frame, 0)
		hoo_flip = false
	elif d < -0.5:
		hoo_cell = Vector2i(0, 2)
		hoo_flip = false
	else:
		hoo_cell = Vector2i(frame, 1)
		hoo_flip = facing.dot(Vector2(-sin(view_angle), cos(view_angle))) < 0.0
	if t >= INTRO_TIME:
		_begin_chase()


func _begin_chase() -> void:
	arrived = true
	dark_x = pos.x - START_GAP
	if _drone.stream and not _drone.playing: _drone.play()
	hoo_shown = false
	angle = 0.0
	view_z = feet + EYE
	flicker_t = 0.12
	mode = Mode.PLAY
	mode_t = 0.0


# --------------------------------------------------------------- update --

func _physics_process(delta: float) -> void:
	clock += delta
	mode_t += delta
	flash = maxf(flash - delta * 1.8, 0.0)
	scare_t = maxf(scare_t - delta, 0.0)
	flicker_t = maxf(flicker_t - delta, 0.0)
	look_cooldown = maxf(look_cooldown - delta, 0.0)
	for p in pops:
		p.t += delta
		p.x += p.vx * delta
		p.y += p.vy * delta
		p.z += p.vz * delta
		p.vz -= delta * (0.0 if p.kind == 5.0 else 6.0)
	pops = pops.filter(func(p): return p.t < 0.45)
	if active and Input.is_action_just_pressed("pause"):
		exit_requested.emit()
		return
	var go := active and (Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("move_up"))
	match mode:
		Mode.TITLE:
			# Attract: a slow, bright flight down the corridor — and, every so
			# often, two frames of what is waiting in it.
			pos = Vector2(2.5 + fmod(clock * 1.6, 44.0), 3.5 + 0.9 * sin(clock * 0.4))
			view_z = 1.7 + 0.4 * sin(clock * 0.5)
			angle = 0.3 * sin(clock * 0.25)
			glitch_t -= delta
			if glitch_t < -0.1: glitch_t = _fx.randf_range(5.0, 9.0)
			if go and mode_t > 0.3: _start_run()
		Mode.INTRO:
			run_t += delta
			_tick_intro(delta, go)
		Mode.PLAY:
			run_t += delta
			_tick_play(delta)
			_tick_dark(delta)
		Mode.FALLING:
			run_t += delta
			view_z = maxf(view_z - delta * 3.0, -4.0)
			_tick_dark(delta)
			if mode == Mode.FALLING and mode_t > FALL_TIME:
				pos = safe_pos
				feet = safe_feet
				vel = Vector2.ZERO
				vz = 0.0
				view_z = feet + EYE
				on_ground = true
				mode = Mode.PLAY
				mode_t = 0.0
		Mode.CAUGHT:
			_tick_caught(delta, go)
		Mode.ESCAPED:
			view_z = feet + EYE
			if mode_t > 6.0 or (go and mode_t > 3.0):
				finished.emit()
				_to_title()
	if mode != Mode.INTRO:
		view_pos = pos
		view_angle = angle
	_push_view()
	_hud.queue_redraw()


func _tick_play(delta: float) -> void:
	angle += Input.get_axis("move_left", "move_right") * TURN_SPEED * delta
	var fwd := 0.0
	if Input.is_action_pressed("move_up"): fwd += 1.0
	if Input.is_action_pressed("move_down"): fwd -= 0.7
	var top := RUN if Input.is_action_pressed("dash") else WALK
	vel = vel.move_toward(Vector2.from_angle(angle) * fwd * top, (ACCEL if on_ground else AIR_ACCEL) * delta)
	_move_h(vel * delta)
	coyote = COYOTE if on_ground else maxf(coyote - delta, 0.0)
	buffer = BUFFER if Input.is_action_just_pressed("jump") else maxf(buffer - delta, 0.0)
	if buffer > 0.0 and coyote > 0.0:
		vz = JUMP + vel.length() * JUMP_RUN_BONUS
		on_ground = false
		coyote = 0.0
		buffer = 0.0
		_sfx_play("jump")
	var g := GRAVITY_HELD if vz > 0.0 and Input.is_action_pressed("jump") else GRAVITY
	vz = maxf(vz - g * delta, -MAX_FALL)
	var nz := feet + vz * delta
	if vz > 0.0:
		var ceiling := _ceiling(pos, feet + BODY)
		if nz + BODY > ceiling[0]:
			nz = ceiling[0] - BODY
			vz = 0.0
			_bump(ceiling[1])
		feet = nz
		on_ground = false
	else:
		var floor_z := _support(pos, feet)
		if nz <= floor_z:
			feet = floor_z
			vz = 0.0
			on_ground = true
		else:
			feet = nz
			on_ground = false
	if on_ground and _all_ground(pos):
		safe_pos = pos
		safe_feet = feet
	if on_ground and vel.length() > 0.3: walk_phase += delta * vel.length() * 3.2
	view_z = feet + EYE + (sin(walk_phase) * 0.025 if on_ground else 0.0)
	if feet < -1.5:
		_sfx_play("hit")
		_voice_play("whisper")
		flash = 0.6
		flash_color = Color(0, 0, 0)
		mode = Mode.FALLING
		mode_t = 0.0
		return
	var body := Vector3(pos.x, pos.y, feet + BODY * 0.5)
	for i in range(coin_list.size() - 1, -1, -1):
		if body.distance_to(coin_list[i]) < 0.5:
			_take_light(coin_list[i], LIGHT_PUSH)
			coin_list.remove_at(i)
	if pos.x >= door_x - 0.6:
		_escape()


## His side of the minute: arrive, follow, swell, scare — and take you.
func _tick_dark(delta: float) -> void:
	if not arrived:
		return
	var gap := pos.x - dark_x
	var pace := lerpf(SPEED_FROM, SPEED_TO, clampf((run_t - INTRO_TIME) / (RUN_TIME - INTRO_TIME), 0.0, 1.0))
	dark_x += (pace + clampf((gap - LEASH) * 0.5, 0.0, 3.0)) * delta
	gap = pos.x - dark_x
	prox = clampf(1.0 - (gap - 1.5) / 9.0, 0.0, 1.0)
	# darkest just before the light: it thickens with time, with how close he
	# is, and with how near you are to the way out
	var progress := smoothstep(0.1, 0.92, (pos.x - START_X) / (door_x - START_X)) * 0.92
	var since := 0.22 + 0.78 * smoothstep(INTRO_TIME, RUN_TIME - 4.0, run_t)
	darkness = maxf(maxf(since, progress), prox * 0.75)
	morph = clampf(0.5 + 0.5 * sin(clock * 0.9) + prox * 0.7 - 0.25, 0.0, 1.0)
	_tick_mood(delta)
	if prox > 0.45 and _fx.randf() < delta * 0.12 * prox:
		_scare()
	# turn round and look at him, and he looks back
	if cos(angle) < -0.3 and gap < 7.0 and look_cooldown <= 0.0:
		look_cooldown = 6.0
		morph = 1.0
		_sfx_play("stinger")
	if (gap <= 0.4 or run_t >= RUN_TIME) and mode != Mode.CAUGHT:
		_caught()


## What the place sounds and feels like at this much dark: the music rotting,
## the drone, the heartbeat, the lights stuttering.
func _tick_mood(delta: float) -> void:
	_music.pitch_scale = lerpf(1.0, 0.5, darkness)
	_music.volume_db = lerpf(-9.0, -32.0, darkness)
	_drone.volume_db = lerpf(-30.0, -4.0, maxf(darkness, prox))
	heart_t -= delta
	if heart_t <= 0.0 and _heart.stream:
		heart_t = lerpf(1.1, 0.3, prox)
		_heart.volume_db = lerpf(-22.0, 0.0, prox)
		_heart.play()
	# the lights stutter, and in the dark his face is there
	if _fx.randf() < delta * 0.35 * darkness:
		flicker_t = _fx.randf_range(0.08, 0.3)


func _scare() -> void:
	scare_t = 0.07
	_voice_play("stinger")


func _caught() -> void:
	mode = Mode.CAUGHT
	mode_t = 0.0
	_music.stop()
	_heart.stop()
	_voice_play("shriek")


func _tick_caught(delta: float, go: bool) -> void:
	# the dark closes over the view, his face comes at you, then nothing
	prox = 1.0
	darkness = 1.0
	dark_x = minf(dark_x + delta * 4.0, pos.x + 0.2)
	angle += delta * 0.6
	if mode_t > 0.9 and mode_t < 1.5: scare_t = 0.05
	_drone.volume_db = lerpf(-4.0, -40.0, clampf((mode_t - 2.0) / 2.0, 0.0, 1.0))
	if mode_t > 6.0 or (go and mode_t > SKIP_END):
		_to_title()


func _escape() -> void:
	mode = Mode.ESCAPED
	mode_t = 0.0
	flash = 1.0
	flash_color = Color(1.0, 0.97, 0.88)
	_drone.stop()
	_heart.stop()
	_music.pitch_scale = 1.0
	_music.volume_db = -14.0
	_sfx_play("valley")


func _take_light(at: Vector3, push: float) -> void:
	for k in 5:
		var a := k * TAU / 5.0 + clock
		pops.append({x = at.x, y = at.y, z = at.z, t = 0.05 * k, kind = 7.0,
			vx = cos(a) * 1.2, vy = sin(a) * 1.2, vz = 2.0})
	lights += 1
	if arrived: dark_x -= push
	flash = 0.25
	flash_color = Color(1.0, 0.85, 0.5)
	_sfx_play("coin")


func _bump(c: Vector2i) -> void:
	if not _inb(c): return
	var i := _i(c)
	if sm[i] == M_STAR:
		sm[i] = M_USED
		_upload_cell(c)
		var at := Vector3(c.x + 0.5, c.y + 0.5, st[i] + 0.3)
		pops.append({x = at.x, y = at.y, z = at.z, t = 0.0, kind = 5.0, vx = 0.0, vy = 0.0, vz = 2.2})
		_take_light(at + Vector3(0, 0, 0.6), BURST_PUSH)
		_sfx_play("portal")
	else:
		_sfx_play("bump")


# ------------------------------------------------------------ collision --

func _i(c: Vector2i) -> int:
	return c.y * MW + c.x


func _inb(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < MW and c.y < MH


func _has_block(i: int) -> bool:
	return st[i] > sb[i]


## Does cell `c` block a body spanning heights z0..z1?
func _blocks(c: Vector2i, z0: float, z1: float) -> bool:
	if not _inb(c): return true
	var i := _i(c)
	if hg[i] > z0 + STEP: return true
	return _has_block(i) and sb[i] < z1 and st[i] > z0 + STEP


func _corners(p: Vector2) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for o in [Vector2(-RADIUS, -RADIUS), Vector2(RADIUS, -RADIUS), Vector2(-RADIUS, RADIUS), Vector2(RADIUS, RADIUS)]:
		var c := Vector2i((p + o).floor())
		if not out.has(c): out.append(c)
	return out


## Every corner of the footprint over ground (not a pit): a safe respawn.
func _all_ground(p: Vector2) -> bool:
	for c in _corners(p):
		if not _inb(c) or hg[_i(c)] < -1.0: return false
	return true


## The highest surface under the footprint at or below height z.
func _support(p: Vector2, z: float) -> float:
	var best := -INF
	for c in _corners(p):
		if not _inb(c): continue
		var i := _i(c)
		if hg[i] <= z + STEP: best = maxf(best, hg[i])
		if _has_block(i) and st[i] <= z + STEP: best = maxf(best, st[i])
	return best


## The lowest block underside over the footprint at or above `head`, and its
## cell — the centre's own cell first, so a bump lands on the block overhead.
func _ceiling(p: Vector2, head: float) -> Array:
	var best := INF
	var cell := Vector2i(-1, -1)
	var cells := _corners(p)
	var own := Vector2i(p.floor())
	if own in cells:
		cells.erase(own)
		cells.push_front(own)
	for c in cells:
		if not _inb(c): continue
		var i := _i(c)
		if _has_block(i) and sb[i] >= head - STEP and sb[i] < best - 0.01:
			best = sb[i]
			cell = c
	return [best, cell]


func _move_h(step: Vector2) -> void:
	for axis in 2:
		var np := pos
		np[axis] += step[axis]
		var ok := true
		for c in _corners(np):
			if _blocks(c, feet, feet + BODY): ok = false
		if ok: pos = np
		else: vel[axis] = 0.0


# ---------------------------------------------------------------- course --

func _set_ground(c: Vector2i, h: float, mat: int) -> void:
	var i := _i(c)
	hg[i] = h
	gm[i] = mat
	sb[i] = 0.0
	st[i] = 0.0
	sm[i] = 0


func _column(x: int, h: float, mat: int) -> void:
	for y in range(1, 6):
		_set_ground(Vector2i(x, y), h, mat)


func _columns(x0: int, x1: int, h: float, mat: int) -> void:
	for x in range(x0, x1 + 1):
		_column(x, h, mat)


func _block(c: Vector2i, bottom: float, top: float, mat: int) -> void:
	var i := _i(c)
	sb[i] = bottom
	st[i] = top
	sm[i] = mat


func _coin_row(x0: int, x1: int, lane: int, z: float) -> void:
	for x in range(x0, x1 + 1):
		coin_list.append(Vector3(x + 0.5, lane + 0.5, z))


## The corridor: built from segments with a fixed seed, so it is the same
## place every run, ending in a wall of lit arches — the way out.
func _build_course() -> void:
	_rng.seed = COURSE_SEED
	hg.resize(MW * MH); sb.resize(MW * MH); st.resize(MW * MH)
	gm.resize(MW * MH); sm.resize(MW * MH)
	hg.fill(WALL_H); sb.fill(0.0); st.fill(0.0); gm.fill(M_KASHI); sm.fill(0)
	coin_list.clear()
	pops.clear()
	for x in MW:
		for y in [0, 6]:
			if _rng.randf() < 0.14: gm[_i(Vector2i(x, y))] = M_NICHE
	_column(0, WALL_H, M_PAVILION)
	var x := _flat(1, 17)
	while x < COURSE_LENGTH and x < MW - 24:
		x = _segment(x)
	_columns(x, x + 3, 0.0, M_GROUND)
	_coin_row(x, x + 2, 3, 0.45)
	_column(x + 4, WALL_H, M_DOOR)
	door_x = x + 4.0
	for xx in range(x + 5, MW): _column(xx, WALL_H, M_PAVILION)
	_upload()


func _segment(x: int) -> int:
	var options := ["flat", "pit", "pit", "blocks", "stairs", "pipes", "stones"]
	match options[_rng.randi() % options.size()]:
		"flat": return _flat(x, _rng.randi_range(3, 6))
		"pit": return _pit(x)
		"blocks": return _blocks_row(x)
		"stairs": return _stairs(x)
		"pipes": return _pipes(x)
		_: return _stones(x)


func _flat(x: int, n: int) -> int:
	_columns(x, x + n - 1, 0.0, M_GROUND)
	if _rng.randf() < 0.5:
		_coin_row(x + 1, x + n - 2, _rng.randi_range(2, 4), 0.45)
	return x + n


func _pit(x: int) -> int:
	var w := _rng.randi_range(1, mini(1 + LEVEL / 2, 3))
	_column(x, 0.0, M_GROUND)
	_columns(x + 1, x + w, PIT_H, M_ABYSS)
	for k in w:
		coin_list.append(Vector3(x + 1.5 + k, 3.5, 1.3))
	_columns(x + w + 1, x + w + 2, 0.0, M_GROUND)
	return x + w + 3


func _blocks_row(x: int) -> int:
	_columns(x, x + 6, 0.0, M_GROUND)
	var lane := _rng.randi_range(2, 4)
	for k in 4:
		var mat := M_STAR if k % 2 == 0 or _rng.randf() < 0.25 else M_BRICK
		_block(Vector2i(x + 1 + k, lane), 1.4, 1.9, mat)
	if _rng.randf() < 0.5:
		coin_list.append(Vector3(x + 2.5, lane + 0.5, 2.3))
	return x + 7


func _stairs(x: int) -> int:
	var n := _rng.randi_range(2, mini(2 + LEVEL / 2, 4))
	_column(x, 0.0, M_GROUND)
	x += 1
	for k in n: _column(x + k, 0.5 * (k + 1), M_HARD)
	var top := x + n
	if _rng.randf() < 0.5:
		# A gap between two stairs gets a two-cell top on either side: a run-up
		# to jump from and room to land.
		_column(top, 0.5 * n, M_HARD)
		top += 1
		var gap := _rng.randi_range(1, mini(1 + LEVEL / 3, 2))
		_columns(top, top + gap - 1, PIT_H, M_ABYSS)
		coin_list.append(Vector3(top + gap * 0.5, 3.5, 0.5 * n + 1.0))
		top += gap
		_column(top, 0.5 * n, M_HARD)
		top += 1
		for k in n: _column(top + k, 0.5 * (n - k), M_HARD)
		x = top + n
	else:
		coin_list.append(Vector3(top - 0.5, 3.5, 0.5 * n + 0.6))
		for k in n - 1: _column(top + k, 0.5 * (n - 1 - k), M_HARD)
		x = top + n - 1
	_columns(x, x + 1, 0.0, M_GROUND)
	return x + 2


func _pipes(x: int) -> int:
	_columns(x, x + 8, 0.0, M_GROUND)
	for k in [1, 5]:
		var h: float = [1.0, 1.5][_rng.randi() % 2]
		var lane := _rng.randi_range(1, 4)
		for dx in 2:
			for dy in 2:
				_set_ground(Vector2i(x + k + dx, lane + dy), h, M_PIPE)
		coin_list.append(Vector3(x + k + 1, lane + 1, h + 0.45))
	return x + 9


func _stones(x: int) -> int:
	_column(x, 0.0, M_GROUND)
	var cx := x + 1
	var lane := _rng.randi_range(2, 3)
	for k in _rng.randi_range(2, 3):
		var gap := _rng.randi_range(1, 2)
		_columns(cx, cx + gap - 1, PIT_H, M_ABYSS)
		cx += gap
		lane = clampi(lane + _rng.randi_range(-1, 1), 1, 4)
		for s in _rng.randi_range(3, 4):   # long enough to land a full running jump on
			_column(cx, PIT_H, M_ABYSS)
			_set_ground(Vector2i(cx, lane), 0.0, M_HARD)
			_set_ground(Vector2i(cx, lane + 1), 0.0, M_HARD)
			cx += 1
		coin_list.append(Vector3(cx - 0.5, lane + 1.0, 0.45))
	_column(cx, PIT_H, M_ABYSS)
	_columns(cx + 1, cx + 2, 0.0, M_GROUND)
	return cx + 3


func _encode(h: float) -> int:
	return 0 if h <= PIT_H + 0.01 else clampi(roundi(h * 32.0 + 64.0), 1, 255)


func _texel(i: int) -> Color:
	var has := _has_block(i)
	return Color8(_encode(hg[i]), _encode(sb[i]) if has else 0, _encode(st[i]) if has else 0, gm[i] + 16 * sm[i])


func _upload_cell(c: Vector2i) -> void:
	_map_img.set_pixel(c.x, c.y, _texel(_i(c)))
	_map_tex.update(_map_img)


func _upload() -> void:
	for y in MH:
		for x in MW:
			_map_img.set_pixel(x, y, _texel(_i(Vector2i(x, y))))
	_map_tex.update(_map_img)


# ----------------------------------------------------------------- view --

func _push_view() -> void:
	var glitch := mode == Mode.TITLE and glitch_t < 0.0
	var caught := mode == Mode.CAUGHT
	_mat.set_shader_parameter("cam_pos", view_pos)
	_mat.set_shader_parameter("cam_z", view_z)
	_mat.set_shader_parameter("cam_angle", view_angle)
	_mat.set_shader_parameter("hoo_pos", Vector3(pos.x, pos.y, feet) if hoo_shown and mode == Mode.INTRO else Vector3(-100, 0, 0))
	_mat.set_shader_parameter("hoo_cell", hoo_cell)
	_mat.set_shader_parameter("hoo_flip", 1.0 if hoo_flip else 0.0)
	_mat.set_shader_parameter("clock", clock)
	_mat.set_shader_parameter("trip", 0.5 * (1.0 - darkness) if mode != Mode.ESCAPED else 0.3)
	_mat.set_shader_parameter("dark", 0.95 if glitch else (darkness if mode != Mode.ESCAPED else 0.0))
	_mat.set_shader_parameter("dark_x", dark_x if mode != Mode.ESCAPED else -100.0)
	_mat.set_shader_parameter("ds_size", lerpf(2.4, 5.5, darkness))
	_mat.set_shader_parameter("morph", morph)
	_mat.set_shader_parameter("prox", prox if mode in [Mode.INTRO, Mode.PLAY, Mode.FALLING, Mode.CAUGHT] else 0.0)
	_mat.set_shader_parameter("scare", 1.0 if scare_t > 0.0 else 0.0)
	_mat.set_shader_parameter("consume", clampf(mode_t / 0.9, 0.0, 1.0) if caught else (1.0 if mode == Mode.FALLING else 0.0))
	_mat.set_shader_parameter("flicker", 1.0 if flicker_t > 0.0 or glitch else 0.0)
	_mat.set_shader_parameter("flash", flash)
	_mat.set_shader_parameter("flash_color", Vector3(flash_color.r, flash_color.g, flash_color.b))
	var cands: Array = []
	for c in coin_list:
		cands.append([pos.distance_squared_to(Vector2(c.x, c.y)), Vector4(c.x, c.y, c.z, 1.0)])
	for p in pops:
		cands.append([0.0, Vector4(p.x, p.y, p.z, p.kind)])
	cands.sort_custom(func(a, b): return a[0] < b[0])
	var arr := PackedVector4Array()
	for k in mini(cands.size(), MAX_SPRITES): arr.append(cands[k][1])
	var count := arr.size()
	arr.resize(MAX_SPRITES)
	_mat.set_shader_parameter("sprites", arr)
	_mat.set_shader_parameter("sprite_count", count)


func _sfx_play(name: String) -> void:
	if not active or not _sounds.has(name): return
	_sfx.stream = _sounds[name]
	_sfx.pitch_scale = lerpf(1.0, 0.6, darkness)
	_sfx.play()


func _voice_play(name: String) -> void:
	if not active or not _sounds.has(name): return
	_voice.stream = _sounds[name]
	_voice.pitch_scale = _fx.randf_range(0.85, 1.1)
	_voice.play()


# ------------------------------------------------------------------ HUD --

const GOLD := Color(0.95, 0.74, 0.30)
const IVORY := Color(0.95, 0.90, 0.76)
const TURQ := Color(0.20, 0.70, 0.70)
const BLOOD := Color(0.7, 0.06, 0.1)


func _draw_hud(c: CanvasItem) -> void:
	match mode:
		Mode.TITLE: _draw_title(c)
		Mode.INTRO:
			# letterbox while it is a film; the bars slide away as it becomes you
			var bar := 11.0 * (1.0 - smoothstep(INTRO_TIME - 0.6, INTRO_TIME, mode_t))
			c.draw_rect(Rect2(0, 0, W, bar), Color.BLACK)
			c.draw_rect(Rect2(0, H - bar, W, bar), Color.BLACK)
		Mode.PLAY, Mode.FALLING:
			_draw_lamp(c)
			if needs_go_prompt():
				c.draw_rect(Rect2(0, 92, W, 11), Color(0, 0, 0, 0.55))
				_text(c, "HOLD UP TO RUN", 100, IVORY, 1)
		Mode.CAUGHT:
			if mode_t > 2.2:
				c.draw_rect(Rect2(0, 0, W, H), Color.BLACK)
				var a := clampf((mode_t - 2.4) / 1.0, 0.0, 1.0)
				_text(c, "CONSUMED", 56, Color(BLOOD, a), 2)
				if mode_t > 3.6:
					_text(c, "he was always behind you", 78, Color(0.5, 0.45, 0.55, clampf(mode_t - 3.6, 0.0, 1.0)), 1)
		Mode.ESCAPED:
			c.draw_rect(Rect2(0, 0, W, H), Color(1.0, 0.98, 0.92, clampf(mode_t * 0.8, 0.0, 1.0)))
			if mode_t > 1.2: _text(c, "THE LIGHT HOLDS", 54, Color(0.55, 0.42, 0.2), 1)
			if mode_t > 2.6 and mode_t < 2.75:
				c.draw_rect(Rect2(0, 0, W, H), Color.BLACK)
				c.draw_rect(Rect2(66, 50, 9, 2), IVORY)
				c.draw_rect(Rect2(85, 50, 9, 2), IVORY)
			if mode_t > 2.75: _text(c, "for now", 70, Color(0.35, 0.3, 0.4), 1)


## Until he has made a start down the corridor, the run says how to make one.
func needs_go_prompt() -> bool:
	return mode == Mode.PLAY and pos.x - START_X < STARTED


## The run's clock is a little oil lamp (cheragh): its flame burns down over
## the minute, and gutters as he comes.
func _draw_lamp(c: CanvasItem) -> void:
	var at := Vector2(6, H - 8)
	var left := clampf(1.0 - run_t / RUN_TIME, 0.0, 1.0)
	var flick := 0.0 if prox < 0.2 else _fx.randf_range(-1.5, 1.0) * prox
	var flame := maxf(left * 7.0 + flick, 0.0)
	if flame > 0.5:
		c.draw_rect(Rect2(at + Vector2(3, -2 - flame), Vector2(2, flame)), GOLD)
		c.draw_rect(Rect2(at + Vector2(3.5, -1.5 - flame * 0.5), Vector2(1, flame * 0.5)), IVORY)
	c.draw_rect(Rect2(at + Vector2(0, -2), Vector2(9, 3)), Color(0.7, 0.5, 0.2))
	c.draw_rect(Rect2(at + Vector2(1, 1), Vector2(7, 1)), Color(0.45, 0.3, 0.12))
	c.draw_rect(Rect2(at + Vector2(9, -2), Vector2(2, 1)), Color(0.7, 0.5, 0.2))
	c.draw_rect(Rect2(at + Vector2(-1, -1), Vector2(1, 2)), Color(0.55, 0.38, 0.15))


func _draw_title(c: CanvasItem) -> void:
	var glitch := glitch_t < 0.0
	c.draw_rect(Rect2(10, 22, W - 20, 52), Color(0.04, 0.05, 0.16, 0.82))
	c.draw_rect(Rect2(10, 22, W - 20, 2), BLOOD if glitch else GOLD)
	c.draw_rect(Rect2(10, 72, W - 20, 2), BLOOD if glitch else GOLD)
	if glitch:
		_text(c, "DARKSHANG", 52, BLOOD, 2)
		_text(c, "IS WAITING", 66, Color(0.5, 0.45, 0.55), 1)
		return
	_star(c, Vector2(24, 48), 7.0, GOLD)
	_star(c, Vector2(W - 24, 48), 7.0, GOLD)
	_text(c, "- SUPER -", 34, TURQ, 1)
	_text(c, "SIMORGH", 52, GOLD, 2)
	_text(c, "RUN TO THE LIGHT", 66, IVORY, 1)
	if int(mode_t * 2.0) % 2 == 0:
		c.draw_rect(Rect2(44, 84, W - 88, 11), Color(0.04, 0.05, 0.16, 0.82))
		_text(c, "PRESS JUMP" if active else "INSERT DISK", 92, Color.WHITE, 1)
	if active:
		c.draw_rect(Rect2(0, 98, W, 22), Color(0, 0, 0, 0.5))
		var lines := title_controls()
		for k in lines.size(): _text(c, lines[k], 107 + 9 * k, TURQ, 1)


## The title's two lines of controls, in the device's own names.
func title_controls() -> PackedStringArray:
	var pad := InputDevice.is_controller()
	return PackedStringArray(["UP GO  LEFT/RIGHT TURN",
		"%s JUMP  X RUN  %s LEAVE" % ["A" if pad else "C", RetroTV.leave_key()]])


func _text(c: CanvasItem, text: String, y: float, color: Color, scale: int) -> void:
	var w := FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 7).x * scale
	c.draw_set_transform(Vector2(roundf((W - w) * 0.5), y), 0.0, Vector2(scale, scale))
	c.draw_string(FONT, Vector2.ZERO, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, color)
	c.draw_set_transform(Vector2.ZERO)


## An eight-pointed star (a square and a diamond), the shamseh in miniature.
func _star(c: CanvasItem, at: Vector2, r: float, color: Color) -> void:
	for a in [0.0, PI / 4.0]:
		var pts := PackedVector2Array()
		for k in 4:
			pts.append(at + Vector2.from_angle(a + k * PI / 2.0) * r)
		c.draw_colored_polygon(pts, color)
	c.draw_circle(at, r * 0.3, TURQ)
