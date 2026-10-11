extends "res://tests/act2_routes_test.gd"
## Real-input traversal of new castle paths. Only trial setup uses respawn;
## every transfer in each sequence is continuous, with live hazard/water logic.
var evidence: Array = []
var trial := ""
var ticks := 0
var capture := false
func _ready() -> void:
	SaveGame.unbind()
	LdtkWorld.debug_start_room = "Prison_R01"
	Screen.load_scene("res://ldtk/Act2World.tscn")
	await frames(20)
	world = Screen.current
	player = world.player
	player.died.connect(func(): deaths += 1)
	# Room-sequence acceptance is separate from actual threshold tests.
	world.portals.clear()
	continuous = true
	capture = "--capture" in OS.get_cmdline_user_args()
	DirAccess.make_dir_recursive_absolute("res://output/act2_redesign/gameplay")
	var recipes: Array = JSON.parse_string(FileAccess.get_file_as_string("res://resources/levels/act2_precision.json"))
	for recipe: Dictionary in recipes:
		var args := OS.get_cmdline_user_args()
		if args.size() > int(capture) and not recipe.name in args: continue
		if recipe.name == "Prison_Hub": continue
		for points: Array in recipe.paths:
			for backwards in [false, true]:
				var path := points.duplicate(true)
				if backwards: path.reverse()
				await settle_retry()
				for candidate in world.rooms:
					if str(candidate.name) == recipe.name: room = candidate
				world._enter_room(room,true)
				offset = room.global_position
				CrumblingPlatform.reset_all(get_tree())
				player.respawn(offset + Vector2(path[0][0],path[0][1]-6))
				player.input_locked = false
				player._ledge_cooldown = 3600.0
				await frames(8)
				trial = str(recipe.name) + ("_return" if backwards else "_forward")
				var before := failures
				var death_start := deaths
				for i in range(1,path.size()):
					var a: Array = path[i-1]
					var b: Array = path[i]
					await precision_transfer(a,b)
					if failures > before: break
				check(deaths==death_start,trial+" no deaths")
				evidence.append({"trial":trial,"passed":before==failures,"deaths":deaths-death_start})
		if recipe.has("wall_path"):
			await settle_retry()
			for candidate in world.rooms:
				if str(candidate.name)==recipe.name:room=candidate
			world._enter_room(room,true);offset=room.global_position
			player.respawn(offset+Vector2(240,170));player.input_locked=false
			await frames(8)
			trial=str(recipe.name)+"_wall_climb"
			var before:=failures
			var death_start:=deaths
			await wall_climb()
			evidence.append({"trial":trial,"passed":failures==before,"deaths":deaths-death_start})

		for points: Array in recipe.water_paths:
			await settle_retry()
			for candidate in world.rooms:
				if str(candidate.name)==recipe.name: room=candidate
			world._enter_room(room,true)
			offset=room.global_position
			player.respawn(offset+Vector2(points[0][0],points[0][1]-6))
			player.input_locked=false
			await frames(8)
			trial=str(recipe.name)+"_swim"
			var before:=failures
			var death_start:=deaths
			for target: Array in points.slice(1):
				var arrived:=false
				for i in 240:
					var at:=player.global_position-offset
					steer(float(target[0]))
					Input.action_release("move_up");Input.action_release("move_down")
					var dy:float=target[1]-6-at.y
					if absf(dy)>2:Input.action_press("move_down" if dy>0 else "move_up")
					var surface:float=world.surface_y_at(player.global_position)
					if dy < -8 and (player.is_on_floor() or (player.swimming() and float(target[1])-6<surface)):
						if i%45==0:Input.action_press("jump")
					if i%45==30:Input.action_release("jump")
					if absf(at.x-target[0])<6 and absf(dy)<8:arrived=true;break
					await frames(1)
					if player.state==Player.State.DEAD:break
				release()
				check(arrived,"%s swim to %s actual %s" % [trial,target,player.global_position-offset])
				if not arrived:break
			check(deaths==death_start,trial+" no deaths")
			evidence.append({"trial":trial,"passed":failures==before,"deaths":deaths-death_start})

	release()
	FileAccess.open("res://output/act2_redesign/route_results.json",FileAccess.WRITE).store_string(JSON.stringify(evidence,"\t"))
	print("ACT2 PRECISION: ",failures," failures")
	get_tree().quit(1 if failures else 0)

func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
		ticks += 1
		if capture and is_instance_valid(player) and ticks % 8 == 0:
			await get_tree().process_frame
			RenderingServer.force_draw()
			Screen.viewport.get_texture().get_image().save_png("res://output/act2_redesign/gameplay/%s_%05d.png" % [trial,ticks])

func precision_transfer(a: Array, b: Array) -> void:
	await prepare(Vector2(a[0],a[1]-6))
	var dx: float = b[0]-a[0]
	var dy: float = b[1]-a[1]
	var dropping: bool = dy > 8 and (absf(dx) < 40 or (a[1]<80 and absf(dx)<=56) or (a[1]==24 and dy>=40 and absf(dx)<=72))
	var use_dash := absf(dx)>40 or dy < -28
	var dash_tick := 4 if a[1] < 72 else 12
	if dy<=-32 and a[1]>=72:dash_tick=18
	if a[1]<56 and dy<0 and absf(dx)>24:
		use_dash=true;dash_tick=10
	var left_pad := false
	var airborne := false
	var landed := false
	if not dropping: Input.action_press("jump")
	for i in 180:
		if dropping and not left_pad:
			steer(float(a[0])+((16 if a[1]==24 else 24) if dx>=0 else -(16 if a[1]==24 else 24)))
			left_pad = absf(player.global_position.x-offset.x-float(a[0])) > (10 if a[1]==24 else 19)
		else: steer(float(b[0]))
		if i==dash_tick and use_dash and not dropping:
			Input.action_release("move_left"); Input.action_release("move_right")
			if absf(dx)>1: Input.action_press("move_right" if dx>0 else "move_left")
			if dy < -20 or (str(room.name)=="Prison_B01" and a[1]==40 and b[1]==24): Input.action_press("move_up")
			Input.action_press("dash")
		if i==dash_tick+6:
			Input.action_release("dash"); Input.action_release("move_up")
		if i==40: Input.action_release("jump")
		await frames(1)
		if _route_exit_started():landed=true;break
		airborne = airborne or not player.is_on_floor()
		if player.state == Player.State.DEAD: break
		var at := player.global_position-offset
		if airborne and player.is_on_floor() and i>5:
			landed = absf(at.x-b[0])<22 and absf(at.y-(b[1]-6))<4
			break
	release()
	check(landed,"%s %s -> %s actual %s" % [trial,a,b,player.global_position-offset])

func wall_climb() -> void:
	var toward:=1
	var last_jump:=-100
	var wall_jumps:=0
	var landed:=false
	Input.action_press("jump")
	for i in 480:
		var at:=player.global_position-offset
		Input.action_release("move_left");Input.action_release("move_right")
		if at.y<58:
			steer(296)
		else:Input.action_press("move_right" if toward>0 else "move_left")
		
		if at.y>=58 and player.is_on_wall() and i-last_jump>12:
			Input.action_release("jump")
			await frames(1)
			Input.action_press("jump")
			last_jump=i
			toward=-toward
			wall_jumps+=1
		await frames(1)
		if player.state==Player.State.DEAD:break
		if player.is_on_floor() and at.y<75 and at.x>276:landed=true;break
	release()
	check(landed and wall_jumps>=2,"alternating walls reach upper landing with %d wall jumps; at %s" % [wall_jumps,player.global_position-offset])
