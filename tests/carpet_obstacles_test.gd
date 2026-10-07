extends Node
## Negative controls: neither passive riding nor held vertical steering can
## cross a split passage. Positive, same-instance recatches live in act2_routes.
var failures:=0
func _ready() -> void:
	SaveGame.slot=-1
	LdtkWorld.debug_start_room="Act_2_Level_10"
	Screen.load_scene("res://ldtk/Act2World.tscn")
	await frames(12)
	var world:=Screen.current as LdtkWorld
	var player:=world.player
	for node in get_tree().get_nodes_in_group("exit"):node.set_deferred("monitoring",false)
	var recipes: Array=JSON.parse_string(FileAccess.get_file_as_string("res://resources/levels/act2_expansion.json"))
	for recipe: Dictionary in recipes:
		for route: Dictionary in recipe.routes:
			if route.kind!="weave":continue
			var room: Node2D
			for candidate in world.rooms:
				if str(candidate.name)==recipe.name:room=candidate
			for action in ["", "move_up", "move_down"]:
				world._enter_room(room,true)
				MagicCarpet.reset_all(get_tree())
				var carpet: MagicCarpet
				for node in room.get_node("Entities").get_children():
					if node is MagicCarpet and absf(node._origin.x-float(route.carpet))<1:carpet=node
				player.respawn(carpet.global_position-Vector2(0,10))
				player._ledge_cooldown=3600.0
				await frames(12)
				check(carpet.activated,"probe starts aboard an activated carpet")
				if action!="":Input.action_press(action)
				var furthest:=player.global_position.x-room.global_position.x
				for i in 300:
					await frames(1)
					furthest=maxf(furthest,player.global_position.x-room.global_position.x)
					if player.state==Player.State.DEAD:break
				if action!="":Input.action_release(action)
				var obstacle: Array=route.islands[0]
				check(furthest<float(obstacle[0]+obstacle[1]),"%s %s cannot bypass required dismount" % [recipe.name,"passive ride" if action=="" else action])
				# Drain a pending real death recovery before the next isolated probe.
				await get_tree().create_timer(0.8).timeout
	print("CARPET_OBSTACLES: ",failures," failures")
	get_tree().quit(0 if failures==0 else 1)
func frames(n:int) -> void:
	for i in n:await get_tree().physics_frame
func check(ok:bool,label:String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
