extends Node
## Act III's score from the real sea on (scripts/act3/act3_music.gd; ElevenLabs
## cues mastered by tools/master_elevenlabs_music.py). Headless audio does not
## mix, so this checks the parts that fail silently rather than the sound:
##   - which room plays which cue (the sunrise, the walk, the tall grass, the chase);
##   - the loops loop, the ones with an intro head jump back past it, and the
##     lemon is a PIECE that plays once and ends in silence;
##   - the designed transitions: the chase CUTS in on the roar, the edge cuts it
##     out, the growl hushes the tall grass in a breath, the peril hands the
##     lemon its first note;
##   - from the growl on, the beats own the score: a doorway mid-chase does not
##     change the cue, and the lemon keeps playing through the paused results.
##
## Headless:  Godot --headless --path . res://tests/act3_music_test.tscn

var failures := 0


func _ready() -> void:
	SaveGame.slot = -1
	var C := Act3Music.Cue
	var rooms := {"Act3_Level_23": C.FLOOR, "Act3_Level_24": C.REST, "Act3_Level_25": C.SUNRISE,
		"Act3_Level_26": C.WAY_HOME, "Act3_Level_27": C.WAY_HOME, "Act3_Level_28": C.STALK,
		"Act3_Level_29": C.CHASE, "Act3_Level_30": C.CHASE, "Act3_Level_31": C.CHASE}
	for room_name: String in rooms:
		var fake := Node2D.new()
		fake.name = room_name
		check(Act3Music.cue_for(fake) == rooms[room_name], "%s plays cue %d" % [room_name, rooms[room_name]])
		fake.free()

	LdtkWorld.debug_start_room = "Act3_Level_26"
	var world: SeaWorld = load("res://ldtk/Act3World.tscn").instantiate()
	world.set_meta("no_beats", true)
	Screen.set_scene(world)
	for i in 20:
		await get_tree().physics_frame
	var music := world.get_node_or_null("Music") as Act3Music
	check(music != null and music.stream is AudioStreamInteractive, "the Act III world has its interactive score")
	if music == null or not music.stream is AudioStreamInteractive:
		_finish()
		return
	var stream := music.stream as AudioStreamInteractive
	check(music.bus == &"Music", "on the Music bus, so the pause menu's MUSIC row mutes it")
	check(music.current_cue() == C.WAY_HOME, "the shore road opens on the walking theme")

	for cue in [C.SUNRISE, C.WAY_HOME, C.STALK, C.CHASE, C.PERIL]:
		var ogg := stream.get_clip_stream(cue) as AudioStreamOggVorbis
		check(ogg != null and ogg.loop and ogg.get_length() > 60.0, "%s loops, over a minute long" % stream.get_clip_name(cue))
	for cue in [C.SUNRISE, C.STALK, C.CHASE, C.PERIL]:
		var ogg := stream.get_clip_stream(cue) as AudioStreamOggVorbis
		check(ogg != null and ogg.loop_offset > 1.0,
			"%s keeps its opening once, then loops past it  [offset %.2f]" % [stream.get_clip_name(cue), ogg.loop_offset])
	var lemon := stream.get_clip_stream(C.LEMON) as AudioStreamOggVorbis
	check(lemon != null and not lemon.loop and lemon.get_length() > 80.0, "the lemon is a piece, played once")
	check(stream.get_clip_auto_advance_next_clip(C.LEMON) == C.REST, "...and ends in silence")

	var CUT := AudioStreamInteractive.FADE_DISABLED
	check(stream.has_transition(AudioStreamInteractive.CLIP_ANY, C.CHASE)
		and stream.get_transition_fade_mode(AudioStreamInteractive.CLIP_ANY, C.CHASE) == CUT,
		"the chase cuts in on the roar")
	check(stream.has_transition(C.CHASE, C.REST) and stream.get_transition_fade_beats(C.CHASE, C.REST) < 0.2,
		"the edge giving way cuts the chase out")
	check(stream.has_transition(C.STALK, C.REST) and stream.get_transition_fade_beats(C.STALK, C.REST) <= 1.0,
		"the tiger's growl hushes the tall grass in a breath")
	check(stream.has_transition(C.PERIL, C.LEMON)
		and stream.get_transition_fade_mode(C.PERIL, C.LEMON) == AudioStreamInteractive.FADE_OUT,
		"the lemon's first note is not faded: the peril lets go under it")
	check(stream.has_transition(C.WAY_HOME, C.STALK) and stream.get_transition_fade_beats(C.WAY_HOME, C.STALK) > 5.0,
		"the wind dies away slowly into the tall grass")

	# The story takes the score at the growl and keeps it through the rooms.
	music._on_room_changed(_room(world, "Act3_Level_28"))
	check(music.current_cue() == C.STALK, "the tall grass plays the stalking bed")
	music.rest()
	check(music.current_cue() == C.REST, "the growl: silence")
	music.chase()
	check(music.current_cue() == C.CHASE, "the roar: the chase")
	music._on_room_changed(_room(world, "Act3_Level_27"))
	check(music.current_cue() == C.CHASE, "running back through a doorway does not stop the chase")
	music._on_room_changed(_room(world, "Act3_Level_31"))
	music.rest()
	music.peril()
	check(music.current_cue() == C.PERIL, "on the vine: the peril")
	music.lemon()
	check(music.current_cue() == C.LEMON and music.process_mode == Node.PROCESS_MODE_ALWAYS,
		"the lemon plays on through the paused results")
	_finish()


func _room(world: SeaWorld, room_name: String) -> Node2D:
	for r in world.rooms:
		if str(r.name) == room_name:
			return r
	return null


func _finish() -> void:
	print("ACT3_MUSIC: %d failures" % failures)
	get_tree().quit(0 if failures == 0 else 1)


func check(ok: bool, message: String) -> void:
	print(("  PASS " if ok else "  FAIL ") + message)
	if not ok:
		failures += 1
