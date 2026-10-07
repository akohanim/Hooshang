extends Node2D
## Movement is ticked by Darkshang, so pursuit and charge never move him together.
enum Phase { IDLE, WARNING, CHARGE, RECOVERY, APPROACH }
var phase := Phase.IDLE
var direction := Vector2.RIGHT
var remaining := 0.0
var speed := 240.0
var distance_left := 240.0
var recovery := 0.7
var staged := false
## Cloud encounters vanish after a miss and return to the saved launch point.
var return_to_launch := false
var launch_position := Vector2.ZERO
var warning_duration := 0.0
var transition_from := Vector2.ZERO
var transition_elapsed := 0.0
var locked_target := Vector2.ZERO
var minimum_range := 0.0
var track_player_height := false
var box := RectangleShape2D.new()

func begin(aim: Vector2, warning: float, travel_speed: float, distance: float, rest: float) -> bool:
	if phase != Phase.IDLE:
		return false
	staged = false
	return_to_launch = false
	track_player_height = false
	direction = aim.normalized() if aim != Vector2.ZERO else Vector2.RIGHT
	speed = maxf(1, travel_speed)
	distance_left = maxf(1, distance)
	minimum_range = distance_left
	recovery = maxf(.05, rest)
	remaining = maxf(.15, warning)
	phase = Phase.WARNING
	queue_redraw()
	return true

func stage(actor: Node2D) -> void:
	staged = true
	warning_duration = remaining
	minimum_range = distance_left
	transition_from = actor.global_position
	transition_elapsed = 0
	phase = Phase.APPROACH

func _hover(delta: float, actor: Node2D) -> void:
	var target: Vector2 = actor.charge_hover_position()
	actor.global_position.x = target.x if return_to_launch else lerpf(actor.global_position.x,target.x,1.0-exp(-10.0*delta))
	var view: Rect2 = actor.charge_view_rect()
	if view.has_area(): actor.global_position.x = clampf(actor.global_position.x,view.position.x+.1,view.end.x-.1)

func _track_lane(actor: Node2D, player: Player) -> void:
	actor.global_position.y = player.global_position.y
	locked_target = player.global_position
	direction = Vector2.LEFT if staged or player.global_position.x <= actor.global_position.x else Vector2.RIGHT
	distance_left = maxf(minimum_range,absf(locked_target.x-actor.global_position.x)+160)

func cancel() -> void:
	phase = Phase.IDLE
	queue_redraw()

func tick(delta: float, actor: Node2D, player: Player) -> bool:
	if phase == Phase.IDLE:
		return false
	if staged and phase == Phase.APPROACH:
		transition_elapsed += delta
		var t := clampf(transition_elapsed/.45,0,1)
		actor.global_position = transition_from.lerp(actor.charge_hover_position(),smoothstep(0,1,t))
		var view: Rect2 = actor.charge_view_rect()
		if view.has_area(): actor.global_position = actor.global_position.clamp(view.position+Vector2(.1,.1),view.end-Vector2(.1,.1))
		actor.global_position.y = player.global_position.y
		if t >= 1:
			_track_lane(actor,player)
			remaining = warning_duration
			phase = Phase.WARNING
		queue_redraw()
		return true
	if staged and phase == Phase.WARNING:
		_hover(delta,actor)
	if track_player_height and phase == Phase.WARNING:
		_track_lane(actor,player)
	if staged and phase == Phase.RECOVERY and not return_to_launch:
		transition_elapsed += delta
		var t := clampf(transition_elapsed/recovery,0,1)
		actor.global_position = transition_from.lerp(actor.charge_return_position(),smoothstep(0,1,t))
	if phase == Phase.WARNING or phase == Phase.RECOVERY:
		remaining -= delta
		if remaining <= 0:
			if phase == Phase.WARNING:
				launch_position = actor.global_position
				phase = Phase.CHARGE
			else:
				if return_to_launch: actor.global_position = launch_position
				phase = Phase.IDLE
		queue_redraw()
		return true
	var motion := direction * minf(speed * delta, distance_left)
	if catch_along(actor, player, motion): return true
	actor.global_position += motion
	distance_left -= motion.length()
	if distance_left <= .01:
		phase = Phase.RECOVERY
		transition_from = actor.global_position
		transition_elapsed = 0
		remaining = recovery
	queue_redraw()
	return true

## Shared sweep for authored charges and the older SurgeZone attacks.
func catch_along(actor: Node2D, player: Player, motion: Vector2) -> bool:
	box.size = actor.charge_catch_size
	# A spectral charge crosses terrain, like pursuit, so ledges cannot cut
	# it short before the locked target. The warning shows the entire path.
	var start: Vector2 = actor.global_position + actor.charge_catch_offset
	var finish := start + motion
	# Segment against an expanded player box: no tunnelling or diagonal AABB kills.
	if is_instance_valid(player) and not player.input_locked and player.state != Player.State.DEAD:
		var target := player.hitbox_rect().grow_individual(box.size.x/2, box.size.y/2, box.size.x/2, box.size.y/2)
		if target.has_point(start) or _segment_hits(start, finish, target):
			# Stop at the victim for the existing ingestion animation.
			actor.global_position = Geometry2D.get_closest_point_to_segment(player.global_position, start, finish) - actor.charge_catch_offset
			cancel()
			actor._catch(player)
			return true
	return false

func _segment_hits(a: Vector2, b: Vector2, rect: Rect2) -> bool:
	var corners := [rect.position, Vector2(rect.end.x,rect.position.y), rect.end, Vector2(rect.position.x,rect.end.y)]
	for i in 4:
		if Geometry2D.segment_intersects_segment(a,b,corners[i],corners[(i+1)%4]) != null:
			return true
	return rect.has_point(b)

func _draw() -> void:
	if phase == Phase.WARNING:
		draw_line(Vector2.ZERO, direction * distance_left, Color("e6a0b8"), 1)
		for d in range(8, int(distance_left), 12):
			var at := direction * d
			draw_line(at-direction.rotated(PI/2)*2, at+direction.rotated(PI/2)*2, Color("e6a0b8"), 1)
	elif phase == Phase.RECOVERY and not return_to_launch:
		draw_arc(Vector2.ZERO, 12, 0, TAU, 16, Color("e6a0b8"), 1)
