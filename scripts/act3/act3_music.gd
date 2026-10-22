class_name Act3Music
extends AudioStreamPlayer
## Act III's score, one AudioStreamInteractive so every change is a designed
## transition rather than a cut. Under the water the cue follows the chapter,
## the way the colour does (tools/gen_act3_sea_music.py); from the real sea on
## it follows the STORY (ElevenLabs Music, tools/gen_elevenlabs_music.py; see
## assets/music/README.md):
##
##   Ch I    the ink shore     shore
##   Ch II   the shallows      deep
##   Ch III  the drowned office wreck
##   Ch IV   the reef          reef
##   Ch V    the trench        trench
##           the floor, the pond, the ascent   floor (once), then silence
##   epilogue the office at dawn  silence (a tube hums in the room)
##           the real sea      sunrise: the ney's homecoming melody; its swell
##                             rises with the fade from black, once
##   the way home  the shore road, the meadow   way_home: setar, kamancheh, daf
##           the tall grass    stalk: the wind stops, something is watching
##           the tiger steps out   silence (Act3Beats calls rest() on the growl)
##           its roar, to the edge chase, CUT in on the roar (Act3Beats: chase())
##           the edge gives way    silence, cut (rest())
##           on the vine           peril: the drone, the heartbeat, the mice
##           he picks the lemon    lemon: the peril lets go and the ney sings;
##                                 a PIECE, played once, through the end cards
##                                 and the results (lemon())
##
## From the growl on, the beats own the cue: rooms change under a chase that
## must not stop for a doorway. Silence is a CLIP ("rest"), not a volume fade:
## LdtkWorld owns volume_db for dialogue ducking (see Act2Music for the same
## rule). Every clip is tagged 60 BPM, so a fade's beats are its seconds.

enum Cue { SHORE, DEEP, WRECK, REEF, TRENCH, FLOOR, SUNRISE, WAY_HOME, STALK, CHASE, PERIL, LEMON, REST }

@export var shore: AudioStream
@export var deep: AudioStream
@export var wreck: AudioStream
@export var reef: AudioStream
@export var trench: AudioStream
@export var floor_cue: AudioStream
@export var sunrise: AudioStream
@export var way_home: AudioStream
@export var stalk: AudioStream
@export var chase_cue: AudioStream
@export var peril_cue: AudioStream
@export var lemon_cue: AudioStream
## Crossfade, in seconds, for every cue change not designed below.
@export var fade_seconds := 3.0

## The designed changes, (from, to, fade mode, seconds). Looked up before the
## default: an exact pair, then CLIP_ANY to a cue (godot's own order).
const TRANSITIONS := [
	# The wind dies away as he walks into the tall grass.
	[Cue.WAY_HOME, Cue.STALK, AudioStreamInteractive.FADE_CROSS, 7.0],
	# The tiger steps out: the stalking bed is gone in a breath, and "...No."
	# is said into silence.
	[Cue.STALK, Cue.REST, AudioStreamInteractive.FADE_OUT, 0.8],
	# The edge gives way: the chase stops dead under him.
	[Cue.CHASE, Cue.REST, AudioStreamInteractive.FADE_OUT, 0.12],
	# Hanging there, the peril comes up out of the wind.
	[Cue.REST, Cue.PERIL, AudioStreamInteractive.FADE_CROSS, 4.0],
	# He picks the lemon: the ney starts at once, the drone lets go under it.
	[Cue.PERIL, Cue.LEMON, AudioStreamInteractive.FADE_OUT, 5.0],
	# The sunrise brings its own swell up out of the office's silence.
	[Cue.REST, Cue.SUNRISE, AudioStreamInteractive.FADE_OUT, 0.5],
]

var _interactive: AudioStreamInteractive
var _cue := -1
var _floor_played := false
## The beats have taken the score (from the tiger's growl): rooms no longer pick it.
var _scored := false


func _ready() -> void:
	var clips := [shore, deep, wreck, reef, trench, floor_cue, sunrise, way_home, stalk, chase_cue, peril_cue, lemon_cue]
	for c in clips:
		if c == null:
			return
	_interactive = AudioStreamInteractive.new()
	_interactive.clip_count = clips.size() + 1
	var names := [&"shore", &"deep", &"wreck", &"reef", &"trench", &"floor", &"sunrise", &"way_home",
		&"stalk", &"chase", &"peril", &"lemon"]
	for i in clips.size():
		var clip: AudioStream = clips[i]
		if clip is AudioStreamOggVorbis:
			# A loop's intro head (loop_offset) comes from its .import.
			(clip as AudioStreamOggVorbis).loop = i != Cue.FLOOR and i != Cue.LEMON
			(clip as AudioStreamOggVorbis).bpm = 60.0
		_interactive.set_clip_stream(i, clip)
		_interactive.set_clip_name(i, names[i])
	_interactive.set_clip_stream(Cue.REST, _silence())
	_interactive.set_clip_name(Cue.REST, &"rest")
	for once in [Cue.FLOOR, Cue.LEMON]:
		_interactive.set_clip_auto_advance(once, AudioStreamInteractive.AUTO_ADVANCE_ENABLED)
		_interactive.set_clip_auto_advance_next_clip(once, Cue.REST)
	for t in TRANSITIONS:
		_interactive.add_transition(t[0], t[1], AudioStreamInteractive.TRANSITION_FROM_TIME_IMMEDIATE,
			AudioStreamInteractive.TRANSITION_TO_TIME_START, t[2], t[3])
	# The chase CUTS in, from anything: its first hit is the roar's.
	_interactive.add_transition(AudioStreamInteractive.CLIP_ANY, Cue.CHASE,
		AudioStreamInteractive.TRANSITION_FROM_TIME_IMMEDIATE, AudioStreamInteractive.TRANSITION_TO_TIME_START,
		AudioStreamInteractive.FADE_DISABLED, 0.0)
	_interactive.add_transition(AudioStreamInteractive.CLIP_ANY, AudioStreamInteractive.CLIP_ANY,
		AudioStreamInteractive.TRANSITION_FROM_TIME_IMMEDIATE, AudioStreamInteractive.TRANSITION_TO_TIME_START,
		AudioStreamInteractive.FADE_CROSS, fade_seconds)
	_interactive.initial_clip = Cue.REST
	stream = _interactive
	var world := get_parent()
	if world.has_signal("room_changed"):
		world.room_changed.connect(_on_room_changed)
	_start.call_deferred()


## One bar of silence at the cues' nominal 60 BPM, looping.
func _silence() -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 22050
	wav.stereo = false
	var data := PackedByteArray()
	data.resize(22050 * 4 * 2)
	wav.data = data
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_end = 22050 * 4
	return wav


func _start() -> void:
	_cue = Cue.REST
	play()
	_on_room_changed(get_parent().get("current_room"))


## Which cue a room plays. Public so a test can check the map without audio.
static func cue_for(room: Node2D) -> int:
	if room == null:
		return Cue.REST
	var n := LdtkWorld.index_in_name(str(room.name)) / 100
	if not str(room.name).begins_with("Act3_Level_"):
		return Cue.REST
	if n <= 3:
		return Cue.SHORE
	if n <= 8:
		return Cue.DEEP
	if n <= 13:
		return Cue.WRECK
	if n <= 18:
		return Cue.REEF
	if n <= 20:
		return Cue.TRENCH
	if n <= 23:
		return Cue.FLOOR
	if n == 24:
		return Cue.REST
	if n == 25:
		return Cue.SUNRISE
	if n <= 27:
		return Cue.WAY_HOME
	if n == 28:
		return Cue.STALK
	return Cue.CHASE


## The cue playing now (tests).
func current_cue() -> int:
	return _cue


## The tiger has roared: run (Act3Beats).
func chase() -> void:
	_scored = true
	_switch(Cue.CHASE)


## Silence: the tiger stepping out of the grass, the edge giving way (Act3Beats).
## How fast it falls silent is the transition's (TRANSITIONS).
func rest() -> void:
	_scored = true
	_switch(Cue.REST)


## Hanging from the vine, a tiger above and below, the mice at the root.
func peril() -> void:
	_scored = true
	_switch(Cue.PERIL)


## He picks the lemon. The game's last music: it keeps playing through the end
## cards and the act's results, which pause the tree, so it stops pausing.
func lemon() -> void:
	_scored = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	_switch(Cue.LEMON)


func _on_room_changed(room: Node2D) -> void:
	# From the growl on, the story has the score; a doorway mid-chase is not a cue.
	if _scored and room != null and LdtkWorld.index_in_name(str(room.name)) / 100 >= 25:
		return
	var cue := cue_for(room)
	# The floor's chord plays once per arrival at the bottom, then the scene is
	# carried by its own quiet.
	if cue == Cue.FLOOR:
		if _floor_played:
			return
		_floor_played = true
	_switch(cue)


func _switch(cue: int) -> void:
	if _interactive == null or cue == _cue:
		return
	_cue = cue
	if not playing:
		play()
	var playback := get_stream_playback() as AudioStreamPlaybackInteractive
	if playback != null:
		playback.switch_to_clip(cue)
