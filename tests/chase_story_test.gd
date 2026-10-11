extends Node
## Exact author text, normal/skip endpoints and persistent story state.
const TEXT := preload("res://resources/dialogue/act2_author_script.tres")
var failures: Array[String] = []
func _ready() -> void:
	SaveGame.slot=-1
	SaveGame._pending={}
	for room_number in [16,19]:
		for skip in [false,true]:await run_case(room_number,skip)
	print("CHASE STORY: ","ALL PASS" if failures.is_empty() else failures)
	get_tree().quit(0 if failures.is_empty() else 1)
func run_case(number: int, skip: bool) -> void:
	LdtkWorld.debug_start_room="Act_2_Level_%d"%number
	var world=load("res://ldtk/Act2World.tscn").instantiate()
	world.get_node("Act2Ending").free()
	add_child(world)
	await frames(20)
	var story=world.current_room.get_node("ChaseRoom")
	var flag: String="chase_banter" if number==16 else "wall_reunion"
	var bottom: int=world.player.camera.limit_bottom
	world.player.respawn(world.current_room.global_position+Vector2(90 if number==16 else 240,194))
	var seen: Array[String]=[]
	var last: String=""
	Engine.time_scale=8
	for tick in 5000:
		await frames(1)
		if world.story_flags.get(flag,false):break
		if not Dialogue._active:continue
		if last!=Dialogue._page_raw:
			last=Dialogue._page_raw
			seen.append(last)
		if skip:
			Input.action_press("skip_dialogue")
			Dialogue._process(Dialogue.skip_hold_time+.1)
			Input.action_release("skip_dialogue")
		else:
			Dialogue._finish_reveal_instantly()
			Dialogue.line_finished.emit()
	Engine.time_scale=1
	check(world.story_flags.get(flag,false),flag+" commits its endpoint")
	check(not world.player.input_locked and not world.player._frozen,flag+" restores controls")
	check(world.player.camera.limit_bottom==bottom,flag+" restores camera")
	if not skip:
		var expected: Array[String]=[]
		for i in range(9 if number==16 else 12,12 if number==16 else 19):expected.append(TEXT.scenes.cell[i].text)
		check(seen==expected,flag+" speaks every author line in order")
	SaveGame._pending={"world_state":world.save_state()}
	world.queue_free()
	await frames(3)
	world=load("res://ldtk/Act2World.tscn").instantiate()
	world.get_node("Act2Ending").free()
	add_child(world)
	await frames(20)
	check(world.story_flags.get(flag,false),flag+" persists on reload")
	world.queue_free()
	await frames(3)
	SaveGame._pending={}
func frames(n: int) -> void:
	for i in n:await get_tree().physics_frame
func check(ok: bool,label: String) -> void:
	print(("PASS " if ok else "FAIL ")+label)
	if not ok:failures.append(label)
