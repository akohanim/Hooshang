class_name Act2Music
extends AudioStreamPlayer
## Act 2's score: "Sunlit Garden Path", cut by tools/gen_act2_garden_music.py
## into bar-aligned cues and driven as one AudioStreamInteractive, so every
## change waits for the next bar and crossfades rather than cutting.
##
##   room 0 (opening)          intro, which runs straight into ...
##   rooms 0-2 (meadow/pond)   ponds   (Exploring Neighborhood Ponds, looped)
##   gardens 3-13              wonder  (Playful Wonder, looped)
##   room 8 (the breather)     ponds   — the rest room gets the calmer theme
##   room 14 (leaving)         coda    (Loop Coda, once; it fades itself out)
##   prison hub + wings        prison  (its own ElevenLabs theme, 60 BPM; see
##                                      assets/music/README.md)
##   everywhere else           rest    (a silent bar: gatehouse, escape and
##                                      finale keep their own soundscape)
##
## Silence is a CLIP ("rest"), not a volume fade, because LdtkWorld owns this
## node's volume_db for dialogue ducking (`_duck_music`) — a second owner of
## that property would fight it every time a line opened or closed.
## The Jamshid night encounter calls rest()/resume() (Act2Beats): crickets and
## the campfire carry that scene.

const BPM := 100.0
## The prison theme's own tempo (tools/master_elevenlabs_music.py measured it):
## bar-quantized transitions count bars in the SOURCE clip's tempo.
const PRISON_BPM := 60.0
const BAR_BEATS := 4

@export var intro: AudioStream
@export var ponds: AudioStream
@export var wonder: AudioStream
@export var coda: AudioStream
@export var rest_stream: AudioStream
@export var prison: AudioStream
## Crossfade length, in beats, for every cue change (4 = one bar).
@export var fade_beats := 4.0
## Garden rooms that play the calmer ponds theme instead of wonder.
@export var breather_rooms: PackedInt32Array = [8]

enum Cue { INTRO, PONDS, WONDER, CODA, REST, PRISON }

var _interactive: AudioStreamInteractive
var _resting := false
var _cue := -1


func _ready() -> void:
	if intro == null or ponds == null or wonder == null or coda == null or rest_stream == null or prison == null:
		return
	_interactive = AudioStreamInteractive.new()
	var clips := [[intro, &"intro", false], [ponds, &"ponds", true], [wonder, &"wonder", true],
		[coda, &"coda", false], [rest_stream, &"rest", true], [prison, &"prison", true]]
	_interactive.clip_count = clips.size()
	for i in clips.size():
		var clip: AudioStream = clips[i][0]
		_tag(clip, bool(clips[i][2]), PRISON_BPM if i == Cue.PRISON else BPM)
		_interactive.set_clip_stream(i, clip)
		_interactive.set_clip_name(i, clips[i][1])
	# The intro is the head of the same recording: it ends exactly where the
	# ponds loop begins, so advancing at its end is seamless. The coda ends in
	# its own fade-out, then sits on the silent bar.
	_interactive.set_clip_auto_advance(Cue.INTRO, AudioStreamInteractive.AUTO_ADVANCE_ENABLED)
	_interactive.set_clip_auto_advance_next_clip(Cue.INTRO, Cue.PONDS)
	_interactive.set_clip_auto_advance(Cue.CODA, AudioStreamInteractive.AUTO_ADVANCE_ENABLED)
	_interactive.set_clip_auto_advance_next_clip(Cue.CODA, Cue.REST)
	_interactive.add_transition(AudioStreamInteractive.CLIP_ANY, AudioStreamInteractive.CLIP_ANY,
		AudioStreamInteractive.TRANSITION_FROM_TIME_NEXT_BAR, AudioStreamInteractive.TRANSITION_TO_TIME_START,
		AudioStreamInteractive.FADE_CROSS, fade_beats)
	stream = _interactive
	var world := get_parent()
	if world.has_signal("room_changed"):
		world.room_changed.connect(_on_room_changed)
	# The world builds its rooms after its children are ready.
	_start.call_deferred()


func _start() -> void:
	var world := get_parent()
	var room: Node2D = world.get("current_room")
	var wanted := cue_for(room)
	# A new act opens on the intro; anything else fades in from the silent bar.
	_interactive.initial_clip = Cue.INTRO if wanted == Cue.PONDS and room != null \
		and str(room.name) == "Act_2_Level_0" else Cue.REST
	_cue = _interactive.initial_clip
	play()
	if _cue == Cue.REST:
		_switch(wanted)


## Which cue a room plays. Public so a test can check the map without audio.
static func cue_for(room: Node2D, breathers: PackedInt32Array = [8]) -> int:
	if room == null:
		return Cue.REST
	var room_name := str(room.name)
	if room_name in ["Act_2_Level_0", "Act_2_Level_1", "Level_2"]:
		return Cue.PONDS
	if room_name.begins_with("Act_2_Level_"):
		var n := room_name.get_slice("_", 3).to_int()
		if n >= 3 and n <= 13:
			return Cue.PONDS if n in breathers else Cue.WONDER
		if n == 14:
			return Cue.CODA
	if room_name.begins_with("Prison_"):
		return Cue.PRISON
	return Cue.REST


func _on_room_changed(room: Node2D) -> void:
	_switch(cue_for(room, breather_rooms))


## Fade the garden out for a scene that brings its own sound.
func rest() -> void:
	_resting = true
	_switch(Cue.REST)


## Bring the room's cue back after rest().
func resume() -> void:
	_resting = false
	_switch(cue_for(get_parent().get("current_room"), breather_rooms))


func _switch(cue: int) -> void:
	if _interactive == null:
		return
	if _resting:
		cue = Cue.REST
	# The coda plays once per arrival from the gardens; walking back into the
	# same room (or reloading in it) must not replay the ending.
	if cue == Cue.CODA and _cue in [Cue.CODA, Cue.REST]:
		cue = Cue.REST
	# Still on the intro: it is already headed for ponds on its own.
	if cue == Cue.PONDS and _cue == Cue.INTRO:
		return
	if cue == _cue:
		return
	_cue = cue
	if not playing:
		play()
	var playback := get_stream_playback() as AudioStreamPlaybackInteractive
	if playback != null:
		playback.switch_to_clip(cue)


## Give an imported cue the tempo the interactive transitions count bars in.
func _tag(clip: AudioStream, looping: bool, bpm: float) -> void:
	if clip is AudioStreamOggVorbis:
		var ogg := clip as AudioStreamOggVorbis
		ogg.loop = looping
		ogg.bpm = bpm
		ogg.bar_beats = BAR_BEATS
		ogg.beat_count = int(round(ogg.get_length() * bpm / 60.0))
