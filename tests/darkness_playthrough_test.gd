extends Node
## Entrance-to-exit attempts. All traversal and pad use is real input. A failed
## attempt restarts at the room entrance, never at the next platform.
var world:LdtkWorld
var player:Player
var chamber:Node2D
var room:Node2D
var config:Dictionary
var inputs:Dictionary
var index:=0
var variant:=0
var died:=false
var failures:Array[String]=[]
func frames(n:int)->void:
	for i in n:await get_tree().physics_frame
func release()->void:
	for a in ["move_left","move_right","move_up","move_down","jump","dash"]:Input.action_release(a)
func _ready()->void:
	SaveGame.slot=-1
	LdtkWorld.debug_start_room="Level_V10"
	world=load("res://ldtk/Act1World.tscn").instantiate()
	add_child(world)
	await frames(8)
	player=world.player;player.has_dash=true
	player.died.connect(func():died=true)
	inputs=JSON.parse_string(FileAccess.get_file_as_string("res://tests/data/darkness_route_inputs.json"))
	var configs:Array=JSON.parse_string(FileAccess.get_file_as_string("res://resources/levels/act1_expansion.json"))
	for c:Dictionary in configs:
		# These movement courses have a separate continuous-input acceptance run.
		if c.get("precision_escape",false):continue
		if get_script().resource_path.ends_with("darkness_playthrough_test.gd") and c.encounter.get("continuous_chase",false):continue
		if not OS.get_cmdline_user_args().is_empty() and c.name not in OS.get_cmdline_user_args():continue
		config=c
		for r in world.rooms:
			if r.name==c.name:room=r
		var passed:=false
		for attempt in (20 if c.has("ladders") else 16):
			variant=attempt;release()
			world._enter_room(room,true)
			CrumblingPlatform.reset_all(get_tree())
			chamber=room.get_node("DarknessRoom")
			await frames(12+attempt*25)
			player.has_dash=true;index=0;died=false
			passed=await solve()
			if passed and not died:
				passed=await go(config.route.size()-1)
				if passed and world.current_room==room:
					Input.action_press("move_left" if c.direction<0 else "move_right")
					for i in 180:
						await frames(1)
						if world.current_room!=room or died:break
					passed=world.current_room==world._room_after(room) and not died
			release()
			if passed:break
			print("RETRY ",c.name," attempt ",attempt," index ",index," at ",player.global_position-room.global_position," step ",chamber.step," seal ",chamber.seal_index)
			await frames(100)
		print("PASS " if passed else "FAIL ",c.name," complete puzzle and exit")
		if not passed:failures.append(c.name)
		release();await frames(100)
	print("DARKNESS PLAYTHROUGH: %d failures" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
func pad_index(p:Array)->int:
	var best:=0;var distance:=INF
	for i in config.route.size():
		var r:Array=config.route[i]
		var d:=Vector2(r[0]+r[2]/2.0,r[1]).distance_to(Vector2(p[0],p[1]))
		if d<distance:best=i;distance=d
	return best
func solve()->bool:
	var e:Dictionary=chamber.e
	match str(e.mode):
		"security":
			for i in e.terminals.size():
				if not await go(pad_index(e.terminals[i])):return false
				if not await walk_x(float(e.terminals[i][0])):return false
				release();await frames(60)
				if chamber.step!=i+1:return false
		"watch","still":
			if not await go(1):return false
			release()
			for i in 1200:
				await frames(1)
				if chamber.solved or died:break
		"sequence":
			for i in e.pads.size():
				if not await go(pad_index(e.pads[i])):return false
				release();await frames(28)
				if chamber.step!=i+1:return false
		"phase":
			for i in e.phase_pads.size():
				if not await go(pad_index(e.phase_pads[i])):return false
				release()
				for f in 1400:
					await frames(1)
					if chamber.step>i or died:break
				if chamber.step<=i:return false
		"pulse":
			if not await walk_x(float(e.anchor[0])-12):return false
			if not await wait_warning("pulse"):return false
			if not await go(2):return false
			release()
			for i in 600:
				await frames(1)
				if chamber.solved or died:break
		"mark","sweep","final":
			var target:=pad_index(e.seal)
			if not await go(target):return false
			if not await wait_warning("mark"):return false
			if not await go(target-1):return false
			release()
			for i in 150:
				await frames(1)
				if chamber.seal_index>0 or died:break
			if chamber.seal_index==0:return false
			if e.has("targets"):
				if not await go(0):return false
				if not await walk_x(float(e.anchor[0])-4):return false
				if not await wait_warning("pulse"):return false
				if not await go(1):return false
				release()
				for i in 500:
					await frames(1)
					if chamber.seal_broken or died:break
			if e.mode=="sweep":
				if not await go(1):return false
				release()
				for i in 1800:
					await frames(1)
					if chamber.solved or died:break
			if e.mode=="final":
				if not await go(1):return false
				release()
				for i in 1200:
					await frames(1)
					if chamber.phase==3 or chamber.phase==0 or died:break
				if not await go(2):return false
				release()
				for i in 500:
					await frames(1)
					if chamber.solved or died:break
	await frames(2)
	if chamber.solved:
		for i in 100:
			if chamber.gate_shape.disabled:break
			await frames(1)
	return chamber.solved and not died
func wait_warning(kind:String)->bool:
	release()
	for i in 2000:
		await frames(1)
		if died:return false
		if chamber.warning_left>1 and chamber.attack_kind==kind:return true
	return false
func walk_x(local_x:float)->bool:
	var target:float=room.global_position.x+local_x
	for i in 600:
		var dx:=target-player.global_position.x
		if absf(dx)<2:release();return true
		Input.action_release("move_left");Input.action_release("move_right")
		Input.action_press("move_right" if dx>0 else "move_left")
		await frames(1)
		if died:return false
	if player.get_slide_collision_count()>0:print("WALK BLOCK ",player.get_last_slide_collision().get_collider())
	return false
func go(target:int)->bool:
	if config.has("ladders"):
		release();await frames(variant*17)
		if index!=target and not await leg(target):return false
		index=target
		return not died
	while index!=target:
		var next:=index+signi(target-index)
		if not await leg(next):return false
		index=next
	return not died
func crumbling(i:int)->bool:
	for item in config.get("crumbles",[]):
		if int(item)==i:return true
	return false
func leg(next:int)->bool:
	if config.has("ladders") and next>0:
		var landing_x:float=config.route[next][0]+config.route[next][2]/2.0
		for deck:Array in config.route:
			if deck[1]<config.route[next][1] and landing_x>deck[0] and landing_x<deck[0]+deck[2]:
				return await ladder_leg(next)
		if config.route[next][1]<config.route[index][1] or absf(config.route[next][0]-config.route[index][0])>160:
			return await ladder_leg(next)
	if config.encounter.get("boss",false):
		release();await frames(variant*7)
		if died:return false
	var a:Array=config.route[index];var b:Array=config.route[next]
	var direction:=signf(float(b[0])+float(b[2])/2-float(a[0])-float(a[2])/2)
	if chamber.phase_door!=null:
		var door_x:float=chamber.phase_door.position.x
		if (float(a[0])+float(a[2])/2-door_x)*(float(b[0])+float(b[2])/2-door_x)<0:
			release()
			for i in 1600:
				await frames(1)
				if chamber.phase==2 and chamber.phase_time<3:break
				if died:return false
	var inset:=8.0
	if config.name=="Level_25" and next==config.route.size()-1:inset=32
	var takeoff:float=a[0]+a[2]-inset if direction>0 else a[0]+inset
	if not crumbling(index) and not await walk_x(takeoff):return false
	if not crumbling(index):await frames(5)
	var timing:int=12 if b[1]<a[1] else -1
	if not config.has("ladders") and next>index:timing=int(inputs[config.name][index])

	var landing_x:float=b[0]+b[2]/2.0
	if crumbling(next):landing_x=b[0]+16 if direction<0 else b[0]+b[2]-16
	var dest:=room.global_position+Vector2(landing_x,b[1]-6)
	Input.action_press("jump")
	for i in 110:
		var dx:=dest.x-player.global_position.x
		Input.action_release("move_left");Input.action_release("move_right")
		if absf(dx)>2:Input.action_press("move_right" if dx>0 else "move_left")
		if i==14:Input.action_release("jump")
		if i==timing:
			if b[1]<a[1]:Input.action_press("move_up")
			Input.action_press("dash")
		if i==timing+1:Input.action_release("dash");Input.action_release("move_up")
		await frames(1)
		if died:return false
		if world.current_room!=room:release();return true
		if i>18 and player.is_on_floor() and absf(player.global_position.y-dest.y)>3:
			Input.action_press("jump")
		if i>3 and player.is_on_floor() and absf(player.global_position.y-dest.y)<3 and absf(player.global_position.x-dest.x)<12:
			release();return true
	return false

## Ladder routes use their authored rails instead of the old jump-only replay.
func ladder_leg(next:int)->bool:
	var rail:Array=config.ladders[next-1]
	var dest:Array=config.route[next]
	# Drop from the departing deck onto the recovery floor if necessary. No
	# teleporting: the same steering carries him over gaps and into the shaft.
	if chamber.phase_door!=null and (player.global_position.x-room.global_position.x-200)*(float(rail[0])-200)<0:
		release()
		for i in 1600:
			await frames(1)
			if world.current_room!=room:release();return true
			if died:return false
			if chamber.phase==2 and chamber.phase_time<1:break
	if not await walk_x(float(rail[0])):return false
	release()
	Input.action_press("move_up")
	await frames(4)
	Input.action_release("move_up")
	for f in 900:
		if climb_window(rail,dest):break
		await frames(1)
		if world.current_room!=room:release();return true
		if died:return false
	var descending:bool=player.global_position.y-room.global_position.y<float(dest[1])-18
	for f in 320:
		Input.action_press("move_down" if descending else "move_up")
		await frames(1)
		if world.current_room!=room:release();return true
		if died:return false
		if player.state==Player.State.CLIMB:
			var y:float=player.global_position.y-room.global_position.y
			if (descending and y>=float(dest[1])-18) or (not descending and y<=float(dest[1])-18):break
	Input.action_release("move_up");Input.action_release("move_down")
	if player.state!=Player.State.CLIMB:return false
	Input.action_press("move_right");Input.action_press("jump")
	for f in 120:
		var dx:float=room.global_position.x+dest[0]+dest[2]/2.0-player.global_position.x
		Input.action_release("move_left");Input.action_release("move_right")
		if absf(dx)>2:Input.action_press("move_right" if dx>0 else "move_left")
		if f==12:Input.action_release("jump")
		await frames(1)
		if world.current_room!=room:release();return true
		if died:return false
		if f>3 and player.is_on_floor() and absf(player.global_position.y-room.global_position.y-(float(dest[1])-6))<3 and absf(dx)<4:
			release();return true
	release();return false

# Choose an observable opening in the periodic patrol, then execute the climb
# with ordinary input. Prediction never disables, freezes, or moves a hazard.
func climb_window(rail:Array,dest:Array)->bool:
	var start_y:float=player.global_position.y-room.global_position.y
	var end_y:float=dest[1]-18
	var duration:float=absf(start_y-end_y)/player.climb_speed
	for n in int(ceil((duration+.45)/.04)):
		var t:float=n*.04
		var p:=Vector2(float(rail[0]),move_toward(start_y,end_y,t*player.climb_speed))
		if t>duration:
			var j:=t-duration
			p.x+=minf(j*player.max_run_speed,float(dest[0])+float(dest[2])/2-float(rail[0]))
			p.y=minf(float(dest[1])-6,end_y-81*j+450*j*j)
		for h in get_tree().get_nodes_in_group("dark_thought"):
			if not room.is_ancestor_of(h):continue
			var hp:Vector2=h.global_position-room.global_position-h._offset(h._clock)+h._offset(h._clock+t)
			if absf(hp.x-p.x)<15 and absf(hp.y-p.y)<14:return false
	return true
