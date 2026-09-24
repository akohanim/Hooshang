extends Node
## Play both preserved conversations through the real dialogue box, then verify
## the existing authored handoff. No line data is replaced or emitted by this test.
var world:LdtkWorld
var pages:Array[String]=[]
var last_page:=""
var failures:Array[String]=[]
func _ready()->void:
	get_tree().current_scene=null
	SaveGame.slot=-1
	LdtkWorld.debug_start_room="Level_14"
	world=load("res://ldtk/Act1World.tscn").instantiate()
	Screen.set_scene(world)
	await frames(8)
	var destination:String=world.get_node("Act1Beats").act_two_scene
	var boss:=world.current_room
	world.player.has_dash=true
	check(await approach(148,false),"reveal approach reaches the first gap")
	check(await approach(240,true),"reveal approach clears the first gap")
	check(await approach(284,false),"reveal approach reaches the second gap")
	check(await approach(380,true),"reveal approach clears the second gap")
	check(await approach(520,false),"reveal approach reaches the story trigger")
	var started:=false
	for i in 2400:
		await tick()
		if world._way_back.get("Level_14","")=="Level_15":started=true
		var shadow:Darkshang=get_tree().get_first_node_in_group("darkshang")
		if started and shadow.state==Darkshang.State.FOLLOWING and not world.player.input_locked:break
	check(started,"crossing the real reveal trigger routes the escape")
	var reveal:=" ".join(pages)
	for phrase in ["What is that", "seed you have sown", "No one can fight", "Don't let it absorb"]:
		check(phrase in reveal,"reveal preserves: "+phrase)
	var home:Node2D
	for room in world.rooms:
		if room.name=="Level_25":home=room
	world._enter_room(home,true)
	await frames(5)
	check(not world.player.input_locked,"homecoming arrival allows movement")
	pages.clear();last_page=""
	Input.action_press("move_left")
	for i in 4800:
		await tick()
		if world.player.input_locked:Input.action_release("move_left")
		if Screen.current!=world:break
	Input.action_release("move_left")
	var ending:=" ".join(pages)
	for phrase in ["gone", "stop watering it", "stop", "Let the thought come", "its origin story"]:
		check(phrase in ending,"final conversation preserves: "+phrase)
	await frames(5)
	check(Screen.current_path()==destination,"final dialogue preserves its authored handoff")
	print("ACT I FINALE: %d failures" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
func tick()->void:
	await frames(1)
	if Dialogue.visible:
		var page:String=Dialogue._page_raw
		if page!=last_page and page!="":
			last_page=page;pages.append(page)
		if Engine.get_physics_frames()%4==0:
			var event:=InputEventAction.new()
			event.action="jump";event.pressed=true
			Input.parse_input_event(event)
func frames(n:int)->void:
	for i in n:await get_tree().physics_frame
func check(ok:bool,label:String)->void:
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)

func approach(x:float,jump:bool)->bool:
	Input.action_press("move_right")
	if jump:Input.action_press("jump")
	for i in 240:
		await frames(1)
		if i==14:Input.action_release("jump")
		if world.player.state==Player.State.DEAD:
			Input.action_release("move_right");Input.action_release("jump");return false
		if world.player.input_locked or (world.player.global_position.x-world.current_room.global_position.x>=x and world.player.is_on_floor()):
			Input.action_release("move_right");Input.action_release("jump");return true
	Input.action_release("move_right");Input.action_release("jump");return false
