extends Node2D
## Author-script finale. Each completed scene has one durable resume endpoint.
signal act_completed
const TEXT := preload("res://resources/dialogue/act2_author_script.tres")
const ADULT := preload("res://assets/characters/hooshang/hooshang_frames.tres")
const PLAYER := preload("res://scenes/characters/hooshang/Hooshang.tscn")
const FAREWELL := preload("res://assets/characters/hooshang_child/act2_ending/farewell_frames.tres")
var releasing_hand := false
var jamshid_saluting := false
var _splash_on_arrival := false
var world: Node
var playing := false
var chapter := ""
var line_index := -1
var _adult_applied := false
var _camera_bottom := 0
var _camera_position := Vector2.ZERO
var _card_age := 0.0
var _shown := false
var paint_progress := 0.0:
	set(value):
		paint_progress = value
		if is_node_ready():
			$Wall/SecondLine.material.set_shader_parameter("progress", value)
			$Gestures.ink_target = $Wall/SecondLine.global_position + Vector2(232*(1.0-value),10)
## Tweened only to hold the breath after the finale's school bell for a beat
## the scene skip can still cut short; nothing reads it.
var _breath := 0.0
var coat_collected := false
var coat_carried := false
var _coat_placed := false
@onready var stage: Node2D = $Cinema/Stage
@onready var flight: Node2D = $Cinema/Stage/Flight
@onready var fade: ColorRect = $Curtain/Fade

func _ready() -> void:
	world = get_parent()

func _physics_process(delta: float) -> void:
	if world.current_room == null: return
	var name: String = str(world.current_room.name)
	if name in ["Act_2_Level_20","Act_2_Level_21"]: _become_adult()
	$Rod.visible = name == "Act_2_Level_20"
	if $Rod.visible:
		$Rod.global_position = _mark(20,"Rod")
		for entity in world.current_room.get_node("Entities").get_children():
			var sign: Node = entity.get_node_or_null("ExitSign")
			if sign != null: sign.hide()
	$Wall.visible = name == "Act_2_Level_21"
	if $Wall.visible: $Wall.global_position = _mark(21,"Wall")
	$Coat.visible = name == "Act_2_Level_21" and (not coat_collected or coat_carried) and not _shown
	if $Coat.visible and not _coat_placed:
		$Coat.global_position = _mark(21,"Painter") + Vector2(20,3)
		_coat_placed = true
	if coat_carried: $Coat.global_position = world.player.global_position + Vector2(-6,0)
	if world.story_flags.get("act2_complete",false):
		if not _shown: _show_complete(false)
		_card_age += delta
		return
	if playing or world._transitioning or world.player.input_locked: return
	match name:
		"Act_2_Level_19":
			if world.story_flags.get("carpet_farewell",false): _travel_to_pond()
			elif world.story_flags.get("wall_reunion",false): _carpet()
		"Act_2_Level_20":
			if not world.story_flags.get("pond_return",false): _pond()
		"Act_2_Level_21":
			if world.player.global_position.x >= _mark(21,"Painter").x-24 and world.player.is_on_floor(): _paint()

func _room(number: int) -> Node2D:
	for room in world.rooms:
		if room.name == "Act_2_Level_%d"%number: return room
	return null

func _mark(number: int, role: String) -> Vector2:
	var room := _room(number)
	if room != null:
		for node in room.get_node("Entities").get_children():
			if node.get_meta("finale_role","") == role: return node.global_position
	push_error("Missing authored ending mark: %d/%s"%[number,role])
	return Vector2.ZERO

func _begin(name: String) -> void:
	playing = true
	chapter = name
	Dialogue.begin_conversation(self,world.player,true)
	world.player.cancel_dialogue_motion()
	_camera_bottom = world.player.camera.limit_bottom
	_camera_position = world.player.camera.position
	world.player.camera.limit_bottom += 64
	world.player.camera.reset_smoothing()

func _finish(flag: String) -> void:
	world.get_node("Act2Audio").stop_cinematics()
	world.story_flags[flag] = true
	world.player.visible = true
	world.player.camera.limit_bottom = _camera_bottom
	world.player.camera.position = _camera_position
	world.player.camera.reset_smoothing()
	Dialogue.end_conversation()
	playing = false
	line_index = -1
	SaveGame.save_now()

func _say(line: Dictionary, adult := false) -> void:
	if Dialogue.scene_skip_requested(self): return
	var speaker: String = line.speaker
	var face: Texture2D = null
	if speaker == "HOOSHANG": face = Act1Beats.FACES.vulnerable if adult else Act2Beats.CHILD_FACES.get(line.get("face","neutral"),Act2Beats.CHILD_FACES.neutral)
	elif speaker == "JAMSHID": face = Jamshid.portrait(line.get("face","sad"))
	elif speaker == "RUMI": face = Act1Beats.RUMI_FACES.serene
	await Dialogue.say(speaker.capitalize(),line.text,Color.WHITE if face != null else Color.TRANSPARENT,face,
		DialogueBox.Side.LEFT if speaker=="HOOSHANG" else DialogueBox.Side.RIGHT,DialogueBox.VSide.BOTTOM)

func _animate(node: Node, property: String, value: Variant, seconds: float) -> void:
	if Dialogue.scene_skip_requested(self): return
	var tween := create_tween()
	tween.tween_property(node,property,value,seconds)
	while tween.is_running() and not Dialogue.scene_skip_requested(self):
		await get_tree().process_frame
	if tween.is_valid(): tween.kill()

func _carpet() -> void:
	_begin("carpet")
	var guide: Node2D = _room(19).get_node("ChaseRoom").guides[0]
	var mark := _mark(19,"Carpet")
	$GroundCarpet.global_position = mark+Vector2(80,-24)
	$GroundCarpet.show()
	await _animate($GroundCarpet,"global_position",mark,0.8)
	# Each beat is staged just BEFORE the line it is anchored to (Act2Script.cue).
	var boards: int = TEXT.cue("carpet", "Move over.")
	var lifts: int = TEXT.cue("carpet", "No. No, no.")
	var alley: int = TEXT.cue("carpet", "I can fix it.")
	var corridor: int = TEXT.cue("carpet", "Tell me what I missed.")
	var drained: int = TEXT.cue("carpet", "Don't.")
	var arrest: int = TEXT.cue("carpet", "Whose is this?")
	var mother: int = TEXT.cue("carpet", "Where is my son?")
	var rain: int = TEXT.cue("carpet", "I should have said they were mine.")
	var hold_on: int = TEXT.cue("carpet", "Please let go.")
	# "(Hooshang looks at their hands. The bright letters change.)" — his "No."
	# is the very next line.
	var let_go := hold_on + 1
	for i in TEXT.scenes.carpet.size():
		line_index = i
		if Dialogue.scene_skip_requested(self): break
		if i == boards: await _animate(guide,"global_position",mark+Vector2(0,-4),0.5)
		if i == lifts:
			stage.show()
			$GroundCarpet.hide()
			guide.hide()
			world.player.hide()
			var child: AnimatedSprite2D = $Cinema/Stage/Flight/Child
			child.sprite_frames = FAREWELL
			child.scale = world.player.visual.scale
			child.offset = world.player.visual.offset
			child.play("hold")
			await _animate($Cinema/Stage/Night,"color:a",0.45,0.8)
		if i == alley: await _flash_memory("arrest",0.9)
		if i == corridor: await _flash_memory("corridor",1.0)
		if i == drained:
			# "There were never any keys." The music stops; the colour drains.
			if world._music != null: world._music.stop()
			await _animate($Cinema/Stage/Night,"color:a",1.0,0.7)
		if i == arrest: _show_memory("arrest")
		if i == mother: _show_memory("mother")
		if i == rain: await _flash_memory("rain",1.8)
		if i == hold_on:
			# "Look." Far below, at the edge of the dark, the sun is coming up.
			await _animate($Cinema/Stage/Morning,"modulate:a",0.35,0.8)
			$Cinema/Stage/Prompt.text = "HOLD ON"
		if i == let_go: $Cinema/Stage/Prompt.text = "LET GO"
		await _say(TEXT.scenes.carpet[i])
	if not Dialogue.scene_skip_requested(self):
		$Cinema/Stage/Prompt.text = ""
		await _animate($Cinema/Stage/Morning,"modulate:a",1.0,0.8)
		releasing_hand = true
		$Cinema/Stage/Flight/Child.play("release")
		# A visible decision before gravity takes him. The hold remains skippable.
		await _animate($Cinema/Stage/Flight/Child,"position:y",12.0,1.02)
		releasing_hand = false
		$Cinema/Stage/Flight/Child.play("fall_rest")
		await _animate($Cinema/Stage/Flight/Child,"position:y",200.0,1.35)
		if not Dialogue.scene_skip_requested(self):
			jamshid_saluting = true
			$Cinema/Stage/Flight/Jamshid.hide()
			$Cinema/Stage/Flight/Salute.show()
			# The returning gesture links the farewell to adult Hooshang's salute.
			await _animate(flight,"position:y",flight.position.y-8.0,0.45)
			await _animate(flight,"position:y",-32.0,1.1)
	jamshid_saluting = false
	$Cinema/Stage/Flight/Salute.hide()
	releasing_hand = false
	await _animate(fade,"color:a",1.0,0.3)
	stage.hide()
	$GroundCarpet.hide()
	guide.hide()
	var with_splash := not Dialogue.scene_skip_requested(self)
	_finish("carpet_farewell")
	await _travel_to_pond(with_splash)

func _ring_school_bell() -> void:
	var bell := AudioStreamPlayer.new()
	bell.stream = Act2Beats.school_bell_stream()
	add_child(bell)
	bell.finished.connect(bell.queue_free)
	bell.play()


func _show_memory(kind: String) -> void:
	$Cinema/Stage/Memory.show_memory(kind)
	flight.hide()

func _flash_memory(kind: String, seconds: float) -> void:
	if Dialogue.scene_skip_requested(self): return
	_show_memory(kind)
	# The unchanged alpha holds a silent image while remaining cancellable.
	await _animate($Cinema/Stage/Memory,"modulate:a",1.0,seconds)
	$Cinema/Stage/Memory.hide()
	flight.show()

func _travel_to_pond(with_splash := false) -> void:
	playing = true
	_splash_on_arrival = with_splash
	await world.transition_with_sequence(_room(20),_fade_out,_pond_arrival)
	playing = false

func _fade_out() -> void:
	await _animate(fade,"color:a",1.0,0.25)

func _pond_arrival() -> void:
	_become_adult()
	if _splash_on_arrival: world.get_node("Act2Audio").play_cue(&"Splash")
	_splash_on_arrival = false
	await _animate(fade,"color:a",0.0,0.5)

func _become_adult() -> void:
	if _adult_applied: return
	_adult_applied = true
	world.player.visual.sprite_frames = ADULT
	# Restore this instance's authored adult profile, never the shared prefab.
	var defaults := PLAYER.instantiate()
	for property in ["childhood_momentum","max_run_speed","ground_accel","ground_decel","dash_end_speed","air_accel_mult","air_decel_mult","jump_speed","use_jump_hold","jump_cut_multiplier","rise_gravity","fall_gravity","max_fall_speed","apex_threshold","spring_impulse_scale"]:
		world.player.set(property,defaults.get(property))
	for property in ["jump_squash_scale","land_squash_scale","squash_ease_time"]:
		world.player.juice.set(property,defaults.get_node("Juice").get(property))
	defaults.free()
	world.player._update_visual()

func _pond() -> void:
	_begin("second_line")
	world.player.global_position = _mark(20,"Immersion")
	world.player.visual.play("swim_idle")
	$Rumi.global_position = _mark(20,"Immersion")+Vector2(40,-12)
	$Rumi.modulate.a = 0
	$Rumi.show()
	await _animate($Rumi,"modulate:a",1.0,0.8)
	# THE FALL is spoken underwater; THE BANK once he has dragged himself out.
	var lines: Array = TEXT.scenes.fall + TEXT.scenes.bank
	var on_bank: int = TEXT.scenes.fall.size()
	# "(Very gently, Rumi's glow begins to thin.)"
	var thins: int = on_bank + TEXT.cue("bank", "Wait. Where are you going?")
	for i in lines.size():
		line_index = i
		if Dialogue.scene_skip_requested(self): break
		if i == on_bank:
			await _animate(world.player,"global_position",_mark(20,"Bank"),1.2)
			$Rumi.global_position = _mark(20,"Rumi")
			world.player.cutscene_rest(true,-1)
		if i == thins: await _animate($Rumi,"modulate:a",0.5,0.8)
		await _say(lines[i],true)
	await _animate($Rumi,"modulate:a",0.0,0.8)
	$Rumi.hide()
	world.player.global_position = _mark(20,"Bank")
	world.player.cutscene_rest(false,1)
	world.set_story_checkpoint(_room(20),_mark(20,"Bank"))
	_finish("pond_return")

func _paint() -> void:
	_begin("paint")
	world.player.global_position = _mark(21,"Painter")
	$Gestures.can = $Wall/Can
	$Gestures.pose(world.player,"pickup",1)
	await _animate($Wall/Can,"global_position",world.player.global_position+Vector2(8,-7),0.7)
	$Gestures.holding_can = true
	# "Keep going." — Jamshid, unseen, across fifty years.
	line_index = 0
	await _say(TEXT.scenes.second_line[0],true)
	$Wall/SecondLine.show()
	paint_progress = 0.0
	if not Dialogue.scene_skip_requested(self):
		$Gestures.release()
		$Gestures.holding_can = true
		world.player.look(1)
		world.player.visual.play("run")
		await _animate(world.player,"global_position:x",$Wall/SecondLine.global_position.x+240,1.4)
		$Gestures.pose(world.player,"paint",-1)
		$Gestures.holding_can = true
		$Gestures.spraying = true
		world.get_node("Act2Audio").play_cue(&"Spray")
		var stroke := create_tween().set_parallel()
		stroke.tween_property(self,"paint_progress",1.0,4.0)
		stroke.tween_property(world.player,"global_position:x",$Wall/SecondLine.global_position.x+8,4.0)
		while stroke.is_running() and not Dialogue.scene_skip_requested(self): await get_tree().process_frame
		if stroke.is_valid(): stroke.kill()
	world.get_node("Act2Audio").get_node("Spray").stop()
	$Gestures.release()
	$Wall/Can.hide()
	paint_progress = 1.0
	world.player.look(1)
	$Gestures.pose(world.player,"walk_home",1)
	await _animate(world.player,"global_position",_mark(21,"Painter"),0.9)
	world.player.cutscene_rest(false,-1)
	$Gestures.pose(world.player,"paint_idle",-1)
	await _animate($Wall/Sunlight,"color:a",0.18,0.8)
	# The verse read aloud, then "Took me long enough." The last line waits for
	# the carpet and the bell.
	var home: int = TEXT.scenes.second_line.size() - 1
	for i in range(1, home):
		line_index = i
		await _say(TEXT.scenes.second_line[i],true)
	$Wall/SecondLine.modulate.a = 1
	$Wall/Can.hide()
	if not Dialogue.scene_skip_requested(self):
		await _animate(world.player.camera,"position:y",_camera_position.y-64,0.65)
		$GroundCarpet.scale = Vector2(0.65,0.65)
		$GroundCarpet.global_position = _room(21).global_position+Vector2(100,56)
		$GroundCarpet.show()
		$Gestures.pose(world.player,"salute",1)
		await _animate($GroundCarpet,"global_position",_room(21).global_position+Vector2(430,44),1.8)
		$GroundCarpet.hide()
		$Gestures.pose(world.player,"paint_idle",1)
		await _animate(world.player.camera,"position:y",_camera_position.y,0.65)
		# "(Far off, a school bell rings.)" Once he would have run, toward it or
		# away. Now he stops, breathes in, breathes out.
		_ring_school_bell()
		_breath = 0.0
		await _animate(self,"_breath",1.0,1.8)
		line_index = home
		await _say(TEXT.scenes.second_line[home],true)
		world.player.look(1)
		$Gestures.pose(world.player,"walk_home",1)
		await _animate(world.player,"global_position:x",_mark(21,"Painter").x+20,0.4)
		$Gestures.pose(world.player,"pickup_coat",1)
		await _animate($Coat,"global_position",world.player.global_position+Vector2(7,-6),0.7)
		coat_collected = true
		coat_carried = true
		$Gestures.pose(world.player,"walk_home",1)
		await _animate(world.player,"global_position",_mark(21,"Home"),2.0)
		$Gestures.pose(world.player,"paint_idle",1)
	await _animate(fade,"color:a",0.9,0.8)
	_finish("act2_complete")
	_show_complete(true)

func _show_complete(emit_event: bool) -> void:
	_shown = true
	$Gestures.release()
	coat_collected = true
	coat_carried = false
	$Coat.hide()
	$Wall/Sunlight.color.a = 0.18
	paint_progress = 1.0
	if world.current_room == _room(21):
		world.player.global_position = _mark(21,"Home")
		world.set_story_checkpoint(_room(21),_mark(21,"Home"))
	$Wall/SecondLine.show()
	$Wall/SecondLine.modulate.a = 1
	$Wall/Can.hide()
	fade.color.a = 0.9
	$Curtain/EndCard.show()
	world.player.freeze()
	Game.completed = true
	SaveGame.save_now()
	if emit_event: act_completed.emit()

func _unhandled_input(event: InputEvent) -> void:
	if _shown and _card_age > 0.4 and event.is_action_pressed("ui_accept"):
		SaveGame.save_now()
		# Consume Enter before replacing this scene, so it cannot select a
		# title-menu item in the same input dispatch.
		get_viewport().set_input_as_handled()
		get_tree().root.set_input_as_handled()
		MainMenu.open(get_tree())
