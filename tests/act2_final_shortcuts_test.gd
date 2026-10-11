extends Node
## Sample obvious input strategies, not an exhaustive solution search.
var world: LdtkWorld
var results: Array = []
func frames(n: int) -> void:
	for i in n:await get_tree().physics_frame
func release() -> void:
	for action in ["move_left","move_right","move_up","move_down","jump","dash"]:Input.action_release(action)
func _ready() -> void:
	SaveGame.unbind()
	LdtkWorld.debug_start_room="Act_2_Level_18"
	Screen.load_scene("res://ldtk/Act2World.tscn")
	await frames(20)
	world=Screen.current
	world.portals.clear()
	var recipes:Array=[
		{"name":"Act_2_Level_16","paths":[[[32,200],[608,200]]],"water_paths":[]},
		{"name":"Act_2_Level_17","paths":[[[32,200],[608,200]]],"water_paths":[]},
		{"name":"Act_2_Level_18","paths":[[[32,184],[608,184]]],"water_paths":[]}]

	var failures:=0
	for recipe: Dictionary in recipes:
		if recipe.name=="Prison_Hub":continue
		var room:Node2D
		for candidate in world.rooms:
			if str(candidate.name)==recipe.name:room=candidate
		var route:Array
		if recipe.has("wall_path"):route=recipe.wall_path
		elif not recipe.water_paths.is_empty():route=recipe.water_paths[0]
		else:route=recipe.paths[0]
		var start:Vector2=Vector2(route[0][0],route[0][1]-6)
		var target:Vector2=Vector2(route[-1][0],route[-1][1]-6)
		for policy in ["hold_forward","repeat_jump","repeat_flat_dash"]:
			release()
			while world.player.state==Player.State.DEAD:await frames(1)
			await frames(8)
			world._enter_room(room,true)
			CrumblingPlatform.reset_all(get_tree())
			world.player.respawn(room.global_position+start)
			world.player.input_locked=false
			await frames(8)
			var solved:=false
			var died:=false
			var direction:="move_right" if target.x>=start.x else "move_left"
			var furthest:=0.0
			for i in 900:
				Input.action_press(direction)
				if policy!="hold_forward":
					if i%60==0:Input.action_press("jump")
					if i%60==40:Input.action_release("jump")
				if policy=="repeat_flat_dash":
					if i%60==16:Input.action_press("dash")
					if i%60==22:Input.action_release("dash")
				if world.player.input_locked:Input.action_press("skip_dialogue")
				else:Input.action_release("skip_dialogue")
				await frames(1)
				var at:=world.player.global_position-room.global_position
				furthest=maxf(furthest,at.distance_to(start))
				if world.player.state==Player.State.DEAD:died=true;break
				if at.distance_to(target)<18 and world.player.is_on_floor():solved=true;break
			release()
			results.append({"room":recipe.name,"strategy":policy,"reached_end":solved,"died":died,"furthest_px":furthest})
			print("SHORTCUT ",recipe.name," ",policy," reached_end=",solved," died=",died)
			if policy=="hold_forward" and solved:failures+=1
	FileAccess.open("res://output/act2_redesign/final_shortcut_results.json",FileAccess.WRITE).store_string(JSON.stringify(results,"\t"))
	print("FINALE HOLD-FORWARD: ",failures," rooms trivialized")
	get_tree().quit(1 if failures else 0)
