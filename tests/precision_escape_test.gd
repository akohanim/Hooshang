extends Node
## Real-controller acceptance for the ten precision rooms. Discovery isolates
## individual legs; replay starts only at the entrance and uses live hazards,
## checkpoints, note contacts and the real exit without mid-route teleports.
var world:LdtkWorld
var player:Player
var room:Node2D
var config:Dictionary
var died:=false
var failures:Array[String]=[]
var solutions:Dictionary={}
var discover:=false
func frames(n:int)->void:
	for i in n:await get_tree().physics_frame
func release()->void:
	for a in ["move_left","move_right","move_up","move_down","jump","dash"]:Input.action_release(a)
func check(ok:bool,label:String)->void:
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func _ready()->void:
	SaveGame.slot=-1
	LdtkWorld.debug_start_room="Level_15"
	discover="--discover" in OS.get_cmdline_user_args()
	world=load("res://ldtk/Act1World.tscn").instantiate();add_child(world)
	await frames(12)
	player=world.player;player.has_dash=true
	player.died.connect(func():died=true)
	if discover:
		player.died.disconnect(world._on_player_died)
		for exit in get_tree().get_nodes_in_group("exit"):exit.set_deferred("monitoring",false)
	else:
		solutions=JSON.parse_string(FileAccess.get_file_as_string("res://tests/data/precision_escape_inputs.json"))
	var configs:Array=JSON.parse_string(FileAccess.get_file_as_string("res://resources/levels/act1_expansion.json"))
	for c:Dictionary in configs:
		if not c.get("precision_escape",false):continue
		var selected:=OS.get_cmdline_user_args()
		if selected.size()>(1 if discover else 0) and c.name not in selected:continue
		config=c
		for r in world.rooms:
			if r.name==c.name:room=r
		world._enter_room(room,true);await frames(8)
		player.has_dash=true
		if discover:
			get_tree().get_first_node_in_group("darkshang").stand_by()
			room.get_node("DarknessRoom").set_physics_process(false)
			await find_legs()
		else:await replay()
		release()
	if discover:
		FileAccess.open("res://output/precision_escape/discovered_inputs.json",FileAccess.WRITE).store_string(JSON.stringify(solutions,"  "))
	print("PRECISION ESCAPE: %d failures" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
func find_legs()->void:
	var found:Array=[]
	for i in config.route.size()-1:
		var solved:=false
		var a:Array=config.route[i];var b:Array=config.route[i+1]
		# [jump hold, dash frame, dash aim (-1=up), takeoff inset].
		var candidates:Array=[]
		for hold in [14,6,0]:
			candidates.append([hold,-1,0,8])
			for timing in [10,14,18,6,22,26]:
				candidates.append([hold,timing,-1 if b[1]<a[1] else 0,8])
		for move:Array in candidates:
			release();CrumblingPlatform.reset_all(get_tree())
			var dir:=signf(float(b[0])+float(b[2])/2-float(a[0])-float(a[2])/2)
			var x:float=a[0]+(float(a[2])-float(move[3]) if dir>0 else float(move[3]))
			player.respawn(room.global_position+Vector2(x,float(a[1])-6));player.has_dash=true
			await frames(3);died=false
			if await transfer(i,move,false):found.append(move);solved=true;break
		check(solved,"%s leg %d reachable" % [config.name,i+1])
		if not solved:
			print("UNREACHABLE ",a," -> ",b," end ",player.global_position-room.global_position)
			found.append([])
	solutions[config.name]=found
func walk_x(x:float)->bool:
	for f in 180:
		var dx:=room.global_position.x+x-player.global_position.x
		if absf(dx)<1.5:release();return true
		steer(dx)
		await frames(1)
		if died:return false
	return false
func steer(dx:float)->void:
	Input.action_release("move_left");Input.action_release("move_right")
	if absf(dx)>1.5:Input.action_press("move_left" if dx<0 else "move_right")
func transfer(index:int,move:Array,walk:bool)->bool:
	var a:Array=config.route[index];var b:Array=config.route[index+1]
	var dir:=signf(float(b[0])+float(b[2])/2-float(a[0])-float(a[2])/2)
	if walk:
		var x:float=a[0]+(float(a[2])-float(move[3]) if dir>0 else float(move[3]))
		if not await walk_x(x):return false
	var target:=room.global_position+Vector2(float(b[0])+float(b[2])/2,float(b[1])-6)
	release()
	for f in 120:
		steer(target.x-player.global_position.x)
		if f==0 and int(move[0])>0:Input.action_press("jump")
		if f==int(move[0]):Input.action_release("jump")
		if f==int(move[1]):
			if int(move[2])<0:Input.action_press("move_up")
			Input.action_press("dash")
		# Hold the aim through the physics tick that consumes the dash press.
		# Releasing it on the very next signal samples a flat dash instead.
		if f==int(move[1])+3:Input.action_release("dash");Input.action_release("move_up")
		await frames(1)
		if died:release();return false
		if world.current_room!=room:release();return true
		if f>3 and player.is_on_floor() and absf(player.global_position.y-target.y)<2 and absf(player.global_position.x-target.x)<float(b[2])/2-2:
			release();return true
	release();return false
func replay()->void:
	died=false
	var passed:=true
	for i in config.route.size()-1:
		var move:Array=solutions[config.name][i]
		if move.is_empty() or not await transfer(i,move,true):
			print("REPLAY BLOCK leg ",i+1," at ",player.global_position-room.global_position)
			passed=false;break
	if passed:
		if config.has("note_landings"):
			var seq:NoteSequence=world.get_node("NoteSequence")
			check(seq.progress==5 and not room.get_meta("exit_locked"),"melody opened gate through real landings")
			passed=seq.progress==5
		if passed:
			Input.action_press("move_left")
			for f in 180:
				await frames(1)
				if world.current_room!=room or died:break
			passed=world.current_room==world._room_after(room) and not died
	check(passed,"%s entrance-to-exit without teleport or immunity" % config.name)
	release();await frames(30)
