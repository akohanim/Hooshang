class_name Act3Music
extends AudioStreamPlayer
## Act III's score (tools/gen_act3_sea_music.py; assets/music/README.md), one
## AudioStreamInteractive so every change crossfades instead of cutting. The cue
## follows the chapter, the way the colour does:
##
##   Ch I    the ink shore     shore
##   Ch II   the shallows      deep
##   Ch III  the drowned office wreck
##   Ch IV   the reef          reef
##   Ch V    the trench        trench
##           the floor, the pond, the ascent   floor (once), then silence
##   epilogue the office at dawn  silence (a tube hums in the room)
##           the real sea      dawn
##
## Silence is a CLIP ("rest"), not a volume fade: LdtkWorld owns volume_db for
## dialogue ducking (see Act2Music for the same rule).

enum Cue { SHORE, DEEP, WRECK, REEF, TRENCH, FLOOR, DAWN, REST }

@export var shore: AudioStream
@export var deep: AudioStream
@export var wreck: AudioStream
@export var reef: AudioStream
@export var trench: AudioStream
@export var floor_cue: AudioStream
@export var dawn: AudioStream
## Crossfade, in seconds, for every cue change.
@export var fade_seconds := 3.0

var _interactive: AudioStreamInteractive
var _cue := -1
var _floor_played := false


func _ready() -> void:
	var clips := [shore, deep, wreck, reef, trench, floor_cue, dawn]
	for c in clips:
		if c == null:
			return
	_interactive = AudioStreamInteractive.new()
	_interactive.clip_count = clips.size() + 1
	var names := [&"shore", &"deep", &"wreck", &"reef", &"trench", &"floor", &"dawn"]
	for i in clips.size():
		var clip: AudioStream = clips[i]
		if clip is AudioStreamOggVorbis:
			(clip as AudioStreamOggVorbis).loop = i != Cue.FLOOR
			(clip as AudioStreamOggVorbis).bpm = 60.0
		_interactive.set_clip_stream(i, clip)
		_interactive.set_clip_name(i, names[i])
	_interactive.set_clip_stream(Cue.REST, _silence())
	_interactive.set_clip_name(Cue.REST, &"rest")
	_interactive.set_clip_auto_advance(Cue.FLOOR, AudioStreamInteractive.AUTO_ADVANCE_ENABLED)
	_interactive.set_clip_auto_advance_next_clip(Cue.FLOOR, Cue.REST)
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
	if n == 25:
		return Cue.DAWN
	return Cue.REST


func _on_room_changed(room: Node2D) -> void:
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
