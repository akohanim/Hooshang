extends Node

const MUSIC_SCRIPT = preload("res://scripts/act1_music.gd")
const NORMAL = preload("res://assets/music/shur_circuit_climb.mp3")
const SOMBER = preload("res://assets/music/darkshang_shur_requiem.ogg")
var failures := 0

func _ready() -> void:
	call_deferred("_run")

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)
	else:
		print("PASS: ", label)

func _run() -> void:
	var world: Node = load("res://ldtk/Act1World.tscn").instantiate()
	check(world.get_node("Music").chase_stream == SOMBER, "actual Act 1 world wires alternate music")
	world.free()
	check(SOMBER.loop, "somber soundtrack loops")
	check(SOMBER.get_length() > 180.0, "complete alternate arrangement loads")
	var music := AudioStreamPlayer.new()
	music.set_script(MUSIC_SCRIPT)
	music.stream = NORMAL
	music.chase_stream = SOMBER
	music.volume_db = -10.0
	music.bus = &"Music"
	music.transition_time = 0.05
	add_child(music)
	var room := Node2D.new()
	add_child(room)
	room.name = "Level_18"
	music._on_room_changed(room)
	await music._fade.finished
	check(music._chase_target and is_equal_approx(music._chase_blend, 1.0), "level 18 fades into chase cue")
	var playback: AudioStreamPlayback = music.get_stream_playback()
	var mix: AudioStreamSynchronized = music.stream
	check(mix.get_sync_stream_volume(0) < -80.0 and absf(mix.get_sync_stream_volume(1)) < 0.01, "chase cue replaces original at full mix")
	for number in [19, 20, 25]:
		room.name = "Level_%d" % number
		music._on_room_changed(room)
		check(music.get_stream_playback() == playback and music.stream == mix, "room %d preserves playback transport" % number)
	music.volume_db = -24.0
	check(music.volume_db == -24.0 and music.bus == &"Music", "dialogue duck and music settings still own outer volume")
	room.name = "Level_26"
	music._on_room_changed(room)
	await music._fade.finished
	check(not music._chase_target and is_zero_approx(music._chase_blend), "homecoming returns to original arrangement")
	check(music.get_stream_playback() == playback, "homecoming does not restart either arrangement")
	room.name = "Level_14"
	music._on_room_changed(room)
	await music._fade.finished
	check(music._chase_target, "first Darkshang room selects somber music")
	room.name = "Level_13"
	music._on_room_changed(room)
	await music._fade.finished
	check(not music._chase_target, "earlier office rooms keep original music")
	get_tree().quit(0 if failures == 0 else 1)
