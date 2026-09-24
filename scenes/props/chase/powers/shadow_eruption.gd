extends Node2D
const POWER_GATE = preload("res://scenes/props/chase/powers/power_gate.gd")
## The placed rectangle is exactly the lethal volume; its bottom is the surface.
@export var size := Vector2(32,8)
@export var encounter_id := "A"
@export var sequence := 0
@export var warning_time := .8
@export var active_time := .55
## Aim only along the authored platform, then lock before the warning draws.
@export var targeting_radius := 64.0
var anchor_position := Vector2.ZERO
var target_locked := false
var elapsed := -1.0
var delay := 0.0
var player: Player
var world: LdtkWorld

func _ready() -> void:
	anchor_position = position
	add_to_group("shadow_eruption")
	var ancestor := get_parent()
	while ancestor != null:
		if ancestor is LdtkWorld:
			world = ancestor
			break
		ancestor = ancestor.get_parent()

func reset() -> void:
	position = anchor_position
	target_locked = false
	elapsed = -1
	queue_redraw()

func activate(wait: float = 0) -> bool:
	var caster: Darkshang = POWER_GATE.caster_for(self)
	if caster == null or not caster.powers_available(): return false
	if elapsed >= 0: return false
	delay = maxf(0,wait)
	elapsed = 0
	target_locked = false
	queue_redraw()
	return true

func is_lethal() -> bool:
	return elapsed >= delay+maxf(.15,warning_time) and elapsed < delay+maxf(.15,warning_time)+maxf(.05,active_time)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Player
		if player != null: player.died.connect(reset)
	if world != null and ((world.current_room == null or not world.current_room.is_ancestor_of(self)) or world.transition_target != null):
		reset()
		return
	if player == null or player.state == Player.State.DEAD or player.input_locked: return
	if elapsed < 0: return
	if not target_locked and elapsed + delta >= delay:
		_lock_target()
	elapsed += delta
	if is_lethal() and Rect2(global_position-size/2,size).intersects(player.hitbox_rect()):
		player.die()
	if elapsed >= delay+maxf(.15,warning_time)+maxf(.05,active_time): reset()
	queue_redraw()

func _lock_target() -> void:
	target_locked = true
	if targeting_radius <= 0 or player == null: return
	var anchor: Vector2 = get_parent().to_global(anchor_position)
	var desired := clampf(player.global_position.x, anchor.x-targeting_radius, anchor.x+targeting_radius)
	# Sweep continuously from the placed strip. Never jump a gap onto another
	# landing or target a checkpoint. The complete footprint needs support.
	var best := anchor
	var step := signf(desired-anchor.x)
	for i in range(1, int(absf(desired-anchor.x))+1):
		var candidate := anchor + Vector2(step*i,0)
		if not _supported_target(candidate): break
		best = candidate
	global_position = best

func _supported_target(at: Vector2) -> bool:
	var space := get_world_2d().direct_space_state
	var volume := Rect2(at-size/2,size)
	for sibling in get_parent().get_children():
		if sibling != self and sibling.is_in_group("shadow_eruption") and sibling.elapsed >= 0:
			if volume.grow(4).intersects(Rect2(sibling.global_position-sibling.size/2,sibling.size)): return false
		if sibling is Checkpoint and volume.intersects(Rect2(sibling.global_position-Vector2(8,8),Vector2(16,16))):
			return false
	if world != null and not world.room_rect(world.current_room).encloses(volume): return false
	var probe := PhysicsShapeQueryParameters2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size-Vector2(.2,.2)
	probe.shape = shape
	probe.transform = Transform2D(0,at)
	probe.collision_mask = 1
	if not space.intersect_shape(probe,1).is_empty(): return false
	for x in range(int(size.x)):
		var foot := at+Vector2(-size.x/2+x+.5,size.y/2)
		var query := PhysicsRayQueryParameters2D.create(foot-Vector2(0,.1),foot+Vector2(0,1),1)
		if space.intersect_ray(query).is_empty(): return false
	return true

func _draw() -> void:
	if elapsed < delay or elapsed < 0: return
	var corner := -size/2
	if not is_lethal():
		draw_rect(Rect2(corner,size),Color(.7,.3,.5,.15))
		draw_rect(Rect2(corner,size),Color("df99b7"),false,1)
		for x in range(0,int(size.x),4):
			draw_line(corner+Vector2(x,size.y),corner+Vector2(x+2,size.y-3),Color("efbfd0"),1)
	else:
		for x in range(0,int(size.x),4):
			var points := PackedVector2Array([corner+Vector2(x,size.y),corner+Vector2(minf(x+2,size.x),0),corner+Vector2(minf(x+4,size.x),size.y)])
			draw_colored_polygon(points,Color("28172f"))
			draw_polyline(points,Color("d18cae"),1)
