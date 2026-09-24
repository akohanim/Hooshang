class_name DarkshangCloud
extends Node2D
## A horizontal shot that sweeps its whole hitbox against world geometry.
## No range timer: only a solid wall, room edge, or encounter reset removes it.
## Travel speed in native pixels per second.
@export var speed := 112.0
## Signed horizontal travel direction.
@export var direction := -1.0
var room_bounds := Rect2()
var player: Player
var stopped := false
var distance_travelled := 0.0
var clock := 0.0
var hit_size := Vector2(16,10)
var box := RectangleShape2D.new()
signal hit_wall(at:Vector2)

func _ready()->void:
	box.size=hit_size

func _physics_process(delta:float)->void:
	if stopped:return
	clock+=delta
	$Sprite.frame=int(clock/.12)%4
	var motion:=Vector2(direction*speed*delta,0)
	var query:=PhysicsShapeQueryParameters2D.new()
	query.shape=box
	query.transform=Transform2D(0,global_position)
	query.collision_mask=1
	query.collide_with_areas=false
	query.margin=.01
	var space:=get_world_2d().direct_space_state
	# cast_motion ignores initial overlaps; reject those explicitly as well.
	if not space.intersect_shape(query,1).is_empty():
		_stop();return
	query.motion=motion
	var travel:=space.cast_motion(query)
	var fraction:float=travel[0] if not travel.is_empty() else 1.0
	var boundary:float=room_bounds.end.x-hit_size.x/2 if direction>0 else room_bounds.position.x+hit_size.x/2
	if absf(motion.x)>0:
		fraction=minf(fraction,clampf((boundary-global_position.x)/motion.x,0,1))
	var next:=global_position+motion*fraction
	var swept:=Rect2(Vector2(minf(global_position.x,next.x)-hit_size.x/2,global_position.y-hit_size.y/2),Vector2(absf(next.x-global_position.x)+hit_size.x,hit_size.y))
	if is_instance_valid(player) and not player.input_locked and swept.intersects(player.hitbox_rect()):player.die()
	distance_travelled+=global_position.distance_to(next)
	global_position=next
	if fraction<1:_stop()

func _stop()->void:
	stopped=true
	hit_wall.emit(global_position)
	queue_free()
