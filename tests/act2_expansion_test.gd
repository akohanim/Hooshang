extends Node
## Imported-room acceptance: real physics contacts, reach, retry and routing.
var failures := 0
var world: LdtkWorld
var player: Player
func _ready() -> void:
	SaveGame.slot = -1
	LdtkWorld.debug_start_room = "Act_2_Level_3"
	Screen.load_scene("res://ldtk/Act2World.tscn")
	await frames(8)
	world = Screen.current as LdtkWorld
	player = world.player
	player.has_dash = true
	for node in get_tree().get_nodes_in_group("exit"):node.set_deferred("monitoring",false)
	var recipes: Array = JSON.parse_string(FileAccess.get_file_as_string("res://resources/levels/act2_expansion.json"))
	for recipe: Dictionary in recipes:
		var only:=OS.get_cmdline_user_args()
		if not only.is_empty() and str(recipe.name) not in only:continue
		var room: Node2D
		for candidate in world.rooms:
			if str(candidate.name)==recipe.name:room=candidate
		check(room!=null,recipe.name+" imported")
		if room==null:continue
		world._enter_room(room,true)
		player.respawn(world.spawn_point_for(room))
		await frames(20)
		check(player.is_on_floor(),recipe.name+" entrance has solid footing")
		check(room.has_node("SkyGarden"),recipe.name+" garden art attached")
		var exit := world._exit_in(room)
		check(exit!=null,recipe.name+" destination present")
		if not recipe.get("final",false):check(world._next_room(exit)!=null,recipe.name+" routes onward")
		for node in room.get_node("Entities").get_children():
			if not is_instance_valid(node):continue
			if node is SpringPlatform or node is Checkpoint or node is MagicCarpet:
				# Drain deferred spring contacts and any pending recovery before
				# teleporting between otherwise independent prop checks.
				player.respawn(world.spawn_point_for(room))
				await frames(65)
			if node is SpringPlatform and absf(node.rotation)<0.1:
				player.respawn(node.global_position+Vector2(0,-24))
				player.input_locked=true
				var launched:=false
				var minimum:float=player.global_position.y
				for i in 65:
					await frames(1)
					launched=launched or player.velocity.y < -300
					minimum=minf(minimum,player.global_position.y)
				check(launched,"%s spring %s launches on contact" % [recipe.name,node.position])
				check(node.global_position.y-minimum>54,"spring has clear arc headroom")
			if node is Checkpoint:
				player.respawn(node.global_position)
				await frames(25)
				check(player.is_on_floor(),"checkpoint has safe footing")
				check(node.is_active,"touching checkpoint activates it")
				player.die()
				await get_tree().create_timer(maxf(world.respawn_delay,player.death_time)+0.25).timeout
				check(player.state!=Player.State.DEAD and player.is_on_floor() and player.global_position.distance_to(node.global_position)<5,"death returns safely to the earned checkpoint")
			if node is MagicCarpet:
				node.reset()
				player.respawn(node.global_position+Vector2(0,-10))
				player.input_locked=true
				await frames(10)
				var carried:=0
				for i in 25:
					await frames(1)
					if node.carrying(player):carried+=1
				check(carried>20,"%s carpet supports the player before the first obstacle (%d/25)" % [recipe.name,carried])
		player.input_locked=false
	print("ACT2_EXPANSION: ",failures," failures")
	get_tree().quit(0 if failures==0 else 1)
func frames(count:int) -> void:
	for i in count:await get_tree().physics_frame
func check(ok:bool,label:String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
