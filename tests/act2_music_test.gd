extends Node
## Act 2's garden score (scripts/act2_music.gd). Headless audio does not mix,
## so this checks the parts that fail silently rather than the sound itself:
## which room plays which cue, that the cues are set up to loop and count bars,
## that the coda plays once per arrival, and rest()/resume() for the night
## encounter. The loop seams are checked offline by
## tools/gen_act2_garden_music.py's own construction.
var failures := 0


func _ready() -> void:
	SaveGame.slot = -1
	var C := Act2Music.Cue
	var rooms := {"Act_2_Level_0": C.PONDS, "Act_2_Level_1": C.PONDS, "Level_2": C.PONDS,
		"Act_2_Level_3": C.WONDER, "Act_2_Level_7": C.WONDER, "Act_2_Level_8": C.PONDS,
		"Act_2_Level_13": C.WONDER, "Act_2_Level_14": C.CODA, "Act_2_Level_15": C.REST,
		"Prison_Hub": C.PRISON, "Prison_Y03": C.PRISON, "Act_2_Level_19": C.REST}
	for room_name: String in rooms:
		var fake := Node2D.new()
		fake.name = room_name
		check(Act2Music.cue_for(fake) == rooms[room_name], "%s plays cue %d" % [room_name, rooms[room_name]])
		fake.free()

	LdtkWorld.debug_start_room = "Act_2_Level_3"
	Screen.load_scene("res://ldtk/Act2World.tscn")
	for i in 20: await get_tree().physics_frame
	var world := Screen.current as LdtkWorld
	var music := world.get_node_or_null("Music") as Act2Music
	check(music != null, "Act 2 world has its Music player")
	if music == null:
		_finish()
		return
	check(music.bus == &"Music", "on the Music bus, so the pause menu's MUSIC row mutes it")
	check(world._music == music, "LdtkWorld ducks it under dialogue")
	var stream := music.stream as AudioStreamInteractive
	check(stream != null and stream.clip_count == 6, "six cues in one interactive stream")
	if stream != null:
		for i in [C.PONDS, C.WONDER, C.REST]:
			var ogg := stream.get_clip_stream(i) as AudioStreamOggVorbis
			check(ogg != null and ogg.loop and is_equal_approx(ogg.bpm, 100.0) and ogg.bar_beats == 4,
				"%s loops and counts bars at 100 BPM" % stream.get_clip_name(i))
		var cell := stream.get_clip_stream(C.PRISON) as AudioStreamOggVorbis
		check(cell != null and cell.loop and is_equal_approx(cell.bpm, 60.0) and absf(cell.get_length() - 64.0) < 0.1,
			"the prison theme loops 16 bars at its own 60 BPM")
		for i in [C.INTRO, C.CODA]:
			check(not (stream.get_clip_stream(i) as AudioStreamOggVorbis).loop, "%s plays once" % stream.get_clip_name(i))
		check(stream.get_clip_auto_advance_next_clip(C.INTRO) == C.PONDS, "intro runs into the ponds loop")
		check(stream.get_clip_auto_advance_next_clip(C.CODA) == C.REST, "the coda ends in silence")
		var ponds := (stream.get_clip_stream(C.PONDS) as AudioStreamOggVorbis).get_length()
		var wonder := (stream.get_clip_stream(C.WONDER) as AudioStreamOggVorbis).get_length()
		check(absf(ponds - 12.0) < 0.01 and absf(wonder - 14.4) < 0.01, "loops are whole bars (5 and 6)")
	check(music.playing, "music is playing in a garden room")
	check(music._cue == C.WONDER, "a garden room starts on Playful Wonder")

	music._on_room_changed(_room(world, "Act_2_Level_8"))
	check(music._cue == C.PONDS, "the breather room drops to the ponds theme")
	music._on_room_changed(_room(world, "Act_2_Level_14"))
	check(music._cue == C.CODA, "leaving the gardens plays the coda")
	music._on_room_changed(_room(world, "Act_2_Level_15"))
	music._on_room_changed(_room(world, "Act_2_Level_14"))
	check(music._cue == C.REST, "walking back into room 14 does not replay the ending")
	music._on_room_changed(_room(world, "Prison_Hub"))
	check(music._cue == C.PRISON, "the prison plays its own theme")
	music._on_room_changed(_room(world, "Act_2_Level_13"))
	check(music._cue == C.WONDER, "back in the gardens, wonder returns")

	music.rest()
	check(music._cue == C.REST, "rest() silences the score")
	music._on_room_changed(_room(world, "Act_2_Level_12"))
	check(music._cue == C.REST, "a room change during a rest stays silent")
	music.resume()
	check(music._cue == C.WONDER, "resume() brings back the room's cue")
	_finish()


func _room(world: LdtkWorld, room_name: String) -> Node2D:
	for room in world.rooms:
		if str(room.name) == room_name:
			return room
	return null


func _finish() -> void:
	print("ACT2_MUSIC: ", failures, " failures")
	get_tree().quit(0 if failures == 0 else 1)


func check(ok: bool, label: String) -> void:
	print("PASS " if ok else "FAIL ", label)
	if not ok:
		failures += 1
