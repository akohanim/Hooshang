class_name Darkshang
extends Area2D
## Hooshang's shadow self, and the only thing in this game that chases you.
##
## He is a DELAYED ECHO: every frame he stands where the player stood
## `read_delay` seconds ago, replayed off PlayerPositionBuffer. That is the whole
## design. It means he is never unfair (he can only go where you have already
## been, so every route he takes is a route you survived), it means stopping
## moving is what kills you, and it means he needs no pathfinding at all.
##
## HE IS AN Area2D, NEVER A CharacterBody2D, AND THAT IS THE POINT.
##
## He ignores level geometry completely — no gravity, no floor, no
## move_and_slide, no collision response of any kind. His position is written
## directly. A shadow that had to walk the room would need everything the player
## controller is, would get stuck on the first ledge, and would stop being
## frightening the moment you learned he could not follow you up a wall. His only
## collision shape is a detection box on the PLAYER's layer; the world layer is
## not in his mask at all, so there is nothing solid he could be stopped by even
## by accident. Pass-through is reported by a separate probe (see GeometryProbe
## below) purely so the art can swell as he goes through a wall — the probe never
## touches his position.
##
## DEATH GOES THROUGH THE EXISTING PATH, ALWAYS.
##
## Catching the player does NOT kill him here. It plays the ingestion animation
## and then calls `player.die()` — the same die() a spike calls, so the death
## count, the burst, the respawn delay and the checkpoint all behave exactly as
## they do everywhere else. See the long comment above Player.die(): death in
## this game has a history of being counted twice, and the fix was to have
## exactly one path. This adds none.

## Where the art comes from. Owned by the art side, and deliberately `load`ed
## behind an existence check rather than preloaded: a preload of a missing file
## is a PARSE error, which would take this whole script — and every level holding
## a Darkshang — down while that scene is still being built. Same reasoning, and
## the same shape, as conveyor_belt.gd's visual. Missing, he is invisible and
## behaves identically.
const VISUAL_SCENE := "res://scenes/characters/darkshang/DarkshangVisual.tscn"

const BUFFER_SCENE := preload("res://scenes/props/chase/PlayerPositionBuffer.tscn")

## Motion states handed to DarkshangVisual.set_motion(). Mirrors its contract;
## the numbers are its, not ours.
enum Motion { IDLE = 0, MOVE = 1, SURGE = 2 }

enum State {
	DORMANT,    ## the chase has not started; he sits at his spawn point
	FOLLOWING,  ## replaying the buffer at read_delay
	SURGING,    ## off the tape, straight at where the player IS
	CAUGHT,     ## the ingestion animation is playing; nothing moves
}

## Fired the moment a surge is TELEGRAPHED, `warning` seconds before he actually
## snaps at the player. Sound, a screen shake and the visual's wind-up hang off
## this — the warning is what makes a surge death read as "I should have dashed"
## instead of "that was random".
signal surge_warned(warning: float)
## Fired when he actually leaves the tape and lunges.
signal surge_started(duration: float, intensity: float)
## Fired when the lunge is over and the delay begins recovering.
signal surge_ended()
## Contact, before anything else happens. The ingestion animation is about to
## play; the player is already input-locked.
signal caught_player(player: Player)
## He has passed into / out of solid level geometry. Reporting only — see
## GeometryProbe. The visual's pass-through swell hangs off these.
signal entered_geometry()
signal left_geometry()
## The chase is over (a SafeZone, or anything else calling stop_chase()).
signal chase_ended()
## He has been put back behind a checkpoint (or a room transition) and the tape
## reseeded, with `at` the player's new position. Fires at the instant the board
## is reset, which is the only moment the gap is exactly `respawn_gap` — from the
## next frame on it is already closing.
signal chase_reset(at: Vector2)

@export_group("Chase")
## How far behind the player he replays, in seconds. THE knob for how hard the
## chase is. Level_13 is 320px — one screen — and the player runs at 90 px/s, so
## 1.2s is a steady-state gap of ~108px: a third of the room, comfortably on
## screen at all times, and close enough that standing still for a second is
## fatal. Much above 2s and he is off the back of the screen in a room this size,
## which is a chase you cannot see.
@export var follow_delay := 1.2
## Whether he wakes up on his own when the player gets near, instead of waiting
## for a script to call start_chase(). On, so a room with a DarkshangSpawn in it
## works with no wiring at all; off if a cutscene should start him.
@export var auto_start := true
## How close the player has to get before auto_start wakes him, in px. 240 is
## most of a 320px room, so entering the room starts the chase — and rooms are
## hundreds of pixels apart in the LDtk world, so a player two rooms away never
## does.
@export var wake_distance := 240.0
## How fast he drifts to the spot he is replaying when he is NOT free to jump
## there — used after a surge, to blend back onto the tape instead of snapping.
## In seconds to close the gap. 0.35 reads as him settling back into the walls.
@export var reattach_time := 0.35

@export_group("Surge")
## Warning before a surge actually starts, in seconds. The player must have time
## to react — 0.5s is about three quarters of a dash's worth of thinking time,
## which is the difference between a death that teaches and a death that annoys.
@export var surge_warning := 0.5
## How fast he travels while surging, px/s. Above the player's 90 px/s run so the
## gap genuinely closes, below his 260 px/s dash so a dash always outruns it —
## that inequality IS the mechanic, and breaking either half of it breaks the
## read. 150 closes ~60 px/s, so a 1.2s surge eats about 72px of a 108px gap.
@export var surge_speed := 150.0
## How fast the shrunken read-delay recovers afterwards, in seconds of delay per
## second of real time. 0.35 means a full 0.7-intensity surge takes ~2.4s to fall
## back to the base gap — long enough that a surge leaves the chase genuinely
## tighter for a while rather than resetting the instant it ends.
@export var delay_recovery := 0.35

@export_group("Caught")
## How long the ingestion animation owns the screen before the existing death
## fires, in seconds. Handed to DarkshangVisual.ingest(). Its own number rather
## than Player.death_time: being eaten is a set piece and is allowed to take
## longer than falling on a spike, which is now 0.5s.
@export var ingest_time := 1.0

@export_group("Respawn")
## Which way the route runs — the direction the PLAYER travels. He is put back
## BEHIND the checkpoint along this, so a respawn always faces the player the
## right way rather than leaving him wherever the last life happened to end.
##
## LEFT, because the chase runs right to left: Hooshang is retracing his steps
## back to his own cubicle, against the direction the rest of Act I is walked.
## A chase that ran the other way wants this flipped per-instance.
@export var route_direction := Vector2.LEFT
## How far behind the checkpoint he is put back, in px. 108 = follow_delay x the
## player's 90 px/s run, i.e. exactly the gap a running chase settles at, so a
## respawn drops you back into the chase at its normal pressure rather than
## easier or harder than the rest of the room.
@export var respawn_gap := 108.0
## Seconds after a respawn during which contact cannot kill. Guards the one frame
## where he and the player might still overlap from the life that just ended —
## a respawn that kills you on frame one is unplayable and unloseable to debug.
@export var respawn_grace := 0.4

@export_group("Detection")
## Size of his kill box in px, centred on him. 12x16 is a shade wider and taller
## than the player's own 8x12 hitbox: a shadow that swallows you should not need
## to be pixel-aligned with you.
@export var catch_size := Vector2(12.0, 16.0):
	set(value):
		catch_size = value
		_fit(_shape, value)
## Size of the pass-through probe in px. Smaller than the kill box so the art
## only swells when he is genuinely INSIDE a wall, not when he brushes one.
@export var probe_size := Vector2(8.0, 10.0):
	set(value):
		probe_size = value
		_fit(_probe.get_child(0) if _probe != null else null, value)

## Where he started. Restored by reset_to_spawn() when there is no checkpoint to
## work from, and where he waits while DORMANT.
var spawn_point := Vector2.ZERO
var state: State = State.DORMANT
## The delay he is CURRENTLY reading at — shrinks during a surge, recovers after.
var read_delay := 0.0
var buffer: PlayerPositionBuffer
## True while he is overlapping solid geometry (the probe's answer).
var in_geometry := false

var _player: Player
var _visual: Node2D
var _probe: Area2D
var _shape: CollisionShape2D
var _surge_timer := 0.0
var _warning_timer := 0.0
var _pending_surge := Vector2.ZERO  # x = duration, y = intensity, queued by the warning
var _reattach := 0.0                # seconds of blend left after a surge
var _grace_timer := 0.0
## How fast he appeared to move last frame, px/s. Derived, not integrated — see
## velocity().
var _velocity := Vector2.ZERO
## The player whose death this node still owes. Non-null between contact and the
## die() call, and the ONLY thing that decides whether that call has happened —
## see _resolve_catch().
var _owed_death: Player
var _died_connected := false


func _ready() -> void:
	collision_layer = 8   # layer 4 "triggers" — nothing masks him, he is not solid
	collision_mask = 2    # the player, and nothing else. NOT layer 1: see the header.
	# After the player's move and after the buffer's record (priority 1), so he
	# reads a tape that already contains this frame.
	process_physics_priority = 2
	spawn_point = global_position
	read_delay = follow_delay

	_shape = CollisionShape2D.new()
	_shape.name = "CatchBox"
	_shape.shape = RectangleShape2D.new()
	add_child(_shape)
	_fit(_shape, catch_size)

	_build_probe()
	buffer = BUFFER_SCENE.instantiate()
	buffer.name = "PositionBuffer"
	add_child(buffer)
	buffer.teleported.connect(_on_player_teleported)
	_attach_visual()
	add_to_group("darkshang", true)


func _exit_tree() -> void:
	# Scene change, debug reload, anything: an ingestion cut short still owes a
	# death, and it is paid here rather than dropped. _resolve_catch() is the one
	# place that can pay it, so this cannot double up with the animation's own
	# completion.
	_resolve_catch()


func _physics_process(delta: float) -> void:
	_grace_timer = maxf(_grace_timer - delta, 0.0)
	_find_player()
	if _player == null:
		return
	if state == State.DORMANT:
		if auto_start and _player.global_position.distance_to(global_position) <= wake_distance:
			start_chase()
		return
	if state == State.CAUGHT:
		return  # frozen for the length of the ingestion

	var was := global_position
	_tick_surge(delta)
	match state:
		State.FOLLOWING:
			_move_following(delta)
		State.SURGING:
			_move_surging(delta)
	_velocity = (global_position - was) * float(Engine.physics_ticks_per_second)
	_check_catch()
	_push_visual()


# ------------------------------------------------------------------ chase ----

## Hold him off screen until something says otherwise: hidden, at his spawn
## point, and deaf to auto_start.
##
## A room with a DarkshangTrigger in it calls this on itself at load, so placing
## a trigger IS the statement "he waits for me". Without it he would wake on
## proximity — auto_start is on by default so a room needs no script at all — and
## the reveal the trigger exists to stage would already have happened.
func stand_by() -> void:
	auto_start = false
	stop_chase()
	global_position = spawn_point
	visible = false


## Put him at his spawn point and show him, without starting the chase.
##
## The "**darkshang appears**" half of a DarkshangTrigger's beat: he is on
## screen, and the player can look at him, while the dialogue plays and nothing
## is hunting anybody yet. Kept apart from start_chase() so the reveal and the
## danger are two separate moments a designer can put time between.
func reveal() -> void:
	global_position = spawn_point
	visible = true
	_push_visual()


## Wake him up and start replaying the tape. Safe to call twice.
##
## Also un-hides him, so a shadow held by stand_by() needs no second call: the
## one thing that starts a chase is the one thing that makes him visible, and
## they cannot get out of step.
func start_chase() -> void:
	if state != State.DORMANT:
		return
	visible = true
	state = State.FOLLOWING
	read_delay = follow_delay
	_seed_buffer_from(_player.global_position if _player != null else spawn_point)
	_grace_timer = respawn_grace


## Stop him where he stands for `seconds`, then carry on exactly as he was.
##
## A PAUSE, not a stop: state, timers, the gap and the tape all survive it, so
## what resumes is the same chase at the same distance. stop_chase()/start_chase()
## look like they would do this and do not — start_chase() re-seeds the buffer
## from wherever the player is now, which hands back a chase with the gap reset.
##
## His TAPE is held too. It records one sample per physics frame and is a child
## of this node, so freezing him alone would leave it filling with however many
## seconds of a player standing still — and he would then replay that stillness
## for the same length of time again after the hold, drifting a beat of cutscene
## into a beat of gameplay.
func hold(seconds: float) -> void:
	if seconds <= 0.0:
		return
	set_physics_process(false)
	if buffer != null:
		buffer.set_physics_process(false)
	await get_tree().create_timer(seconds).timeout
	if not is_inside_tree():
		return
	set_physics_process(true)
	if buffer != null:
		buffer.set_physics_process(true)


## Stop him dead — a SafeZone, or the end of the sequence. He goes DORMANT rather
## than being freed, so the narrative beat still has something on screen to talk
## to, and so restarting the chase is one call rather than a respawn.
func stop_chase() -> void:
	if state == State.DORMANT:
		return
	# An ingestion in flight when the chase ends still owes its death. Paying it
	# here (rather than swallowing it) is what keeps "cut short" and "played out"
	# the same number of deaths.
	_resolve_catch()
	state = State.DORMANT
	_pending_surge = Vector2.ZERO
	_warning_timer = 0.0
	_surge_timer = 0.0
	_reattach = 0.0
	read_delay = follow_delay
	_push_visual()
	chase_ended.emit()


## He stops, for good, exactly where he is standing.
##
## The difference from stop_chase() is `auto_start`, and it is not cosmetic.
## stop_chase() puts him back to DORMANT — and DORMANT is also the state he sits
## in BEFORE a chase, waiting to wake when the player comes within
## `wake_distance`. So a stop_chase() on its own reads as "the chase is over"
## and behaves as "the chase is armed again": in a 224px room the player is
## inside 240px of him from the moment he arrives, and the shadow would come
## back to life a second after standing down.
##
## He stays VISIBLE and stays PUT — no teleport to spawn_point, unlike
## stand_by(). That is the whole point of the beat this exists for: Act I ends
## with the thing that chased Hooshang across twenty rooms simply stopping in the
## doorway of his cubicle, still there, no longer coming.
func stand_down() -> void:
	auto_start = false
	stop_chase()
	# Otherwise the art keeps the lean of whatever he was doing on the last frame
	# he moved — he reads as paused mid-stride rather than as stopped.
	_velocity = Vector2.ZERO
	_push_visual()


## He goes out — stops, thins, and is not there any more.
##
## The end of the chase rather than a pause in it: stand_down() leaves him
## standing in the room to be talked to, and this is for the beat where there is
## nothing left to talk to. Act I ends with Hooshang asking "It's... gone?" and
## the honest answer has to already be on screen before he asks it.
##
## Stops FIRST and fades second, so nothing is still creeping toward the player
## while it thins out — a shadow that keeps closing while it disappears reads as
## a rendering bug rather than as an ending.
##
## `visible = false` at the end is what takes him out of `_shadow_in_play()`, so
## a later beat looking for "the shadow currently chasing" correctly finds none.
func dissolve(seconds: float) -> void:
	stand_down()
	if seconds <= 0.0:
		modulate.a = 0.0
		visible = false
		return
	var out := create_tween()
	out.tween_property(self, "modulate:a", 0.0, seconds) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await out.finished
	if not is_inside_tree():
		return
	visible = false


## Telegraph a surge, then lunge. Called by a SurgePointTrigger the player walks
## into. `duration` and `intensity` come off the LDtk entity, so two surge points
## in one room can differ.
##
## The WARNING is the whole reason this is two phases: he keeps following for
## `surge_warning` seconds first while the signal above lets sound and the art
## wind up. A surge that started on contact would be an unavoidable death for
## anyone who happened to be standing in the wrong place.
func surge(duration: float, intensity: float) -> void:
	if state != State.FOLLOWING or _warning_timer > 0.0:
		return
	_pending_surge = Vector2(maxf(duration, 0.0), clampf(intensity, 0.0, 1.0))
	_warning_timer = maxf(surge_warning, 0.0)
	surge_warned.emit(_warning_timer)
	if _warning_timer <= 0.0:
		_begin_surge()


## True while a surge is telegraphed but has not landed yet.
func warning() -> bool:
	return _warning_timer > 0.0


## Gap to the live player in px — what the chase actually feels like, and the one
## number a test can assert the whole design on.
func gap() -> float:
	if _player == null:
		return INF
	return global_position.distance_to(_player.global_position)


func _tick_surge(delta: float) -> void:
	if _warning_timer > 0.0:
		_warning_timer = maxf(_warning_timer - delta, 0.0)
		if _warning_timer <= 0.0:
			_begin_surge()
		return
	if state == State.SURGING:
		_surge_timer -= delta
		if _surge_timer <= 0.0:
			state = State.FOLLOWING
			_reattach = reattach_time
			surge_ended.emit()
		return
	# Not surging: the shrunken delay walks back up to the base one. move_toward
	# rather than a lerp so the recovery rate is a number in px... seconds per
	# second, readable in the inspector, instead of an exponent nobody can tune.
	read_delay = move_toward(read_delay, follow_delay, delay_recovery * delta)
	_reattach = maxf(_reattach - delta, 0.0)


func _begin_surge() -> void:
	if state != State.FOLLOWING:
		_pending_surge = Vector2.ZERO
		return
	var duration := _pending_surge.x
	var intensity := _pending_surge.y
	_pending_surge = Vector2.ZERO
	if duration <= 0.0:
		return
	state = State.SURGING
	_surge_timer = duration
	# The delay is shrunk immediately and recovers afterwards. It is what makes a
	# surge PERSIST: he ends the lunge genuinely closer, and the tape he goes back
	# to reading is the tape at the shorter delay.
	read_delay = follow_delay * (1.0 - intensity)
	surge_started.emit(duration, intensity)


## Following: stand where he stood. A straight write, no physics — see the header.
func _move_following(delta: float) -> void:
	if buffer.samples() == 0:
		return  # nothing recorded yet — stand still rather than snap to the origin
	var target := buffer.get_position_at_delay(read_delay)
	if _reattach > 0.0:
		# Just came off a surge and is not on the tape any more. Ease onto it over
		# reattach_time instead of snapping, which would read as a teleport.
		var t := clampf(delta / _reattach, 0.0, 1.0)
		global_position = global_position.lerp(target, t)
	else:
		global_position = target


## Surging: off the tape entirely, in a straight line at where the player IS.
## This is the only time he does something the player has not already done, which
## is exactly why it has to be telegraphed.
func _move_surging(delta: float) -> void:
	global_position = global_position.move_toward(
		_player.global_position, surge_speed * delta)


func _find_player() -> void:
	if is_instance_valid(_player):
		return
	_player = get_tree().get_first_node_in_group("player") as Player
	if _player != null and not _died_connected:
		# Every mid-chase respawn resets him, not just the ones he caused: dying
		# to a spike or the kill plane leaves the tape just as stale.
		_player.died.connect(_on_player_died)
		_died_connected = true


# ------------------------------------------------------------------ caught ---

## Overlap is re-derived every frame rather than taken off body_entered.
##
## Same reasoning as slide_zone.gd: the signal only fires when the boundary is
## CROSSED, and a respawn, a room load or a debug teleport can all put the two of
## them inside each other without a crossing. Asking the question fresh cannot
## get stuck on a stale answer.
func _check_catch() -> void:
	if _grace_timer > 0.0 or _owed_death != null:
		return
	if _player.state == Player.State.DEAD:
		return
	for body in get_overlapping_bodies():
		if body is Player:
			_catch(body as Player)
			return


func _catch(who: Player) -> void:
	state = State.CAUGHT
	_owed_death = who
	who.input_locked = true
	who.velocity = Vector2.ZERO
	caught_player.emit(who)
	_push_visual()
	await _play_ingestion(who)
	_resolve_catch()


## The ~1s animation, if the art exists; a plain wait of the same length if it
## does not. Either way the caller awaits exactly `ingest_time` worth of screen
## time, so the timing of the sequence never depends on whether the art has
## landed yet.
func _play_ingestion(who: Player) -> void:
	if _visual != null and _visual.has_method("ingest"):
		await _visual.ingest(who, ingest_time)
		return
	if is_inside_tree():
		await get_tree().create_timer(ingest_time).timeout


## Pay the death this node owes, exactly once.
##
## `_owed_death` is claimed and cleared before die() is called, so whichever of
## the two callers gets here first — the animation finishing, stop_chase(), or
## _exit_tree on a scene change — pays, and the others find nothing owed. That is
## the whole interruption guarantee, and it is deliberately one variable rather
## than a set of flags: see the comment above Player.die() for what the last
## death bug cost.
func _resolve_catch() -> void:
	var who := _owed_death
	_owed_death = null
	if who == null:
		return
	if state == State.CAUGHT:
		state = State.FOLLOWING
	if not is_instance_valid(who):
		return
	who.input_locked = false
	if who.state == Player.State.DEAD:
		return  # something else already killed him; die() would be a no-op anyway
	who.die()


# ---------------------------------------------------------------- respawn ----

## Every death during the chase, whoever caused it. The reset itself has to land
## AFTER the player is actually back — resetting while the corpse is still lying
## where it died would seed the tape with a position nobody is standing at.
##
## DORMANT is checked twice, before and after the wait, and both matter. This is
## connected to the player's `died` signal, and that player is shared by the
## whole Act: without the guard, a death in ANY room — a spike in room 3, a
## kill plane in room 8 — woke a shadow sitting dormant in room 11, teleported
## him to `respawn_gap` behind the player and started a chase in a room that has
## nothing to do with him. The slide and conveyor suites caught it as their
## player being frozen mid-ingestion two thousand pixels from where this node
## lives. A dormant shadow must be completely inert.
func _on_player_died() -> void:
	if state == State.DORMANT:
		return
	await _wait_for_respawn()
	if state == State.DORMANT:
		return  # the chase ended while the death was resolving
	if not is_instance_valid(_player) or not is_inside_tree():
		return
	reset_to_checkpoint(_player.global_position)


## Wait out the existing death/respawn (LdtkWorld holds for max(respawn_delay,
## player.death_time) and then calls player.respawn). Polled rather than timed so
## this cannot drift out of step with a level that holds longer.
func _wait_for_respawn() -> void:
	for i in 600:
		await get_tree().physics_frame
		if not is_instance_valid(_player):
			return
		if _player.state != Player.State.DEAD:
			return


## The player was MOVED rather than having moved: a room transition, a respawn,
## the debug picker. Treated exactly like a checkpoint respawn — he is placed the
## usual gap behind wherever the player now is, with the usual grace period.
##
## This is what lets the chase cross a room boundary without special-casing it:
## LdtkWorld._slide_to_room puts the player at the next room's spawn point in one
## frame, and a follower that replayed that jump would either walk the whole gap
## in a single step or spend the slide standing in the room he just left.
func _on_player_teleported(to: Vector2) -> void:
	if state == State.DORMANT or state == State.CAUGHT:
		return
	reset_to_checkpoint(to)


## Put the chase back to a survivable state around a player standing at `at`.
##
## The guarantee this exists to make: EVERY checkpoint state is survivable. He is
## placed at a fixed distance behind, the tape is reseeded with a path that leads
## to where the player actually is, the delay is back at base, he is FOLLOWING
## (never mid-surge), and contact cannot register for respawn_grace seconds.
func reset_to_checkpoint(at: Vector2) -> void:
	var back := route_direction.normalized() if route_direction != Vector2.ZERO \
		else Vector2.LEFT
	global_position = at - back * respawn_gap
	_seed_buffer_from(at)
	read_delay = follow_delay
	state = State.FOLLOWING
	_surge_timer = 0.0
	_warning_timer = 0.0
	_pending_surge = Vector2.ZERO
	_reattach = 0.0
	_grace_timer = respawn_grace
	_rearm_surge_points(at)
	_push_visual()
	chase_reset.emit(at)


## Seed the tape with a synthetic run-in, so the very first Following read puts
## him exactly where reset_to_checkpoint just placed him — no snap, no gap of
## zero. The trail speed is chosen so the sample at follow_delay IS respawn_gap
## behind: the two numbers cannot disagree because only one of them is typed in.
func _seed_buffer_from(at: Vector2) -> void:
	var back := route_direction.normalized() if route_direction != Vector2.ZERO \
		else Vector2.LEFT
	var trail_speed := respawn_gap / maxf(follow_delay, 0.0001)
	buffer.clear_and_seed(at, -back, trail_speed)


## Surge points the player has yet to reach again are made live again; ones he
## has already banked (behind the checkpoint along the route) stay spent.
##
## Without this a respawn past a surge point either re-fires it every single life
## — an unavoidable ambush on a checkpoint — or, resetting nothing, leaves the
## stretch AFTER the checkpoint permanently toothless.
func _rearm_surge_points(at: Vector2) -> void:
	var forward := route_direction.normalized() if route_direction != Vector2.ZERO \
		else Vector2.RIGHT
	for node in get_tree().get_nodes_in_group("surge_point"):
		if node is not SurgePointTrigger:
			continue
		var sp: SurgePointTrigger = node
		if forward.dot(sp.global_position - at) > 0.0:
			sp.rearm()


# ----------------------------------------------------------------- visual ----

## Detection-only overlap with the world layer.
##
## He passes through walls; this only REPORTS that he is doing it, so the art can
## swell as he comes through. It is an Area2D, which cannot push or be pushed, on
## a mask that touches layer 1 and nothing else — there is no arrangement of it
## that could move him, which is the property worth keeping.
func _build_probe() -> void:
	_probe = Area2D.new()
	_probe.name = "GeometryProbe"
	_probe.collision_layer = 0  # nothing detects the probe
	_probe.collision_mask = 1   # world geometry only
	var shape := CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	_probe.add_child(shape)
	add_child(_probe)
	_fit(shape, probe_size)
	_probe.body_entered.connect(_on_probe_changed)
	_probe.body_exited.connect(_on_probe_changed)


## Resize one of the two boxes. Null-tolerant because the exports have setters
## and Godot runs those while the scene is still being loaded, long before
## _ready() has built anything for them to write to.
func _fit(shape: CollisionShape2D, to: Vector2) -> void:
	if shape == null or shape.shape is not RectangleShape2D:
		return
	(shape.shape as RectangleShape2D).size = to.max(Vector2.ONE * 0.01)


func _on_probe_changed(_body: Node2D) -> void:
	# Recomputed from the overlap list rather than counted up and down: tilemap
	# layers report as one body each, and a shadow crossing a seam between two of
	# them would otherwise flicker "out" for a frame in the middle of a wall.
	var now := not _probe.get_overlapping_bodies().is_empty()
	if now == in_geometry:
		return
	in_geometry = now
	if _visual != null and _visual.has_method("set_inside_geometry"):
		_visual.set_inside_geometry(now)
	if now:
		entered_geometry.emit()
	else:
		left_geometry.emit()


## Tell the art what he is doing. It owns everything about how that looks; this
## only ever hands over the state and the velocity, both of which are facts the
## physics already knows.
func _push_visual() -> void:
	if _visual == null or not _visual.has_method("set_motion"):
		return
	var motion := Motion.IDLE
	match state:
		State.FOLLOWING:
			motion = Motion.MOVE
		State.SURGING:
			motion = Motion.SURGE
	_visual.set_motion(int(motion), velocity())


## His apparent velocity, px/s — derived from how far he moved last frame, since
## nothing here integrates one. A plain getter with no side effects: it used to
## advance `_last_pos` itself, which meant the number depended on how many times
## it had been asked for, and went wildly wrong the first frame after the art
## finally existed (the visual being absent had skipped every previous update).
func velocity() -> Vector2:
	return _velocity


func _attach_visual() -> void:
	if _visual != null or not ResourceLoader.exists(VISUAL_SCENE):
		return
	var packed := load(VISUAL_SCENE) as PackedScene
	if packed == null:
		return
	_visual = packed.instantiate() as Node2D
	if _visual == null:
		return
	add_child(_visual)
