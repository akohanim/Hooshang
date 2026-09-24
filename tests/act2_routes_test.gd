extends Node
## Real player-input transfer checks in the imported rooms. Each segment starts
## on a real resting surface; no positions/velocities are written during flight.
var world: LdtkWorld
var player: Player
var room: Node2D
var failures:=0
var offset:=Vector2.ZERO
var continuous:=false
func _ready() -> void:
	SaveGame.slot=-1
	LdtkWorld.debug_start_room="Act_2_Level_3"
	Screen.load_scene("res://ldtk/Act2World.tscn")
	await frames(8)
	world=Screen.current as LdtkWorld;player=world.player
	player.has_dash=true
	for e in get_tree().get_nodes_in_group("exit"):e.set_deferred("monitoring",false)
	var recipes: Array = JSON.parse_string(FileAccess.get_file_as_string("res://resources/levels/act2_expansion.json"))
	for recipe: Dictionary in recipes:
		select(int(str(recipe.name).get_slice("_",3)))
		for step: Dictionary in recipe.routes:
			match step.kind:
				"spring":await spring_transfer(step.start+step.target)
				"side":await side_transfer(step)
				_:await fly(step)
	await bonus_loop()
	# Repeat the main solutions from entrance to exit without teleporting
	# between obstacles. This catches an individually possible transfer that
	# leaves the player on the wrong side of the next spring or boarding dock.
	continuous=true
	for recipe: Dictionary in recipes:
		select(int(str(recipe.name).get_slice("_",3)))
		player.respawn(world.spawn_point_for(room));player.input_locked=false
		await frames(10)
		var before:=failures
		for step: Dictionary in recipe.routes:
			match step.kind:
				"spring":await spring_transfer(step.start+step.target)
				"side":await side_transfer(step)
				"flight":await fly(step)
			if failures>before:break
		check(failures==before,"%s continuous entrance-to-exit route" % recipe.name)
	print("ACT2_ROUTES: ",failures," failures")
	get_tree().quit(0 if failures==0 else 1)
func select(n:int) -> void:
	for candidate in world.rooms:
		if str(candidate.name)=="Act_2_Level_%d" % n:room=candidate
	world._enter_room(room,true);offset=room.global_position
func prepare(at:Vector2) -> void:
	release()
	if continuous:
		for i in 150:
			steer(at.x)
			await frames(1)
			if absf(player.global_position.x-offset.x-at.x)<2 and player.is_on_floor():break
		release()
	else:
		MagicCarpet.reset_all(get_tree());player.respawn(offset+at);player.input_locked=false
		await frames(8)
func steer(x:float) -> void:
	var dx:=x-(player.global_position.x-offset.x)
	var brake:=player.velocity.x*absf(player.velocity.x)/1500.0
	var intent:=dx-brake
	Input.action_release("move_left");Input.action_release("move_right")
	if absf(intent)>2:Input.action_press("move_right" if intent>0 else "move_left")
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
		steady=steady and absf(carpet.position.x-previous-32.0/60.0)<0.04
		previous=carpet.position.x
		if player.state==Player.State.DEAD:interrupted=true;break
		var at:=player.global_position-offset
		if jumped and player.is_on_floor() and absf(at.x-float(recipe.target[0]))<24 and absf(at.y-(float(recipe.target[1])-6))<3:landed=true;break
	release()
	check(steady,"horizontal speed stays constant through steering")
	check(not interrupted and landed,"%s full boarded flight and exit landing at %s" % [room.name,player.global_position-offset])
	if not continuous:
		player.respawn(offset+Vector2(200,282))
		await frames(310)
		check(not carpet.activated and carpet.position.is_equal_approx(carpet._origin),"abandoned flight returns after five seconds")


func bonus_loop() -> void:
	select(5)
	var carpet: MagicCarpet
	for node in room.get_node("Entities").get_children():
		if node is MagicCarpet:carpet=node
	await prepare(Vector2(244,186))
	Input.action_press("jump")
	for i in 100:
		steer(carpet.position.x);await frames(1)
		if carpet.activated:break
	release()
	for i in 260:
		if carpet.position.y-4>112:Input.action_press("move_up")
		else:Input.action_release("move_up")
		await frames(1)
		if carpet.position.x>=376:break
	release();Input.action_press("jump")
	var reached:=false
	for i in 100:
		steer(416);await frames(1)
		var at:=player.global_position-offset
		if player.is_on_floor() and absf(at.y-74)<3 and absf(at.x-416)<20:
			reached=true;break
	release()
	check(reached,"Orchard optional lemon balcony is reachable from the high route")
	if not reached:return
	# Let the vehicle catch up, then jump back onto it from the balcony.
	while carpet.position.x<432:await frames(1)
	Input.action_press("jump")
	var returned:=false
	for i in 120:
		steer(carpet.position.x);await frames(1)
		if carpet.carrying(player):returned=true;break
	release()
	check(returned,"optional balcony rejoins the moving carpet")

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
	for i in n:await get_tree().physics_frame
func check(ok:bool,label:String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1

