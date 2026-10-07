extends Node
## Real player-input solutions in imported rooms, continuous from entrance
## to exit. Only initial spawns and the optional-branch setup reposition players.
var world: LdtkWorld
var player: Player
var room: Node2D
var failures:=0
var offset:=Vector2.ZERO
var continuous:=false
var deaths:=0
var advanced:=false
var used_climb:=false
var capture_weave:=false
func _ready() -> void:
	capture_weave="--capture-weave" in OS.get_cmdline_user_args()
	SaveGame.slot=-1
	LdtkWorld.debug_start_room="Act_2_Level_3"
	Screen.load_scene("res://ldtk/Act2World.tscn")
	await frames(8)
	world=Screen.current as LdtkWorld;player=world.player
	player.has_dash=true
	player.died.connect(func(): deaths+=1)
	for e in get_tree().get_nodes_in_group("exit"):e.set_deferred("monitoring",false)
	var recipes: Array = JSON.parse_string(FileAccess.get_file_as_string("res://resources/levels/act2_expansion.json"))
	# Every main solution runs from entrance to exit with real input and no
	# position/velocity writes between obstacles. Optional routes are separate runs.
	continuous=true
	for recipe: Dictionary in recipes:
		var only:=OS.get_cmdline_user_args()
		if "--capture-weave" in only:only.remove_at(only.find("--capture-weave"))
		if not only.is_empty() and str(recipe.name) not in only:continue
		select(int(str(recipe.name).get_slice("_",3)))
		CrumblingPlatform.reset_all(get_tree())
		player.respawn(world.spawn_point_for(room));player.input_locked=false
		await frames(10)
		var before:=failures
		var starting_deaths:=deaths
		used_climb=false
		if advanced:player._ledge_cooldown=3600.0
		for step: Dictionary in recipe.routes:
			await run_step(step)
			if failures>before:break
		if failures==before:
			await prepare(Vector2(float(recipe.exit[0])-12,float(recipe.exit[1])-6))
		check(failures==before and deaths==starting_deaths,"%s continuous entrance-to-exit route" % recipe.name)
		if advanced:check(not used_climb,"advanced route requires no climb, mantle, or wall jump")
		if recipe.get("optional_routes",[]).size()>0:
			select(int(str(recipe.name).get_slice("_",3)))
			CrumblingPlatform.reset_all(get_tree())
			var start: Array=recipe.optional_routes[0].start
			player.respawn(offset+Vector2(start[0]-20,start[1]-6))
			await frames(8)
			var branch_deaths:=deaths
			for step: Dictionary in recipe.optional_routes:
				await run_step(step)
			check(deaths==branch_deaths,"optional route completes without a death")
	print("ACT2_ROUTES: ",failures," failures")
	get_tree().quit(0 if failures==0 else 1)
func run_step(step: Dictionary) -> void:
	match step.kind:
		"spring": await spring_transfer(step.start+step.target)
		"spring_dash": await spring_dash_transfer(step)
		"weave": await weave_flight(step)
		"side": await side_transfer(step)
		"jump", "dash": await jump_transfer(step)
		_: await fly(step)

func jump_transfer(step: Dictionary) -> void:
	await prepare(Vector2(step.start[0],step.start[1]-6))
	var landed:=false
	var airborne:=false
	var dashed:=false
	var dash_frame:=int(step.get("dash_frame",10 if step.target[1]<step.start[1]-24 else 14))
	Input.action_press("jump")
	for i in 180:
		steer(float(step.target[0]))
		if i==dash_frame and step.kind=="dash":
			# The movement action owns direction; no direct velocity injection.
			Input.action_press("move_right" if step.target[0]>step.start[0] else "move_left")
			if step.get("dash_up", step.target[1]<step.start[1]-24):Input.action_press("move_up")
			Input.action_press("dash")
		if i==int(step.get("jump_hold",16)):Input.action_release("jump")
		if i==dash_frame+6:
			Input.action_release("dash");Input.action_release("move_up")
		await frames(1)
		dashed=dashed or player.state==Player.State.DASH
		airborne=airborne or not player.is_on_floor()
		var at:=player.global_position-offset
		if player.state==Player.State.DEAD:break
		if airborne and player.is_on_floor() and player.state!=Player.State.LEDGE_MANTLE:
			landed=absf(at.x-float(step.target[0]))<20 and absf(at.y-(float(step.target[1])-6))<4
			break
	release()
	check(landed and (dashed or step.kind=="jump"),"%s %s %s -> %s actual %s" % [room.name,step.kind,step.start,step.target,player.global_position-offset])

func select(n:int) -> void:
	advanced=n>=9
	for candidate in world.rooms:
		if str(candidate.name)=="Act_2_Level_%d" % n:room=candidate
	world._enter_room(room,true);offset=room.global_position
func prepare(at:Vector2) -> void:
	release()
	if continuous:
		for i in 150:
			steer(at.x)
			await frames(1)
			if absf(player.global_position.x-offset.x-at.x)<2 and absf(player.velocity.x)<8 and player.is_on_floor():break
		release()
		check(absf(player.global_position.x-offset.x-at.x)<2 and player.is_on_floor(), "reached departure on foot")
	else:
		MagicCarpet.reset_all(get_tree());player.respawn(offset+at);player.input_locked=false
		await frames(8)
func steer(x:float) -> void:
	var dx:=x-(player.global_position.x-offset.x)
	var braking := player.childhood_turn_accel if player.childhood_momentum else 750.0
	var brake:=player.velocity.x*absf(player.velocity.x)/(2.0*braking)
	var intent:=dx-brake
	Input.action_release("move_left");Input.action_release("move_right")
	if absf(dx)<1.0 and absf(player.velocity.x)>4:
		Input.action_press("move_left" if player.velocity.x>0 else "move_right")
	elif absf(intent)>0.5:Input.action_press("move_right" if intent>0 else "move_left")
func spring_transfer(s:Array) -> void:
	await prepare(Vector2(s[0]-20,s[1]-6))
	var launched:=false;var landed:=false
	for i in 180:
		if player.velocity.y < -250:launched=true
		steer(s[2] if launched else s[0])
		await frames(1)
		var at:=player.global_position-offset
		if launched and player.is_on_floor() and absf(at.x-s[2])<24 and absf(at.y-(s[3]-6))<5:landed=true;break
	release();check(landed,"%s spring %s -> %s actual %s" % [room.name,Vector2(s[0],s[1]),Vector2(s[2],s[3]),player.global_position-offset])
func spring_dash_transfer(step: Dictionary) -> void:
	await prepare(Vector2(step.start[0]-20,step.start[1]-6))
	var launched:=false
	var launch_frames:=0
	var dashed:=false
	var landed:=false
	for i in 220:
		if player.velocity.y < -250:launched=true
		steer(float(step.target[0]) if launched else float(step.start[0]))
		if launched:
			launch_frames+=1
			if launch_frames==int(step.dash_frame):
				Input.action_press("move_up")
				Input.action_press("dash")
			if launch_frames==int(step.dash_frame)+6:
				Input.action_release("dash");Input.action_release("move_up")
		await frames(1)
		dashed=dashed or player.state==Player.State.DASH
		var at:=player.global_position-offset
		if player.state==Player.State.DEAD:break
		if dashed and player.is_on_floor() and player.state!=Player.State.LEDGE_MANTLE:
			landed=absf(at.x-float(step.target[0]))<24 and absf(at.y-(float(step.target[1])-6))<4
			break
	release()
	check(landed and dashed,"%s spring-to-dash %s -> %s actual %s" % [room.name,step.start,step.target,player.global_position-offset])

func weave_flight(spec: Dictionary) -> void:
	var carpet: MagicCarpet
	for node in room.get_node("Entities").get_children():
		if node is MagicCarpet and absf(node._origin.x-float(spec.carpet))<1:carpet=node
	check(carpet!=null,"weave carpet exists")
	if carpet==null:return
	var original_id:=carpet.get_instance_id()
	await prepare(Vector2(spec.start[0],spec.start[1]-6))
	Input.action_press("jump")
	for i in 120:
		steer(carpet.position.x)
		await frames(1)
		if carpet.activated and carpet.carrying(player):break
	release()
	check(carpet.activated and carpet.carrying(player),"weave boarded with real input")
	var obstacle:=0
	var phase:=0 # ride, jump onto island, cross island, catch rug, final jump
	var phase_frames:=0
	var catches:=0
	var landed:=false
	var previous_x:=carpet.position.x
	var stayed_forward:=true
	for i in 2200:
		phase_frames+=1
		Input.action_release("move_up");Input.action_release("move_down")
		var lane:=float(spec.target[1])-8.0
		if obstacle<spec.islands.size():lane=float(spec.islands[obstacle][2])+1
		if obstacle>0 and lane>float(spec.islands[obstacle-1][2]):
			var old: Array=spec.islands[obstacle-1]
			if carpet.position.x<float(old[0]+old[1])+82:lane=float(old[2])+1
		if phase==0 and absf(carpet.position.y-4-lane)>0.7:
			Input.action_press("move_up" if carpet.position.y-4>lane else "move_down")
		if obstacle<spec.islands.size():
			var island: Array=spec.islands[obstacle]
			var left:=float(island[0]);var right:=left+float(island[1]);var top:=float(island[2])-24.0
			if phase==0 and carpet.position.x>=left-20:
				Input.action_press("jump");phase=1;phase_frames=0
			if phase==1:
				steer(left+12)
				if phase_frames>=14:Input.action_release("jump")
				var at:=player.global_position-offset
				if phase_frames>6 and player.is_on_floor() and absf(at.y-(top-6))<2 and not carpet.carrying(player):
					phase=2;phase_frames=0;Input.action_release("jump")
					check(true,"left moving carpet for island "+str(obstacle+1))
					snapshot_weave(str(obstacle+1)+"_island")
			elif phase==2:
				steer(right-6)
				if carpet.position.x>=right+2 and player.global_position.x-offset.x>=right-9:
					Input.action_press("jump");phase=3;phase_frames=0
			elif phase==3:
				steer(carpet.position.x+3)
				if phase_frames>=6:Input.action_release("jump")
				if phase_frames>8 and carpet.carrying(player):
					catches+=1;obstacle+=1;phase=0;phase_frames=0;release()
					check(carpet.get_instance_id()==original_id,"caught the same carpet "+str(catches))
					snapshot_weave(str(catches)+"_recatch")
		else:
			if phase==0 and carpet.position.x>=float(spec.jump_x):
				Input.action_press("jump");phase=4;phase_frames=0
			if phase==4:
				steer(float(spec.target[0]))
				if phase_frames>16:Input.action_release("jump")
				var at:=player.global_position-offset
				if player.is_on_floor() and not carpet.carrying(player) and absf(at.x-float(spec.target[0]))<24 and absf(at.y-(float(spec.target[1])-6))<3:
					landed=true;break
		await frames(1)
		stayed_forward=stayed_forward and carpet.position.x>=previous_x-0.1 and carpet.activated
		previous_x=carpet.position.x
		if player.state==Player.State.DEAD:break
	release()
	check(landed and catches==spec.islands.size() and stayed_forward,"%s mandatory dismount/recatch sequence (%d/%d), at %s phase %d" % [room.name,catches,spec.islands.size(),player.global_position-offset,phase])

func fly(recipe: Dictionary) -> void:
	var carpet: MagicCarpet
	for node in room.get_node("Entities").get_children():
		if node is MagicCarpet and absf(node._origin.x-float(recipe.carpet))<1:carpet=node
	check(carpet!=null,"flight carpet exists")
	if carpet==null:return
	check(carpet.pattern==MagicCarpet.CarpetPattern.RIDE and carpet.speed==32,"steady right flight configured")
	if recipe.start != null:
		await prepare(Vector2(recipe.start[0],recipe.start[1]-6))
		Input.action_press("jump")
		for i in 100:
			steer(carpet.position.x)
			await frames(1)
			if carpet.activated:break
	elif not continuous:
		await prepare(carpet._origin-Vector2(0,10))
	release()
	check(carpet.activated,"boarding starts flight")
	var gate:=0
	var landed:=false
	var jumped:=false
	var interrupted:=false
	var steady:=true
	var previous:=carpet.position.x
	for i in 1000:
		var target:=float(recipe.target[1])-8.0
		if gate<recipe.waypoints.size():
			var g: Array=recipe.waypoints[gate]
			target=float(g[1])
			if carpet.position.x>float(g[0])+24:gate+=1
		Input.action_release("move_up");Input.action_release("move_down")
		if absf(carpet.position.y-4-target)>1:
			Input.action_press("move_up" if carpet.position.y-4>target else "move_down")
		if not jumped and carpet.position.x>=float(recipe.jump_x):
			Input.action_press("jump");jumped=true
		if jumped:steer(float(recipe.target[0]))
		await frames(1)
		if not jumped and carpet.carrying(player):
			steady=steady and absf(carpet.position.x-previous-32.0/60.0)<0.04
		previous=carpet.position.x
		if player.state==Player.State.DEAD:interrupted=true;break
		var at:=player.global_position-offset
		if jumped and player.is_on_floor() and player.state!=Player.State.LEDGE_MANTLE and absf(at.x-float(recipe.target[0]))<24 and absf(at.y-(float(recipe.target[1])-6))<3:landed=true;break
	release()
	check(steady,"horizontal speed stays constant through steering")
	check(not interrupted and landed,"%s full boarded flight and exit landing at %s" % [room.name,player.global_position-offset])
	if not continuous:
		player.respawn(offset+Vector2(200,282))
		await frames(310)
		check(not carpet.activated and carpet.position.is_equal_approx(carpet._origin),"abandoned flight returns after five seconds")

func side_transfer(step: Dictionary) -> void:
	await prepare(Vector2(step.start[0],step.start[1]-6))
	var spring: SpringPlatform
	for node in room.get_node("Entities").get_children():
		if node is SpringPlatform and node.rotation>1:spring=node
	check(spring!=null,"side spring present")
	if spring==null:return
	var launched:=false
	var landed:=false
	for i in 180:
		if player.velocity.x>200:launched=true
		steer(float(step.target[0]) if launched else spring.position.x)
		await frames(1)
		var at:=player.global_position-offset
		if launched and player.is_on_floor() and absf(at.x-float(step.target[0]))<32 and absf(at.y-(float(step.target[1])-6))<5:
			landed=true;break
	release()
	check(launched and landed,"%s side spring to rug: %s" % [room.name,player.global_position-offset])

func release() -> void:
	for a in ["move_left","move_right","move_up","move_down","jump","dash"]:Input.action_release(a)
func frames(n:int) -> void:
	for i in n:
		await get_tree().physics_frame
		if advanced and is_instance_valid(player):
			used_climb=used_climb or player.state in [Player.State.CLIMB,Player.State.LEDGE_MANTLE] or player.wall_jump_timer>0.0
func check(ok:bool,label:String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1


func snapshot_weave(label: String) -> void:
	if not capture_weave:return
	RenderingServer.force_draw()
	var frame:=Screen.viewport.get_texture().get_image()
	frame.resize(1280,720,Image.INTERPOLATE_NEAREST)
	frame.save_png("res://output/act2_expansion/%s_weave_%s.png" % [room.name,label])
