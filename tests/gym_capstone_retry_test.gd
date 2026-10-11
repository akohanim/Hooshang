extends Node
## Staged contacts and failure states; earned routes are tested separately.
var failures := 0
func frames(n: int) -> void:
	for i in n:await get_tree().physics_frame
func check(ok: bool,label: String) -> void:
	if not ok:
		failures+=1
		push_error(label)
func _ready() -> void:
	SaveGame.unbind()
	LdtkWorld.debug_start_room="Prison_Y03"
	Screen.load_scene("res://ldtk/Act2World.tscn")
	await frames(20)
	var world=Screen.current
	var room=world.current_room
	check(world.collected.is_empty(),"spawn cannot touch the enclosed Gold key")
	check(world.timers.active("gym_ascent"),"initial plate starts ascent")
	world.player.respawn(room.global_position+Vector2(232,114))
	await frames(8)
	check(world.timers.solved("gym_ascent"),"real midpoint contact banks first phrase")
	var second=world.props.filter(func(p):return p.kind=="TimedShutter" and p.puzzle_id=="gym_reverse" and p.get_parent().get_parent()==room)[0]
	var hit:=KinematicCollision2D.new()
	check(world.player.test_move(Transform2D(0,room.global_position+Vector2(64,154)),Vector2(0,-30),hit) and hit.get_collider()==second.get_node("Barrier"),"first phrase alone cannot expose key")
	world.player.respawn(room.global_position+Vector2(256,114))
	await frames(8)
	check(world.timers.active("gym_reverse"),"second plate starts upper crossing")
	var stone=room.get_node("Entities").get_children().filter(func(p):return p is CrumblingPlatform and p.position.x==248)[0]
	world.player.respawn(room.global_position+Vector2(248,50))
	await frames(100)
	check(stone._spent,"staged stone contact exercises actual collapse")
	world.player.respawn(room.global_position+Vector2(280,114))
	await frames(520)
	check(not world.timers.active("gym_reverse"),"upper timer expires away from its plate")
	var deaths: Array=[]
	world.player.died.connect(func():deaths.append(true))
	var event:=InputEventAction.new()
	event.action="respawn";event.pressed=true;Input.parse_input_event(event)
	await frames(1)
	event=InputEventAction.new();event.action="respawn";event.pressed=false;Input.parse_input_event(event)
	await frames(100)
	check(deaths.size()==1 and not stone._spent,"retry input counts one death and restores the collapsed stone")
	check(world.timers.solved("gym_ascent") and not world.timers.active("gym_reverse"),"death retains first phrase and clears second attempt")
	check(world.player.global_position.distance_to(room.global_position+Vector2(112,154))<3,"failure respawns at safe entrance")
	world.player.respawn(room.global_position+Vector2(256,114))
	await frames(8)
	world.player.respawn(room.global_position+Vector2(88,58))
	await frames(8)
	check(world.timers.solved("gym_reverse") and second.barrier.disabled,"real upper seal opens remaining key roof")
	world.player.die()
	await frames(90)
	check(world.timers.solved("gym_ascent") and world.timers.solved("gym_reverse"),"both phrases persist across death")
	world.queue_free()
	await frames(3)
	print("GYM CAPSTONE RETRY: ",failures," failures")
	get_tree().quit(1 if failures else 0)
