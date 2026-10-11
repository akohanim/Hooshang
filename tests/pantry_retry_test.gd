extends Node
## Deliberately staged failure states; route earning is covered separately.
var failures := 0
func frames(n: int) -> void:
	for i in n: await get_tree().physics_frame
func check(ok: bool, label: String) -> void:
	if not ok:
		failures+=1
		push_error(label)
func _ready() -> void:
	SaveGame.unbind()
	LdtkWorld.debug_start_room="Prison_R03"
	Screen.load_scene("res://ldtk/Act2World.tscn")
	await frames(20)
	var world=Screen.current
	var room=world.current_room
	var shelf=world.props.filter(func(p):return p.kind=="CrumblingShelf" and p.get_parent().get_parent()==world.current_room)[0]
	var first="cafeteria_pantry_shelf"
	var second="cafeteria_pantry_upper"
	# Staged landing uses the current stone, then real contact and gravity.
	var initial_deaths: Array=[]
	world.player.died.connect(func():initial_deaths.append(true))
	world.player.respawn(shelf.global_position+Vector2(0,-22))
	for i in 120:
		await frames(1)
		if shelf._falling:break
	check(shelf._spent and shelf._falling and not shelf.get_collision_layer_value(1),"footfall collapses service stone")
	await frames(90)
	check(initial_deaths.size()==1,"missed departure causes one real pit death")
	check(world.player.global_position.distance_to(room.global_position+Vector2(40,154))<3,"missed departure respawns safely")
	check(not shelf._spent and shelf.get_collision_layer_value(1),"pit death restores stone")
	world.player.respawn(room.global_position+Vector2(40,154))
	await frames(5)
	Input.action_press("move_up")
	await frames(4)
	Input.action_release("move_up")
	check(world.timers.active(first) and not shelf._spent and shelf.get_collision_layer_value(1),"real lever restores shelf for retry without death")
	world.timers.bank(first)
	await frames(4)
	var hit:=KinematicCollision2D.new()
	check(world.player.test_move(Transform2D(0,room.global_position+Vector2(288,118)),Vector2(0,40),hit),"first seal alone does not expose key")
	var shutter=world.props.filter(func(p):return p.kind=="TimedShutter" and p.get_parent().get_parent()==room and p.puzzle_id==second)[0]
	check(hit.get_collider()==shutter.get_node("Barrier"),"second banked shutter is the actual key blocker")
	world.timers.start(second)
	world.player.die()
	await frames(90)
	check(world.timers.solved(first) and not world.timers.active(second),"death retains midpoint and resets second attempt")
	check(not shelf._spent and shelf.get_collision_layer_value(1),"death restores crumble collision")
	# The room reset restores a spent shelf even when its lever is already banked.
	shelf.give_way()
	await frames(5)
	check(shelf._falling,"fixture spends completed-section shelf")
	var other=world.rooms.filter(func(r):return str(r.name)=="Prison_R02")[0]
	world._enter_room(other,true)
	world._enter_room(room,true)
	await frames(4)
	check(not shelf._spent and shelf.get_collision_layer_value(1),"room re-entry restores shelf")
	check(world.timers.solved(first),"room re-entry retains midpoint")
	shelf.give_way()
	await frames(5)
	world.player.respawn(room.global_position+Vector2(40,154))
	await frames(5)
	Input.action_press("move_up")
	await frames(4)
	Input.action_release("move_up")
	check(not shelf._spent and world.timers.solved(first),"completed lever still restores temporary footing")
	check(world.collected.is_empty(),"failure fixtures never grant key")
	var patrol=world.props.filter(func(p):return p.kind=="Patrol" and p.get_parent().get_parent()==room)[0]
	var hits: Array = []
	world.player.died.connect(func():hits.append(true))
	patrol.clock=PI/4.0
	world.player.respawn(room.global_position+Vector2(288,90))
	world.player.invulnerable_timer=0.0
	await frames(30)
	check(hits.size()==1,"low patrol phase actually threatens the dash lane")
	print("PANTRY RETRY: ",failures," failures")
	get_tree().quit(1 if failures else 0)
