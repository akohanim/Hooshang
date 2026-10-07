extends Node
## Continuous input-only mission walk. No teleport between hub, wings or keys.
## The navigator reads collision supports; a planned edge only counts if the
## actual player reaches it. Mantle assists are disabled in the player fixture.
var world: Node
var deaths := 0
var failure := ""
var trace: Array = []
var nodes: Array[Vector2] = []
var links: Array = []
var geo: Node
var forbidden := false
var ticks := 0
var policy := 0
var trial_deaths := 0
var saw_wall_jump := false
var reverse_mode := false

func _ready() -> void:
	await setup_world()
	print("NAV START speed=",world.player.max_run_speed," jump=",world.player.jump_speed)
	reverse_mode="--reverse" in OS.get_cmdline_user_args()
	if reverse_mode:
		world.collected.assign(world.IDS)
		world.rescue_started=true
		world._refresh()
	var wings: Array=["R","G","B","Y"]
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--wing="): wings=[arg.trim_prefix("--wing=")]
	for wing in wings:
		var itinerary: Array=[]
		for number in ([4,3,2,1] if reverse_mode else [1,2,3,4]): itinerary.append("Prison_%s%02d" % [wing,number])
		itinerary.append("Prison_Hub")
		for destination in itinerary:
			if str(world.current_room.name).ends_with("03") and not reverse_mode:
				var key: Node
				for prop in world.props:
					if prop.kind=="Key" and prop.get_parent().get_parent()==world.current_room: key=prop
				if not await navigate(key.position): break
				await frames(8)
				if not world.collected.has(key.key_id): failure="missed key "+key.key_id; break
			if not await cross(destination): break
		if failure!="": break
		print("LOOP PASS ",wing," keys=",world.collected)
	if failure=="" and wings.size()==4 and not reverse_mode:
		if not await navigate(Vector2(292,346)): failure="return to cage"
		await frames(240)
		if not world.rescued: failure="rescue did not complete"
	release()
	DirAccess.make_dir_recursive_absolute("res://output/prison_build")
	var file := FileAccess.open("res://output/prison_build/navigation_reverse.json" if reverse_mode else "res://output/prison_build/navigation.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"failure":failure,"deaths":deaths,"forbidden":forbidden,"trace":trace}))
	print("PRISON NAVIGATION: ","PASS" if failure=="" and deaths==0 and not forbidden else "FAIL "+failure," deaths=",deaths," forbidden=",forbidden)
	await shutdown(0 if failure=="" and deaths==0 and not forbidden else 1)

func release() -> void:
	for action in ["move_left","move_right","move_up","move_down","jump","dash"]: Input.action_release(action)
func frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame
		ticks+=1
		saw_wall_jump=saw_wall_jump or world.player.wall_jump_timer>0
		forbidden=forbidden or world.player.state_name() in ["CLIMB","LEDGE_MANTLE"]
		if ticks%6==0:
			trace.append({"room":str(world.current_room.name),"at":var_to_str(world.player.position-world.current_room.position),"state":world.player.state_name()})
func local_player() -> Vector2:
	return world.player.global_position-world.current_room.global_position
func clear_at(p: Vector2) -> bool:
	for dx in [-4.0,4.0]:
		for dy in [-5.5,5.5]:
			if geo.value_at(Vector2i(floori((p.x+dx)/8),floori((p.y+dy)/8))) in [1,3]: return false
	if str(world.current_room.name)=="Prison_Hub" and not world.rescued:
		if Rect2(302,308,68,50).has_point(p): return false
	return true
func wet(p: Vector2) -> bool:
	return geo.value_at(Vector2i(floori(p.x/8),floori(p.y/8)))==4
func supported(p: Vector2) -> bool:
	return geo.value_at(Vector2i(floori(p.x/8),floori((p.y+7)/8))) in [1,2]
func edge_ok(a: Vector2,b: Vector2) -> bool:
	var delta := b-a
	var swimming := wet(a) and wet(b)
	if swimming:
		if delta.length()>25: return false
	elif absf(delta.x)>(24 if delta.y < -1 else 44) or delta.y < -25 or delta.y>65: return false
	if not swimming and delta.y>7:
		# A downward edge must leave the current one-way deck, not assume
		# the player can fall through its middle or through intervening decks.
		for y in range(floori((a.y+6)/8),floori((b.y+5)/8)+1):
			for dx in [-4,4]:
				if geo.value_at(Vector2i(floori((b.x+dx)/8),y)) in [1,2]: return false
	for step in range(1,17):
		var t := step/16.0
		var p := a.lerp(b,t)
		if not swimming and not (absf(delta.y)<1 and supported(a.lerp(b,0.5))):
			p.y-=sin(t*PI)*28
		if geo.value_at(Vector2i(floori((p.x-4)/8),0))==1 or geo.value_at(Vector2i(floori((p.x+4)/8),0))==1: p.y=maxf(p.y,14)
		if not clear_at(p): return false
	return true
func build_graph(target: Vector2) -> int:
	geo=world.current_room.get_node("PrisonGeometry")
	nodes.clear();links.clear()
	var size: Vector2i=geo.size_cells
	for y in range(1,size.y):
		for x in range(1,size.x-1):
			var p:=Vector2(x*8+4,y*8-6.1)
			if geo.value_at(Vector2i(x,y)) in [1,2] and clear_at(p): nodes.append(p)
			elif x%2==0 and y%2==0:
				p=Vector2(x*8+4,y*8+4)
				if wet(p) and clear_at(p): nodes.append(p)
	nodes.append(local_player());nodes.append(target)
	for i in nodes.size():
		var adjacent: Array[int]=[]
		for j in nodes.size():
			if i!=j and edge_ok(nodes[i],nodes[j]): adjacent.append(j)
		links.append(adjacent)
	return nodes.size()-2
func navigate(target: Vector2, attempt: int=0) -> bool:
	var room_name := str(world.current_room.name)
	var start:=build_graph(target)
	var goal:=nodes.size()-1
	var frontier: Array[int]=[start]
	var previous: Dictionary={start:-1}
	while not frontier.is_empty():
		var at: int=frontier.pop_front()
		if at==goal: break
		for neighbor in links[at]:
			if not previous.has(neighbor):
				previous[neighbor]=at
				frontier.append(neighbor)
	if not previous.has(goal):
		var closest: Vector2=nodes[start]
		for reachable in previous:
			if nodes[reachable].distance_to(target)<closest.distance_to(target): closest=nodes[reachable]
		print("CLOSEST ",closest," reachable=",previous.size()," of ",nodes.size())
		failure="no support route in %s from %s to %s" % [room_name,local_player(),target]
		return false
	var path: Array[Vector2]=[]
	var cursor:=goal
	while cursor!=start:
		path.push_front(nodes[cursor]);cursor=previous[cursor]
	print("PATH ",room_name," ",local_player()," -> ",target," ",path)
	for point in path:
		if not await move_to(point,room_name):
			if deaths==0 and attempt<3:
				print("RECOVER ",failure)
				failure=""
				return await navigate(target,attempt+1)
			return false
	return true
func move_to(target: Vector2,room_name: String) -> bool:
	# Wait on the approach deck for an overhead patrol to move away.
	for prop in world.props:
		if prop.kind!="Patrol" or prop.get_parent().get_parent()!=world.current_room: continue
		if prop.position.x < minf(local_player().x,target.x)-8 or prop.position.x > maxf(local_player().x,target.x)+8: continue
		for wait_frame in 240:
			var angle: float=prop.clock*2.0*float(prop.fields.get("Speed",1.0))+float(prop.fields.get("Phase",0.0))
			if sin(angle)<-0.75 and cos(angle)<0: break
			release();await frames(1)
	var jumped := false
	var jump_frames := 0
	for frame in 240:
		if str(world.current_room.name)!=room_name: release();return true
		var p: Player=world.player
		var at:=local_player()
		var delta:=target-at
		if deaths>0: failure="death in "+room_name;release();return false
		if absf(delta.x)<4 and absf(delta.y)<5 and (p.is_on_floor() or p.swimming() or not supported(target)):
			release();await frames(12);return true
		for action in ["move_left","move_right","move_up","move_down","dash"]: Input.action_release(action)
		if jump_frames==0: Input.action_release("jump")
		if absf(delta.x)>2.0:
			# Stop early enough for the childhood momentum profile to brake.
			if absf(delta.x)>absf(p.velocity.x)*0.06 or signf(p.velocity.x)!=signf(delta.x):
				Input.action_press("move_right" if delta.x>0 else "move_left")
		if p.swimming():
			if absf(delta.y)>3: Input.action_press("move_down" if delta.y>0 else "move_up")
			if not wet(target) and delta.y < -3 and frame%24==0: jump_frames=10
		elif p.is_on_floor() and not jumped:
			if delta.y < -7 or (absf(delta.y)<7 and not supported(at.lerp(target,0.5))):
				jumped=true;jump_frames=24
		if jump_frames>0:
			Input.action_press("jump");jump_frames-=1
		await frames(1)
	failure="stalled in %s at %s aiming %s" % [room_name,local_player(),target]
	release();return false
func cross(destination: String) -> bool:
	if str(world.current_room.name) in ["Prison_Y01","Prison_Y02","Prison_Y03"] and local_player().x<184 and destination in ["Prison_Y02","Prison_Y03"]:
		if not await navigate(Vector2(172,154)): return false
		for point in [Vector2(176,114),Vector2(196,98)]:
			if not await gym_go(world.current_room.global_position+point,false):
				failure="gym wall-jump route at "+str(local_player());return false
		print("GYM WALL PASS ",world.current_room.name," wall jump=",saw_wall_jump)
	var portal: Dictionary={}
	for entry in world.portals:
		if entry.from==world.current_room and str(entry.to.name)==destination: portal=entry
	if portal.is_empty(): failure="missing portal "+destination;return false
	var target: Vector2=portal.center-world.current_room.global_position
	if portal.direction==Vector2.DOWN: target.x+=12
	if portal.direction.x!=0: target.y=portal.rect.end.y-world.current_room.global_position.y-6.1
	# Stop just inside the edge; crossing itself is driven by held input.
	var approach: Vector2=target-portal.direction*20
	if not await navigate(approach): return false
	var original:=str(portal.from.name)
	for frame in 180:
		if str(world.current_room.name)==destination:
			release();await frames(65)
			print("CROSS PASS ",original," -> ",destination)
			return true
		for action in ["move_left","move_right","move_up","move_down"]: Input.action_release(action)
		if portal.direction.x!=0: Input.action_press("move_right" if portal.direction.x>0 else "move_left")
		else:
			var dx: float=target.x-local_player().x
			if absf(dx)>2: Input.action_press("move_right" if dx>0 else "move_left")
			Input.action_press("move_down" if portal.direction.y>0 else "move_up")
			if portal.direction.y<0: Input.action_press("jump")
		await frames(1)
	failure="could not cross "+original+" -> "+destination+" at "+str(local_player())
	release();return false

func gym_go(target: Vector2, wet: bool) -> bool:
	var jump_held := 0
	var dash_cooldown := 0
	var wall_cooldown := 0
	var airborne := 0
	for frame in 600:
		var p: Player = world.player
		if deaths != trial_deaths or not world.room_rect(world.current_room).has_point(p.global_position): return false
		airborne = 0 if p.is_on_floor() else airborne+1
		var delta := target-p.global_position
		var require_ground: bool = not wet and (target.x-room_offset().x >= 280 or world.current_room.name.begins_with("Prison_Y") and is_equal_approx(target.y-room_offset().y,114))
		if absf(delta.x)<7 and (absf(delta.y)<12 or not wet and target.y-room_offset().y>150) and (not require_ground or p.is_on_floor()):
			release()
			return true
		for action in ["move_left","move_right","move_up","move_down","dash"]: Input.action_release(action)
		var was_jump := Input.is_action_pressed("jump")
		if jump_held == 0: Input.action_release("jump")
		var dir := signf(delta.x)
		if absf(delta.x)>3:
			Input.action_press("move_right" if dir>0 else "move_left")
		if p.swimming():
			jump_held = maxi(0,jump_held-1)
			if delta.y < -5 and not Input.is_action_pressed("jump"):
				Input.action_press("jump")
				jump_held = 30 if world.current_room.name.begins_with("Prison_Y") else [10,16,24][policy%3]
			if absf(delta.y)>4: Input.action_press("move_down" if delta.y>0 else "move_up")
		else:
			if p.is_on_floor() and (not was_jump if world.current_room.name.begins_with("Prison_Y") else not Input.is_action_pressed("jump")) and (needs_jump(dir) or delta.y < -8): jump_held = 30 if world.current_room.name.begins_with("Prison_Y") else [10,16,24][policy%3]
			if world.current_room.name.begins_with("Prison_Y") and p.is_on_wall() and delta.y < -8 and wall_cooldown <= 0:
				if was_jump:
					jump_held = 0
					Input.action_release("jump")
				else:
					jump_held = 30
					wall_cooldown = 16
			if jump_held>0:
				Input.action_press("jump")
				jump_held -= 1
			if not wet and airborne >= [6,10,14][policy%3] and p.dash_available and (delta.y < -16 or needs_jump(dir)) and dash_cooldown<=0:
				if delta.y < -16: Input.action_press("move_up")
				Input.action_press("dash")
				dash_cooldown = 30
		dash_cooldown -= 1
		wall_cooldown -= 1
		await frames(1)

	return false

func room_offset() -> Vector2:
	return world.current_room.global_position

func needs_jump(dir: float) -> bool:
	var geo = world.current_room.get_node("PrisonGeometry")
	var feet: Vector2 = world.player.global_position + Vector2(dir*[12,16,20,24][policy/3],8)
	var cell: Vector2i = geo.grid.local_to_map(geo.grid.to_local(feet))
	return geo.value_at(cell) not in [1,2] or geo.value_at(cell+Vector2i.UP) == 1

func setup_world() -> void:
	SaveGame.unbind()
	world = load("res://ldtk/Act2World.tscn").instantiate()
	world.debug_start_room = "Prison_Hub"
	var player = world.player_scene.instantiate()
	player.set_script(load("res://tests/fixtures/prison_no_assist_player.gd"))
	var packed := PackedScene.new()
	packed.pack(player)
	player.free()
	world.player_scene = packed
	add_child(world)
	world.player.died.connect(func(): deaths += 1)
	await frames(20)

func shutdown(exit_code: int) -> void:
	release()
	world.queue_free()
	world=null
	for frame in 3: await get_tree().physics_frame
	get_tree().quit(exit_code)
