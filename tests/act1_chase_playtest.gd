extends Node
## Complete each escape room in one life with Darkshang active. Retries use the
## normal room entrance; no repositioning is allowed between its jumps.
var world:LdtkWorld
var player:Player
var shadow:Darkshang
var failures:Array[String]=[]
var died:=false
var active_room:Node2D
var final_leg:=false
func _ready()->void:
	SaveGame.slot=-1
	LdtkWorld.debug_start_room="Level_15"
	world=load("res://ldtk/Act1World.tscn").instantiate()
	add_child(world)
	await frames(8)
	player=world.player
	player.has_dash=true
	player.died.connect(func():died=true)
	shadow=get_tree().get_first_node_in_group("darkshang")
	var configs:Array=JSON.parse_string(FileAccess.get_file_as_string("res://resources/levels/act1_expansion.json"))
	var solutions:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://output/act1_expansion/route_timings.json"))
	for config:Dictionary in configs:
		if config.direction>0:continue
		var room:Node2D
		for candidate in world.rooms:
			if str(candidate.name)==config.name:room=candidate
		active_room=room
		var success:=false
		for variant in 3:
			release()
			world._enter_room(room,true)
			CrumblingPlatform.reset_all(get_tree())
			player.has_dash=true
			await frames(50)
			died=false
			shadow.start_chase()
			shadow.reset_to_checkpoint(player.global_position)
			success=true
			for i in range(config.route.size()-1):
				final_leg=i==config.route.size()-2
				var a:Array=config.route[i]
				var b:Array=config.route[i+1]
				# Start a little earlier at running speed than the from-rest test.
				var takeoff:float=room.global_position.x+float(a[0])+12+variant*4
				Input.action_press("move_left")
				for frame in 150:
					if player.global_position.x<=takeoff or died:break
					await frames(1)
				if died:success=false;break
				var timing:int=int(solutions[config.name][i])
				if config.name=="Level_24" and final_leg:timing=12
				if timing>=0:timing=maxi(4,timing-variant*2)
				if not await jump_to(room.global_position+Vector2(float(b[0])+float(b[2])/2,float(b[1])-6),float(b[2]),timing,b[1]<a[1]):
					success=false
					print("RETRY %s leg %d variant %d at %s" % [config.name,i+1,variant,player.global_position-room.global_position])
					break
			if success:break
			shadow.stop_chase()
			await frames(65)
		print("PASS " if success else "FAIL ",config.name," complete with active chase")
		if not success:failures.append(config.name)
		shadow.stop_chase()
		await frames(3)
	release()
	print("CHASE PLAYTEST: %d failures" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
func jump_to(target:Vector2,width:float,dash_at:int,up:bool)->bool:
	Input.action_press("jump")
	for frame in 100:
		if frame==14:Input.action_release("jump")
		if frame==dash_at:
			if up:Input.action_press("move_up")
			Input.action_press("dash")
		if frame==dash_at+1:
			Input.action_release("dash");Input.action_release("move_up")
		await frames(1)
		if final_leg and world.current_room!=active_room:return true
		if died:return false
		if frame>3 and player.is_on_floor() and absf(player.global_position.y-target.y)<3 and absf(player.global_position.x-target.x)<width/2:
			Input.action_release("jump");Input.action_release("dash");Input.action_release("move_up")
			return true
	return false
func release()->void:
	for action in ["move_left","move_right","move_up","jump","dash"]:Input.action_release(action)
func frames(n:int)->void:
	for i in n:await get_tree().physics_frame
