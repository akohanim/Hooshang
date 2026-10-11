extends "res://tests/act2_precision_routes_test.gd"
## One continuous, save-free key mission. No position writes, respawns, key
## grants or disabled portals after the normal initial world spawn.
var next_room := ""
var navigator: Node
var visited: Array[String] = []
var skip_ticks := 0
func _ready() -> void:
	SaveGame.unbind()
	LdtkWorld.debug_start_room="Prison_Hub"
	Screen.load_scene("res://ldtk/Act2World.tscn")
	await frames(20)
	world=Screen.current;player=world.player
	player.died.connect(func():deaths+=1)
	continuous=true
	navigator=load("res://tests/fixtures/act2_precision_navigator.gd").new()
	navigator.run_on_ready=false;navigator.world=world
	add_child(navigator)
	var recipes:Array=JSON.parse_string(FileAccess.get_file_as_string("res://resources/levels/act2_precision.json"))
	for wing in ["R","G","B","Y"]:
		room=world.current_room;offset=room.global_position
		var first:="Prison_%s01" % wing
		next_room=first
		var portal:=find_portal(first)
		var approach:Vector2=portal.center-offset-portal.direction*24
		if portal.direction.x!=0:approach.y=portal.rect.end.y-offset.y-6
		else:
			approach.x=portal.rect.position.x-offset.x+8
			if portal.direction==Vector2.UP:approach.y-=6
		if portal.direction==Vector2.DOWN:
			# The upper terraces can be left at their outer edge; the central
			# stairwell then gives an unobstructed, safe descent through the hall.
			for target in [Vector2(504,154),Vector2(320,202),Vector2(272,250),Vector2(320,298),Vector2(408,322)]:
				for tick in 480:
					steer(target.x)
					await frames(1)
					var at:Vector2=player.global_position-offset
					if absf(at.x-target.x)<4 and absf(at.y-target.y)<8 and player.is_on_floor():break
				release()
			check(await navigator.navigate(Vector2(444,370)),"hub approach to lower right well")
			if not failures:check(await navigator.gym_go(offset+Vector2(408,362),false),"hub lower well landing")
		else:check(await navigator.navigate(approach),"hub access to "+first+" "+navigator.failure)
		if failures:break
		await cross_to(first)
		if failures:break
		for n in range(1,5):
			room=world.current_room;offset=room.global_position
			var name_now:="Prison_%s%02d" % [wing,n]
			check(str(room.name)==name_now,"continuous entry "+name_now)
			if failures:break
			visited.append(name_now)
			player._ledge_cooldown=3600
			next_room="Prison_%s%02d" % [wing,n+1] if n<4 else "Prison_Hub"
			var recipe:Dictionary
			for item:Dictionary in recipes:
				if item.name==name_now:recipe=item
			trial=name_now+"_connected"
			if recipe.has("wall_path"):await wall_climb()
			elif not recipe.water_paths.is_empty():await swim_route(recipe.water_paths[0])
			else:
				var points:Array=recipe.paths[0]
				for i in range(1,points.size()):
					await precision_transfer(points[i-1],points[i])
					if failures or _route_exit_started():break
			if failures:break
			if n==3:check(world.collected.has({"R":"Red","G":"Green","B":"Blue","Y":"Gold"}[wing]),"earned the "+wing+" key by touching it")
			await cross_to(next_room)
			check(deaths==0,"continuous wing has no deaths")
			if failures:break
		if failures:break
		print("CONNECTED WING ",wing," complete; keys=",world.collected)
		if wing=="B":
			next_room="Prison_Y01"
			trial="Hub_lower_return"
			room=world.current_room;offset=room.global_position
			await precision_transfer([88,368],[156,352])
			if failures:break
	if not failures:
		room=world.current_room;offset=room.global_position
		check(world.collected.size()==4,"all four keys earned")
		next_room="Act_2_Level_16"
		check(await navigator.navigate(Vector2(480,346)),"reach the cage overpass approach")
		await precision_transfer([480,352],[432,304])
		check(await navigator.navigate(Vector2(292,346)),"return to Jamshid on foot")
		for i in 600:
			await frames(1)
			if world.rescued and world.story_flags.get("cell_reunion",false) and not player.input_locked:break
		check(world.rescued and world.inserted.size()==4,"four earned keys release Jamshid")
		check(world.story_flags.get("cell_reunion",false) and not player.input_locked,"reunion completes and restores control")
		if not failures:
			check(await navigator.navigate(Vector2(160,346)),"reach the courtyard terrace")
			await prepare(Vector2(160,346))
			Input.action_press("jump")
			for tick in 120:
				steer(64)
				if tick==12:Input.action_press("dash")
				if tick==13:Input.action_release("dash")
				if tick==40:Input.action_release("jump")
				await frames(1)
				if tick>20 and player.is_on_floor():break
			release()
			check(player.is_on_floor() and player.global_position.x-offset.x<136 and player.global_position.y-offset.y<352,"courtyard jump reaches a supported terrace")
			await prepare(Vector2(64,346))
			Input.action_press("move_up");await frames(2);Input.action_release("move_up")
			await frames(100)
			check(str(world.current_room.name)=="Act_2_Level_16","rescued courtyard door reaches final trials")
	release();Input.action_release("skip_dialogue")
	var report:={"failures":failures,"deaths":deaths,"visited":visited,"keys":world.collected,"rescued":world.rescued,"destination":str(world.current_room.name)}
	FileAccess.open("res://output/act2_redesign/mission_results.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("PRECISION MISSION: ",JSON.stringify(report))
	get_tree().quit(1 if failures else 0)

func _physics_process(_delta:float) -> void:
	if not is_instance_valid(player):return
	if player.input_locked and not world._transitioning:
		skip_ticks+=1
		# Release between holds: a new conversation intentionally rejects an
		# X already held during the preceding cage-unlock animation.
		if skip_ticks%90<2:Input.action_release("skip_dialogue")
		else:Input.action_press("skip_dialogue")
	else:
		skip_ticks=0
		Input.action_release("skip_dialogue")

func _route_exit_started() -> bool:
	return str(world.current_room.name)==next_room or (world._transitioning and world.transition_target!=null and str(world.transition_target.name)==next_room)

func find_portal(destination:String) -> Dictionary:
	for portal:Dictionary in world.portals:
		if portal.from==world.current_room and str(portal.to.name)==destination:return portal
	return {}

func cross_to(destination:String) -> void:
	release()
	if not _route_exit_started():
		var portal:=find_portal(destination)
		check(not portal.is_empty(),"portal exists to "+destination)
		if portal.is_empty():return
		var target:Vector2=portal.center-offset
		if portal.direction==Vector2.DOWN:target.x=portal.rect.end.x-offset.x-12
		if portal.direction==Vector2.UP:
			target.x=portal.rect.position.x-offset.x+8
			await prepare(Vector2(target.x,18))
		for i in 300:
			if _route_exit_started():break
			if portal.direction.x!=0:Input.action_press("move_right" if portal.direction.x>0 else "move_left")
			else:
				steer(target.x)
				Input.action_press("move_down" if portal.direction.y>0 else "move_up")
				if portal.direction.y<0:Input.action_press("jump")
			await frames(1)
	release()
	for i in 180:
		await frames(1)
		if str(world.current_room.name)==destination and not world._transitioning:break
	await frames(6)
	check(str(world.current_room.name)==destination,"walked actual portal to "+destination)

func swim_route(points:Array) -> void:
	await prepare(Vector2(points[0][0],points[0][1]-6))
	for target:Array in points.slice(1):
		var arrived:=false
		for i in 300:
			var at:=player.global_position-offset
			steer(float(target[0]))
			Input.action_release("move_up");Input.action_release("move_down")
			var dy:float=target[1]-6-at.y
			if absf(dy)>2:Input.action_press("move_down" if dy>0 else "move_up")
			if absf(at.x-target[0])<6 and absf(dy)<8:arrived=true;break
			await frames(1)
			if _route_exit_started():arrived=true;break
			if player.state==Player.State.DEAD:break
		release()
		check(arrived,trial+" swim to "+str(target))
		if failures or _route_exit_started():return
