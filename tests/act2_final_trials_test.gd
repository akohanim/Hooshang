extends "res://tests/act2_routes_test.gd"
## Connected input-only finale: actual exits, ordinary story skip, no mid-run
## respawns or position writes. Stops at the painted-wall room before its scene.
var expected := ""
var capture := false
var ticks := 0
var retry_mode := false
var retries := 0
var retried: Array[String] = []
func _ready() -> void:
	SaveGame.unbind()
	LdtkWorld.debug_start_room="Act_2_Level_16"
	Screen.load_scene("res://ldtk/Act2World.tscn")
	await frames(20)
	world=Screen.current;player=world.player
	player.died.connect(func():deaths+=1)
	continuous=true
	capture="--capture" in OS.get_cmdline_user_args()
	retry_mode="--retry" in OS.get_cmdline_user_args()
	DirAccess.make_dir_recursive_absolute("res://output/act2_redesign/finale_gameplay")
	var recipes:Array=JSON.parse_string(FileAccess.get_file_as_string("res://resources/levels/act2_final_trials.json"))
	for recipe:Dictionary in recipes:
		room=world.current_room;offset=room.global_position
		check(str(room.name)==recipe.name,"arrived in "+str(recipe.name))
		if failures:break
		player._ledge_cooldown=3600
		expected="Act_2_Level_%d" % (int(str(recipe.name).get_slice("_",3))+1)
		for step:Dictionary in recipe.routes:
			await run_step(step)
			await check_retry()
			if failures:break
		if failures:break
		for points:Array in recipe.water_paths:
			await prepare(Vector2(points[0][0],points[0][1]-6))
			for point:Array in points.slice(1):
				await swim_to(Vector2(point[0],point[1]-6))
				if failures:break
			await check_retry()
			if failures:break
		if failures:break
		for i in 300:
			if str(world.current_room.name)==expected:break
			Input.action_press("move_right")
			await frames(1)
		release()
		await frames(60)
		check(str(world.current_room.name)==expected,"actual exit to "+expected)
		check(deaths==retries,"finale has no unplanned deaths")
		if failures:break
	release();Input.action_release("skip_dialogue")
	if retry_mode:check(retries==3,"all three interior checkpoints tested")
	print("FINAL TRIALS: ",failures," failures; deaths=",deaths)
	get_tree().quit(1 if failures else 0)

func _route_exit_started() -> bool:
	return str(world.current_room.name)==expected or (world._transitioning and world.transition_target!=null and str(world.transition_target.name)==expected)

func frames(n:int) -> void:
	for i in n:
		await get_tree().physics_frame
		ticks+=1
		if is_instance_valid(player):
			if player.input_locked and not world._transitioning:Input.action_press("skip_dialogue")
			else:Input.action_release("skip_dialogue")
		if capture and is_instance_valid(player) and ticks%8==0:
			await get_tree().process_frame
			RenderingServer.force_draw()
			Screen.viewport.get_texture().get_image().save_png("res://output/act2_redesign/finale_gameplay/%s_%05d.png" % [world.current_room.name,ticks])

func prepare(at:Vector2) -> void:
	release()
	for i in 450:
		if not player.input_locked:steer(at.x)
		await frames(1)
		if not player.input_locked and absf(player.global_position.x-offset.x-at.x)<2 and absf(player.velocity.x)<8 and player.is_on_floor():break
	release()
	check(not player.input_locked and absf(player.global_position.x-offset.x-at.x)<2 and player.is_on_floor(),"reached finale departure on foot")

func swim_to(target:Vector2) -> void:
	var arrived:=false
	for i in 300:
		var at:=player.global_position-offset
		steer(target.x)
		Input.action_release("move_up");Input.action_release("move_down")
		if absf(target.y-at.y)>2:Input.action_press("move_down" if target.y>at.y else "move_up")
		if absf(target.x-at.x)<6 and absf(target.y-at.y)<6:arrived=true;break
		await frames(1)
		if player.state==Player.State.DEAD:break
	release()
	check(arrived,"finale swim "+str(target)+" actual "+str(player.global_position-offset))

func check_retry() -> void:
	if not retry_mode or str(room.name) in retried:return
	var local_checkpoint:Vector2=world._checkpoint-offset
	if local_checkpoint.x<300 or local_checkpoint.x>400:return
	if not player.is_on_floor() or player.global_position.distance_to(world._checkpoint)>24:return
	release()
	var saved:Vector2=world._checkpoint
	var old_deaths:=deaths
	player.die()
	await frames(110)
	retries+=1
	retried.append(str(room.name))
	check(deaths==old_deaths+1 and world.current_room==room and player.is_on_floor() and player.global_position.distance_to(saved)<12,"interior checkpoint gives one supported retry in "+str(room.name))
