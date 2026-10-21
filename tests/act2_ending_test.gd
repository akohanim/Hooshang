extends Node
## Full authored dialogue and skip/save endpoints; staging starts from debug rescue.
const TEXT := preload("res://resources/dialogue/act2_author_script.tres")
var failures: Array[String] = []
func _ready() -> void:
	SaveGame.slot=-1
	SaveGame._pending={}
	for mode in ["full","early_skip","late_skip","stroke_skip","salute_skip","release_skip","memory_skip","jamshid_salute_skip"]:await run_case(mode)
	print("ACT2 ENDING: ","ALL PASS" if failures.is_empty() else failures)
	get_tree().quit(0 if failures.is_empty() else 1)
func run_case(mode: String) -> void:
	Game.completed=false
	LdtkWorld.debug_start_room="Act_2_Level_19"
	var world=load("res://ldtk/Act2World.tscn").instantiate()
	add_child(world)
	await frames(20)
	world.story_flags["wall_reunion"]=true
	world.player.respawn(world.current_room.global_position+Vector2(240,194))
	var ending=world.get_node("Act2Ending")
	var cues: Array[StringName] = []
	world.get_node("Act2Audio").cue_started.connect(func(cue): cues.append(cue))
	var completions=[0]
	ending.act_completed.connect(func():completions[0]+=1)
	# "late_skip" holds X once each chapter reaches its closing stretch: the
	# carpet's "Please let go.", the pond's "Wait. Where are you going?" (counted
	# across the fall and the bank, which play as one conversation), and the
	# lines after the painting.
	var late_skip_at := {
		"carpet": TEXT.cue("carpet","Please let go."),
		"second_line": TEXT.scenes.fall.size()+TEXT.cue("bank","Wait. Where are you going?"),
		"paint": 1,
	}
	var seen: Array[String]=[]
	var last=""
	var checked_pond=false
	var gestures: Array[String] = []
	var saw_partial_paint := false
	var saw_carried_coat := false
	var stroke_skip_sent := false
	var salute_skip_sent := false
	var saw_release := false
	var saw_jamshid_salute := false
	var jamshid_skip_sent := false
	var saw_lowered_hands := false
	var release_skip_sent := false
	var memories: Array[String] = []
	var memory_skip_sent := false
	Engine.time_scale=8
	for tick in 24000:
		await frames(1)
		if ending._shown:break
		var actor: AnimatedSprite2D = ending.get_node("Gestures/Actor")
		var memory = ending.get_node("Cinema/Stage/Memory")
		if memory.is_visible_in_tree():
			if not memories.has(memory.current): memories.append(memory.current)
			if mode == "memory_skip" and memory.current == "rain" and not memory_skip_sent:
				memory_skip_sent = true
				Input.action_press("skip_dialogue")
				Dialogue._process(Dialogue.skip_hold_time+.1)
				Input.action_release("skip_dialogue")
		if ending.jamshid_saluting:
			saw_jamshid_salute = ending.get_node("Cinema/Stage/Flight/Salute").is_visible_in_tree() and not ending.get_node("Cinema/Stage/Flight/Jamshid").visible and ending.get_node("Cinema/Stage/Morning").modulate.a == 1.0
			if mode == "jamshid_salute_skip" and not jamshid_skip_sent:
				jamshid_skip_sent = true
				Input.action_press("skip_dialogue")
				Dialogue._process(Dialogue.skip_hold_time+.1)
				Input.action_release("skip_dialogue")
		if ending.releasing_hand:
			saw_release = true
			saw_lowered_hands = saw_lowered_hands or ending.get_node("Cinema/Stage/Flight/Child").frame >= 3
			if mode == "release_skip" and not release_skip_sent:
				release_skip_sent = true
				Input.action_press("skip_dialogue")
				Dialogue._process(Dialogue.skip_hold_time+.1)
				Input.action_release("skip_dialogue")
		if actor.visible and not gestures.has(str(actor.animation)): gestures.append(str(actor.animation))
		if actor.visible and actor.animation == &"walk_home" and ending.coat_carried and ending.get_node("Coat").visible:
			saw_carried_coat = true
		if mode == "salute_skip" and actor.visible and actor.animation == &"salute" and not salute_skip_sent:
			salute_skip_sent = true
			Input.action_press("skip_dialogue")
			Dialogue._process(Dialogue.skip_hold_time+.1)
			Input.action_release("skip_dialogue")
		if ending.paint_progress > 0.1 and ending.paint_progress < 0.9:
			saw_partial_paint = true
			if mode == "stroke_skip" and not stroke_skip_sent:
				stroke_skip_sent = true
				Input.action_press("skip_dialogue")
				Dialogue._process(Dialogue.skip_hold_time+.1)
				Input.action_release("skip_dialogue")
		if world.story_flags.get("pond_return",false) and not checked_pond:
			checked_pond=true
			check(not Game.completed,"pond is not premature act completion")
			check(not world.player.childhood_momentum and world.player.visual.sprite_frames==ending.ADULT,"adult appearance and profile return at the pond")
			check(not world.player.input_locked and not world.player._frozen,"pond scene restores playable control")
			check(world._return_room==null,"waking pond cannot backtrack into the invented prison")
			check(world._checkpoint.distance_to(ending._mark(20,"Bank"))<1,"pond completion banks the dry shore checkpoint")
		if checked_pond and not ending.playing:Input.action_press("move_right")
		else:Input.action_release("move_right")
		if not Dialogue._active:continue
		var token: String=str(Dialogue._generation)+":"+Dialogue._page_raw
		if token!=last:
			last=token
			seen.append(Dialogue._page_raw)
		var should_skip: bool=mode=="early_skip" or (mode=="late_skip" and ending.line_index >= late_skip_at.get(ending.chapter,999))
		if should_skip:
			Input.action_press("skip_dialogue")
			Dialogue._process(Dialogue.skip_hold_time+.1)
			Input.action_release("skip_dialogue")
		else:
			Dialogue._finish_reveal_instantly()
			Dialogue.line_finished.emit()
	Input.action_release("move_right")
	Engine.time_scale=1
	check(ending._shown and Game.completed,mode+" reaches the real ending")
	check(world.player.global_position.distance_to(ending._mark(21,"Home"))<1,mode+" reaches the same home endpoint")
	check(completions[0]==1,mode+" emits completion exactly once")
	check(world.story_flags.get("carpet_farewell",false) and world.story_flags.get("pond_return",false) and world.story_flags.get("act2_complete",false),mode+" saves all three endpoints")
	check(not Dialogue.visible and ending.get_node("Wall/SecondLine").visible,mode+" clears dialogue and completes the poem")
	check(not ending.stage.visible and not ending.get_node("Rumi").visible,mode+" clears staged actors")
	check(not world.get_node("Act2Audio/Spray").playing and not world.get_node("Act2Audio/Splash").playing,mode+" clears cinematic audio")
	if mode == "early_skip": check(cues.is_empty(), "whole-scene skips do not trigger splash or spray cues")
	check(not ending.get_node("Gestures/Actor").visible and world.player.visual.visible,mode+" restores the real player visual")
	check(ending.coat_collected and not ending.get_node("Coat").visible and ending.paint_progress == 1.0,mode+" completes paint and coat on the same endpoint")
	if mode == "stroke_skip": check(stroke_skip_sent, "skip was tested during the painting motion")
	if mode == "salute_skip": check(salute_skip_sent, "skip was tested during the raised-camera salute")
	if mode == "release_skip": check(release_skip_sent and not ending.releasing_hand, "skip during hand release clears staging and completes")
	if mode == "memory_skip": check(memory_skip_sent, "skip was tested during the silent rain memory")
	check(world.player.camera.position == ending._camera_position,mode+" restores the camera after the salute")
	if mode == "jamshid_salute_skip": check(jamshid_skip_sent and not ending.jamshid_saluting and not ending.get_node("Cinema/Stage/Flight/Salute").visible,"skip during Jamshid salute clears pose and reaches the endpoint")
	if mode=="full":
		check(saw_jamshid_salute,"Jamshid returns the half-salute as the carpet rises")
		check(memories == ["arrest","corridor","mother","rain"], "all four distinct memories appear in script order")
		check(cues.count(&"Splash")==1 and cues.count(&"Spray")==1,"full ending cues water impact and painting once")
		check(saw_release and saw_lowered_hands, "full farewell animates the hand release before the fall")
		check(saw_partial_paint and gestures.has("paint") and gestures.has("pickup") and gestures.has("salute"), "full finale paints progressively, picks up props and salutes")
		check(saw_carried_coat and gestures.has("pickup_coat"), "full finale picks up and visibly carries the coat home")
		var expected: Array[String]=[]
		for scene in ["carpet","fall","bank","second_line"]:
			for line in TEXT.scenes[scene]:
				for page in Dialogue._paginate(line.text): expected.append(page)
		if seen!=expected:
			print("TEXT MISMATCH expected=",expected.size()," seen=",seen.size())
			for i in mini(seen.size(),expected.size()):
				if seen[i]!=expected[i]: print("FIRST DIFFERENCE ",i," got=",seen[i]," expected=",expected[i]); break
		check(seen==expected,"all %d author pages play in exact order"%expected.size())
	SaveGame._pending={"world_state":world.save_state()}
	LdtkWorld.debug_start_room=str(world.current_room.name)
	world.queue_free()
	await frames(3)
	world=load("res://ldtk/Act2World.tscn").instantiate()
	add_child(world)
	await frames(25)
	ending=world.get_node("Act2Ending")
	check(ending._shown and not ending.playing and Game.completed,mode+" reload shows completion without replay")
	check(world.player.visual.sprite_frames==ending.ADULT,mode+" reload preserves adult artwork")
	world.queue_free()
	await frames(3)
	SaveGame._pending={}
func frames(n: int) -> void:
	for i in n:await get_tree().physics_frame
func check(ok: bool,label: String) -> void:
	print(("PASS " if ok else "FAIL ")+label)
	if not ok:failures.append(label)
