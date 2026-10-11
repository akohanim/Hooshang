extends Node
## Disk-backed epilogue retry/resume and physical Enter back to the title.
var failures: Array[String]=[]
func _ready() -> void:
	var menu := preload("res://scenes/ui/MainMenu.tscn").instantiate()
	add_child(menu)
	menu.hide()
	menu.process_mode=Node.PROCESS_MODE_DISABLED
	SaveGame.dir="user://act2_ending_acceptance_saves"
	SaveGame.erase(0)
	SaveGame.unbind()
	SaveGame._bind(0)
	LdtkWorld.debug_start_room="Act_2_Level_20"
	Screen.load_scene("res://ldtk/Act2World.tscn")
	await frames(30)
	var world=Screen.current
	# A normal journey already completed the childhood pond scene. Its restored
	# scenery must not replace the epilogue's adult player or waking staging.
	world.story_flags["pond_dawn"]=true
	await skip_scene(world.get_node("Act2Ending"))
	check(world.story_flags.get("pond_return",false),"pond skip reaches dry bank")
	world.player.die()
	await frames(100)
	check(world.current_room.name=="Act_2_Level_20" and world.player.is_on_floor() and not world.player.input_locked,"pond death retries safely without replay")
	check(SaveGame.save_now(),"pond endpoint writes to disposable save slot")
	SaveGame.unbind()
	check(SaveGame.resume(0),"pond save reloads from disk")
	await frames(35)
	world=Screen.current
	var ending=world.get_node("Act2Ending")
	check(not ending.playing and world.story_flags.get("pond_return",false),"disk resume skips finished pond dialogue")
	check(world.player.visual.sprite_frames==ending.ADULT and not world.player.childhood_momentum,"disk resume keeps adult art and movement")
	Input.action_press("move_right")
	for i in 300:
		await frames(1)
		if ending.playing:break
	Input.action_release("move_right")
	check(world.current_room.name=="Act_2_Level_21","actual movement reaches final wall through authored exit")
	await skip_scene(ending)
	check(ending._shown and Game.completed,"painting skip reaches real completion")
	check(SaveGame.save_now(),"completion writes to save slot")
	SaveGame.unbind()
	check(SaveGame.resume(0),"completed save reloads from disk")
	await frames(40)
	world=Screen.current
	ending=world.get_node("Act2Ending")
	check(ending._shown and not ending.playing and Game.completed,"completed disk save resumes at end card")
	check(world.player.global_position.distance_to(ending._mark(21,"Home"))<1,"completed disk save restores home endpoint")
	var event:=InputEventKey.new()
	event.physical_keycode=KEY_ENTER
	event.keycode=KEY_ENTER
	event.pressed=true
	Input.parse_input_event(event)
	await frames(2)
	event=InputEventKey.new()
	event.physical_keycode=KEY_ENTER
	event.keycode=KEY_ENTER
	event.pressed=false
	Input.parse_input_event(event)
	await frames(25)
	check(Screen.current==null and menu.visible and SaveGame.slot==-1,"Enter returns to title and unbinds the save")
	SaveGame.unbind()
	SaveGame.erase(0)
	print("ENDING SAVE: ","ALL PASS" if failures.is_empty() else failures)
	get_tree().quit(0 if failures.is_empty() else 1)
func skip_scene(ending: Node) -> void:
	for i in 200:
		await frames(1)
		if Dialogue._active:break
	Input.action_press("skip_dialogue")
	Dialogue._process(Dialogue.skip_hold_time+.1)
	Input.action_release("skip_dialogue")
	for i in 200:
		await frames(1)
		if not ending.playing:break
func frames(n:int)->void:
	for i in n:await get_tree().physics_frame
func check(ok:bool,label:String)->void:
	print(("PASS " if ok else "FAIL ")+label)
	if not ok:failures.append(label)
